defmodule QlockWeb.ReportsLive do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  # Ash.Query.filter is a macro — must be required before using ^ pin and
  # expression syntax (>=, <=, ==) inside filter/2 calls.
  require Ash.Query

  alias Qlock.TimeTracking.TimeEntry
  alias Qlock.TimeTracking

  # ── Mount ─────────────────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    is_admin = socket.assigns.current_user.role == :admin

    # Admin gets a list of all users for the filter dropdown
    all_users =
      if is_admin do
        {:ok, users} =
          Ash.read(Qlock.Accounts.User,
            domain: Qlock.Accounts,
            authorize?: false
          )
        Enum.sort_by(users, & &1.email)
      else
        []
      end

    socket =
      socket
      |> assign(
        is_admin: is_admin,
        all_users: all_users,
        date_from: Date.new!(today.year, today.month, 1),
        date_to: today,
        filter_user_id: "",
        total_seconds: 0,
        entry_count: 0,
        project_groups: [],
        member_groups: [],
        daily_groups: [],
        loading: false
      )
      |> load_report()

    {:ok, socket}
  end

  # ── Events ────────────────────────────────────────────────────────────────

  # Quick range buttons
  @impl true
  def handle_event("set_range", %{"range" => range}, socket) do
    today = Date.utc_today()

    {date_from, date_to} =
      case range do
        "this_week" ->
          dow = Date.day_of_week(today)
          {Date.add(today, -(dow - 1)), today}

        "this_month" ->
          {Date.new!(today.year, today.month, 1), today}

        "last_month" ->
          last_day = Date.new!(today.year, today.month, 1) |> Date.add(-1)
          {Date.new!(last_day.year, last_day.month, 1), last_day}

        "last_7" ->
          {Date.add(today, -6), today}

        _ ->
          {socket.assigns.date_from, socket.assigns.date_to}
      end

    {:noreply,
     socket
     |> assign(date_from: date_from, date_to: date_to)
     |> load_report()}
  end

  # ── Nudge ─────────────────────────────────────────────────────────────────────
  # Admin clicks Nudge next to a member who is behind their goal.
  # Broadcasts via Phoenix PubSub → NotificationTransport → tauri-plugin-websocket
  # → OS popup on the user's desktop. No database involved.
  def handle_event("nudge", %{"user-id" => user_id, "actual" => actual_s, "goal" => goal_s}, socket) do
    if socket.assigns.is_admin do
      actual_h = String.to_integer(actual_s) |> div(3600)
      goal_h   = String.to_integer(goal_s)   |> div(3600)

      message =
        "You've logged #{actual_h}h this week but your goal is #{goal_h}h. " <>
        "Please add your missing time entries in SandQlock."

      Phoenix.PubSub.broadcast(
        Qlock.PubSub,
        "notifications:#{user_id}",
        {:nudge, message}
      )

      {:noreply, put_flash(socket, :info, "Nudge sent ✓")}
    else
      {:noreply, socket}
    end
  end

  # Custom date range + user filter
  def handle_event("apply_filter", params, socket) do
    date_from =
      case Date.from_iso8601(params["date_from"] || "") do
        {:ok, d} -> d
        _ -> socket.assigns.date_from
      end

    date_to =
      case Date.from_iso8601(params["date_to"] || "") do
        {:ok, d} -> d
        _ -> socket.assigns.date_to
      end

    filter_user_id =
      if socket.assigns.is_admin, do: params["filter_user_id"] || "", else: ""

    {:noreply,
     socket
     |> assign(date_from: date_from, date_to: date_to, filter_user_id: filter_user_id)
     |> load_report()}
  end

  # ── Data loading ──────────────────────────────────────────────────────────

  defp load_report(socket) do
    %{
      current_user: user,
      is_admin: is_admin,
      date_from: date_from,
      date_to: date_to,
      filter_user_id: filter_user_id
    } = socket.assigns

    base_query =
      TimeEntry
      |> Ash.Query.filter(date >= ^date_from and date <= ^date_to)
      |> Ash.Query.load([:project, :category, :user])

    # Admin filtering by specific user
    query =
      if is_admin && filter_user_id != "" do
        Ash.Query.filter(base_query, user_id == ^filter_user_id)
      else
        base_query
      end

    entries =
      if is_admin do
        # Admin policy (just added) allows reading all — no authorize? bypass needed
        Ash.read!(query, actor: user, domain: TimeTracking)
      else
        Ash.read!(query, actor: user, domain: TimeTracking)
      end

    total_seconds = Enum.sum(Enum.map(entries, & &1.duration_seconds))

    project_groups = build_project_groups(entries)
    member_groups = if is_admin, do: build_member_groups(entries), else: []
    daily_groups = build_daily_groups(entries, date_from, date_to)

    assign(socket,
      total_seconds: total_seconds,
      entry_count: length(entries),
      project_groups: project_groups,
      member_groups: member_groups,
      daily_groups: daily_groups
    )
  end

  # Groups: [{project | nil, total_seconds, [{category | nil, seconds}]}]
  defp build_project_groups(entries) do
    entries
    |> Enum.group_by(& &1.project_id)
    |> Enum.map(fn {_pid, proj_entries} ->
      total = Enum.sum(Enum.map(proj_entries, & &1.duration_seconds))
      project = proj_entries |> hd() |> Map.get(:project)

      categories =
        proj_entries
        |> Enum.group_by(& &1.category_id)
        |> Enum.map(fn {_cid, cat_entries} ->
          cat_total = Enum.sum(Enum.map(cat_entries, & &1.duration_seconds))
          category = cat_entries |> hd() |> Map.get(:category)
          {category, cat_total}
        end)
        |> Enum.sort_by(&elem(&1, 1), :desc)

      {project, total, categories}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  # [{user, total_seconds}] — admin only, includes weekly_hours_goal from user
  defp build_member_groups(entries) do
    entries
    |> Enum.group_by(& &1.user_id)
    |> Enum.map(fn {_uid, user_entries} ->
      total = Enum.sum(Enum.map(user_entries, & &1.duration_seconds))
      user = user_entries |> hd() |> Map.get(:user)
      {user, total}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  # Goal in seconds for the selected date range.
  # weekly_hours_goal (nil → 35h default) scaled by weeks in range.
  def goal_secs_for_range(user, date_from, date_to) do
    weekly_h = user.weekly_hours_goal || 35.0
    days = Date.diff(date_to, date_from) + 1
    weeks = max(1, days / 7)
    round(weekly_h * 3600 * weeks)
  end

  def goal_class(actual, goal) when goal > 0 do
    pct = actual / goal * 100
    cond do
      pct >= 100 -> "text-success"
      pct >= 70  -> "text-warning"
      true       -> "text-error"
    end
  end
  def goal_class(_, _), do: "text-base-content"

  def goal_progress_class(actual, goal) when goal > 0 do
    pct = actual / goal * 100
    cond do
      pct >= 100 -> "progress-success"
      pct >= 70  -> "progress-warning"
      true       -> "progress-error"
    end
  end
  def goal_progress_class(_, _), do: "progress-secondary"

  # [{date, total_seconds}] — every day in range (0 if no entries)
  defp build_daily_groups(entries, date_from, date_to) do
    entry_map =
      entries
      |> Enum.group_by(& &1.date)
      |> Map.new(fn {date, day_entries} ->
        {date, Enum.sum(Enum.map(day_entries, & &1.duration_seconds))}
      end)

    days = Date.range(date_from, date_to) |> Enum.to_list()

    Enum.map(days, fn day ->
      {day, Map.get(entry_map, day, 0)}
    end)
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp format_hours(seconds) do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)

    cond do
      h > 0 && m > 0 -> "#{h}h #{m}m"
      h > 0 -> "#{h}h"
      m > 0 -> "#{m}m"
      true -> "#{rem(seconds, 60)}s"
    end
  end

  defp pct(_total, 0), do: 0
  defp pct(0, _part), do: 0
  defp pct(total, part), do: round(part / total * 100)

  defp project_label(nil), do: "No Project"
  defp project_label(p), do: p.name

  defp category_label(nil), do: "No Category"
  defp category_label(c), do: c.name

  defp user_label(nil), do: "Unknown"
  defp user_label(u), do: to_string(u.email)

  defp format_date_range(from, to) do
    "#{Calendar.strftime(from, "%d %b %Y")} – #{Calendar.strftime(to, "%d %b %Y")}"
  end

  defp days_in_range(from, to), do: Date.diff(to, from) + 1

  # ── Render ────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:reports} current_user={@current_user}>
      <div class="max-w-3xl mx-auto px-6 md:px-10 py-6 space-y-8">

        <%!-- Page header --%>
        <div class="pb-6 border-b border-base-300">
          <div class="flex items-center justify-between gap-4 flex-wrap">
            <div>
              <h1 class="text-3xl font-semibold">Reports</h1>
              <p class="text-sm text-base-content/50 mt-0.5">
                {format_date_range(@date_from, @date_to)}
                <span :if={@is_admin && @filter_user_id != ""} class="ml-2">
                  · {user_label(Enum.find(@all_users, &(to_string(&1.id) == @filter_user_id)))}
                </span>
              </p>
            </div>

            <%!-- Admin badge --%>
            <span :if={@is_admin} class="badge badge-primary badge-sm gap-1">
              <.icon name="ri-shield-star-line" class="size-3" />
              Team view
            </span>
          </div>

          <%!-- Quick range buttons --%>
          <div class="flex items-center gap-2 mt-4 flex-wrap">
            <button phx-click="set_range" phx-value-range="last_7"
                    class="btn btn-ghost btn-xs">Last 7 days</button>
            <button phx-click="set_range" phx-value-range="this_week"
                    class="btn btn-ghost btn-xs">This week</button>
            <button phx-click="set_range" phx-value-range="this_month"
                    class="btn btn-ghost btn-xs">This month</button>
            <button phx-click="set_range" phx-value-range="last_month"
                    class="btn btn-ghost btn-xs">Last month</button>
          </div>

          <%!-- Custom filter form --%>
          <form phx-submit="apply_filter" class="flex items-end gap-3 mt-3 flex-wrap">
            <div>
              <label class="label py-0.5">
                <span class="label-text text-xs">From</span>
              </label>
              <input type="date" name="date_from"
                     value={Date.to_iso8601(@date_from)}
                     max={Date.to_iso8601(Date.utc_today())}
                     class="input input-bordered input-sm" />
            </div>
            <div>
              <label class="label py-0.5">
                <span class="label-text text-xs">To</span>
              </label>
              <input type="date" name="date_to"
                     value={Date.to_iso8601(@date_to)}
                     max={Date.to_iso8601(Date.utc_today())}
                     class="input input-bordered input-sm" />
            </div>

            <%!-- Admin only: filter by user --%>
            <div :if={@is_admin}>
              <label class="label py-0.5">
                <span class="label-text text-xs">Member</span>
              </label>
              <select name="filter_user_id" class="select select-bordered select-sm min-w-36">
                <option value="">All members</option>
                <option
                  :for={u <- @all_users}
                  value={u.id}
                  selected={to_string(u.id) == @filter_user_id}
                >
                  {to_string(u.email)}
                </option>
              </select>
            </div>

            <button type="submit" class="btn btn-primary btn-sm">Apply</button>
          </form>
        </div>

        <%!-- Summary cards --%>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <div class="card bg-base-200 p-4">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50 mb-1">Total</p>
            <p class="text-2xl font-bold tabular-nums">{format_hours(@total_seconds)}</p>
          </div>
          <div class="card bg-base-200 p-4">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50 mb-1">Entries</p>
            <p class="text-2xl font-bold tabular-nums">{@entry_count}</p>
          </div>
          <div class="card bg-base-200 p-4">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50 mb-1">Projects</p>
            <p class="text-2xl font-bold tabular-nums">{length(@project_groups)}</p>
          </div>
          <div class="card bg-base-200 p-4">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50 mb-1">
              {if @is_admin, do: "Members", else: "Days"}
            </p>
            <p class="text-2xl font-bold tabular-nums">
              {if @is_admin,
                do: length(@member_groups),
                else: days_in_range(@date_from, @date_to)}
            </p>
          </div>
        </div>

        <%!-- Empty state --%>
        <div :if={@entry_count == 0}
             class="flex flex-col items-center justify-center py-20 gap-3 text-base-content/40">
          <.icon name="ri-bar-chart-line" class="size-14" />
          <p class="text-sm">No entries found for this period</p>
        </div>

        <%!-- ── By Project ──────────────────────────────────────────────────── --%>
        <div :if={@entry_count > 0} class="space-y-6">
          <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50">
            By Project
          </p>

          <div :for={{project, proj_total, categories} <- @project_groups} class="space-y-2">
            <%!-- Project row --%>
            <div class="flex items-center gap-3">
              <div class="w-[3px] self-stretch bg-primary rounded-full shrink-0" />
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between gap-2 mb-1">
                  <span class="font-semibold text-sm truncate">{project_label(project)}</span>
                  <div class="flex items-center gap-2 shrink-0">
                    <span class="text-xs text-base-content/40">
                      {pct(@total_seconds, proj_total)}%
                    </span>
                    <span class="font-mono font-semibold text-sm tabular-nums">
                      {format_hours(proj_total)}
                    </span>
                  </div>
                </div>
                <progress
                  class="progress progress-primary h-1.5 w-full"
                  value={proj_total}
                  max={@total_seconds}
                />
              </div>
            </div>

            <%!-- Category breakdown (only if multiple or named) --%>
            <div
              :if={length(categories) > 1 || (length(categories) == 1 && elem(hd(categories), 0) != nil)}
              class="ml-5 space-y-1"
            >
              <div :for={{category, cat_total} <- categories}
                   class="flex items-center gap-2 text-xs">
                <span class="text-base-content/40 flex-1 truncate">
                  {category_label(category)}
                </span>
                <span class="font-mono text-base-content/50 tabular-nums">
                  {format_hours(cat_total)}
                </span>
                <span class="text-base-content/30 w-7 text-right tabular-nums">
                  {pct(proj_total, cat_total)}%
                </span>
              </div>
            </div>
          </div>
        </div>

        <%!-- ── By Member (admin only) ───────────────────────────────────────── --%>
        <div :if={@is_admin && @entry_count > 0 && @member_groups != []}
             class="space-y-4 border-t border-base-300 pt-6">
          <div class="flex items-center justify-between">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50">
              By Member
            </p>
            <span class="badge badge-primary badge-sm">Admin only</span>
          </div>

          <div :for={{member, member_total} <- @member_groups}
               class="flex items-center gap-3">
            <%!-- Avatar --%>
            <div class="w-8 h-8 rounded-full bg-primary text-primary-content flex items-center justify-center shrink-0">
              <span class="text-xs font-bold leading-none">
                {user_label(member) |> String.first() |> String.upcase()}
              </span>
            </div>

            <div class="flex-1 min-w-0">
              <%!-- Email + goal status --%>
              <div class="flex items-center justify-between gap-2 mb-1">
                <span class="text-sm truncate">{user_label(member)}</span>

                <div class="flex items-center gap-2 shrink-0">
                  <%!-- Actual / Goal --%>
                  <% goal_secs = if member, do: goal_secs_for_range(member, @date_from, @date_to), else: 0 %>
                  <span class={"font-mono font-semibold text-sm tabular-nums #{goal_class(member_total, goal_secs)}"}>
                    {format_hours(member_total)}
                  </span>
                  <span class="text-xs text-base-content/30">/</span>
                  <span class="font-mono text-sm tabular-nums text-base-content/40">
                    {format_hours(goal_secs)}
                  </span>
                  <%!-- Status icon --%>
                  <span :if={member_total >= goal_secs && goal_secs > 0}
                        class="text-success text-xs">✓</span>
                  <span :if={member_total < goal_secs && member_total / max(goal_secs, 1) >= 0.7}
                        class="text-warning text-xs">!</span>
                  <span :if={member_total / max(goal_secs, 1) < 0.7 && goal_secs > 0}
                        class="text-error text-xs">✗</span>
                </div>
              </div>

              <%!-- Progress bar vs goal (not vs total — vs their own target) --%>
              <progress
                class={"progress h-1.5 w-full #{goal_progress_class(member_total, goal_secs)}"}
                value={min(member_total, goal_secs)}
                max={max(goal_secs, 1)}
              />

              <%!-- Part-time label --%>
              <p :if={member && (member.weekly_hours_goal || 35.0) < 35.0}
                 class="text-xs text-base-content/30 mt-0.5">
                Part-time · {trunc(member.weekly_hours_goal || 35.0)}h/week goal
              </p>
            </div>

            <%!-- Nudge button — shown when member is behind goal --%>
            <%!-- Broadcasts via PubSub → NotificationTransport → tauri-plugin-websocket → OS popup --%>
            <button
              :if={member && member_total < goal_secs_for_range(member, @date_from, @date_to)}
              phx-click="nudge"
              phx-value-user-id={member && member.id}
              phx-value-actual={member_total}
              phx-value-goal={goal_secs_for_range(member, @date_from, @date_to)}
              title="Send a real-time reminder to this user's desktop"
              class="btn btn-ghost btn-xs gap-1 text-warning shrink-0"
            >
              <.icon name="ri-notification-2-line" class="size-3.5" />
              Nudge
            </button>
          </div>
        </div>

        <%!-- ── By Day ──────────────────────────────────────────────────────── --%>
        <div :if={@entry_count > 0} class="space-y-4 border-t border-base-300 pt-6">
          <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50">
            By Day
          </p>

          <%!-- Only show day chart if range ≤ 31 days to keep it legible --%>
          <div :if={days_in_range(@date_from, @date_to) <= 31}
               class="flex items-end gap-0.5 h-16">
            <% max_day = Enum.max(Enum.map(@daily_groups, &elem(&1, 1)), fn -> 1 end) %>
            <div :for={{day, secs} <- @daily_groups}
                 class="flex-1 flex flex-col items-center gap-1 group"
                 title={"#{Calendar.strftime(day, "%d %b")}: #{format_hours(secs)}"}>
              <div
                class={[
                  "w-full rounded-t-sm transition-opacity",
                  if(secs > 0, do: "bg-primary", else: "bg-base-300")
                ]}
                style={"height: #{if secs > 0, do: max(4, round(secs / max_day * 48)), else: 4}px"}
              />
            </div>
          </div>

          <%!-- Table view for longer ranges --%>
          <div :if={days_in_range(@date_from, @date_to) > 31} class="space-y-1">
            <div :for={{day, secs} <- @daily_groups} :if={secs > 0}
                 class="flex items-center justify-between text-sm py-1 border-b border-base-200 last:border-0">
              <span class="text-base-content/60">
                {Calendar.strftime(day, "%a, %d %b")}
              </span>
              <span class="font-mono font-semibold tabular-nums">{format_hours(secs)}</span>
            </div>
          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end
end
