defmodule QlockWeb.TimeTrackingLive do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  require Ash.Query

  alias Qlock.TimeTracking.TimeEntry
  alias Qlock.TimeTracking

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()

    {:ok,
     assign(socket,
       selected_date: today,
       entries: load_entries(today, socket.assigns.current_user)
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket,
       entries: load_entries(socket.assigns.selected_date, socket.assigns.current_user)
     )}
  end

  # ── Date navigation ────────────────────────────────────────────────────────

  @impl true
  def handle_event("prev_day", _, socket) do
    date = Date.add(socket.assigns.selected_date, -1)
    {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
  end

  @impl true
  def handle_event("next_day", _, socket) do
    if Date.compare(socket.assigns.selected_date, Date.utc_today()) != :lt do
      {:noreply, socket}
    else
      date = Date.add(socket.assigns.selected_date, 1)
      {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
    end
  end

  @impl true
  def handle_event("today", _, socket) do
    date = Date.utc_today()
    {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
  end

  # ── Data ───────────────────────────────────────────────────────────────────

  defp load_entries(date, actor) do
    TimeEntry
    |> Ash.Query.filter(date: date)
    |> Ash.read!(actor: actor, domain: TimeTracking, load: [:project, :category])
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp format_date(date) do
    dow = Calendar.strftime(date, "%A")
    Calendar.strftime(date, "#{dow}, %d %B %Y")
  end

  defp format_duration(seconds) do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)

    cond do
      h > 0 && m > 0 -> "#{h}h #{m}m"
      h > 0 -> "#{h}h"
      m > 0 -> "#{m}m"
      true -> "#{rem(seconds, 60)}s"
    end
  end

  defp total_seconds(entries), do: Enum.sum(Enum.map(entries, & &1.duration_seconds))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:time} current_user={@current_user}>
      <div class="max-w-2xl mx-auto px-6 md:px-10 py-6">

        <%!-- Header: date navigation --%>
        <div class="pb-5 border-b border-base-300 space-y-4">
          <div class="flex items-center justify-between gap-2">
            <h1 class="text-2xl font-semibold">Time Log</h1>
            <%!-- SandQlock hint --%>
            <span class="flex items-center gap-1.5 text-xs text-base-content/40 italic">
              <.icon name="ri-mac-line" class="size-3.5" />
              Managed in SandQlock
            </span>
          </div>

          <%!-- Date nav --%>
          <% is_today = @selected_date == Date.utc_today() %>
          <div class="flex items-center gap-2">
            <button
              phx-click="prev_day"
              class="btn btn-ghost btn-sm btn-square"
            >
              <.icon name="ri-arrow-left-s-line" class="size-5" />
            </button>

            <span class="flex-1 text-center font-semibold text-sm">
              {format_date(@selected_date)}
            </span>

            <button
              phx-click="next_day"
              class="btn btn-ghost btn-sm btn-square"
              disabled={is_today}
            >
              <.icon name="ri-arrow-right-s-line" class="size-5" />
            </button>

            <button
              phx-click="today"
              class={["btn btn-ghost btn-xs gap-1", is_today && "invisible"]}
            >
              <.icon name="ri-calendar-line" class="size-3.5" />
              Today
            </button>
          </div>
        </div>

        <%!-- Daily total bar --%>
        <div
          :if={@entries != []}
          class="flex items-center justify-between px-1 py-3 text-sm border-b border-base-200"
        >
          <span class="text-base-content/50">
            {length(@entries)} {if length(@entries) == 1, do: "entry", else: "entries"}
          </span>
          <span class="font-mono font-semibold">
            {format_duration(total_seconds(@entries))}
          </span>
        </div>

        <%!-- Entry list --%>
        <div class="mt-3 space-y-2">
          <div
            :for={entry <- @entries}
            class="flex items-start justify-between gap-4 px-4 py-3 rounded-lg hover:bg-base-200 transition-colors"
          >
            <%!-- Left: task + project/category --%>
            <div class="flex-1 min-w-0">
              <p class="font-medium text-sm truncate">{entry.task_name}</p>
              <p
                :if={entry.project || entry.category}
                class="text-xs text-base-content/40 mt-0.5 truncate"
              >
                <span :if={entry.project}>{entry.project.name}</span>
                <span :if={entry.project && entry.category}> › </span>
                <span :if={entry.category}>{entry.category.name}</span>
              </p>
            </div>

            <%!-- Right: duration + badges --%>
            <div class="flex items-center gap-2 shrink-0">
              <span :if={entry.overtime} class="badge badge-warning badge-sm">OT</span>
              <span class="font-mono text-sm font-semibold tabular-nums">
                {format_duration(entry.duration_seconds)}
                <span class="text-xs font-normal opacity-40 ml-1">
                  ({entry.duration_seconds}s)
                </span>
              </span>
            </div>
          </div>

          <%!-- Empty state --%>
          <div
            :if={@entries == []}
            class="flex flex-col items-center justify-center py-20 gap-4 text-base-content/30"
          >
            <.icon name="ri-time-line" class="size-12" />
            <div class="text-center space-y-1">
              <p class="text-sm font-medium">No entries for this day</p>
              <p class="text-xs">Open SandQlock on your desktop to track time</p>
            </div>
          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end
end
