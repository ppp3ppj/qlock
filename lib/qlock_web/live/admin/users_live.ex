defmodule QlockWeb.Admin.UsersLive do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  @default_goal 35.0   # 7h × 5 days

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user.role != :admin do
      {:ok, push_navigate(socket, to: ~p"/projects")}
    else
      {:ok,
       assign(socket,
         users: load_users(),
         editing_goal_id: nil
       )}
    end
  end

  # ── Events ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("edit_goal", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_goal_id: id)}
  end

  def handle_event("save_goal", %{"id" => id, "value" => raw}, socket) do
    goal =
      case Float.parse(String.trim(raw)) do
        {val, _} when val > 0 -> val
        _ -> nil
      end

    Qlock.Accounts.User
    |> Ash.get!(id, domain: Qlock.Accounts, authorize?: false)
    |> Ash.Changeset.for_update(:set_weekly_goal, %{weekly_hours_goal: goal},
        actor: socket.assigns.current_user)
    |> Ash.update(domain: Qlock.Accounts)

    {:noreply, assign(socket, users: load_users(), editing_goal_id: nil)}
  end

  def handle_event("keydown_goal", %{"key" => "Escape"}, socket),
    do: {:noreply, assign(socket, editing_goal_id: nil)}

  def handle_event("keydown_goal", _, socket), do: {:noreply, socket}

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp load_users do
    {:ok, users} = Ash.read(Qlock.Accounts.User, domain: Qlock.Accounts, authorize?: false)
    Enum.sort_by(users, &to_string(&1.email))
  end

  defp effective_goal(nil), do: @default_goal
  defp effective_goal(h), do: h

  defp format_goal(nil), do: "#{trunc(@default_goal)}h"
  defp format_goal(h) do
    if h == trunc(h), do: "#{trunc(h)}h", else: "#{h}h"
  end

  # ── Render ────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :default_goal, @default_goal)

    ~H"""
    <Layouts.app flash={@flash} current_page={:admin} current_user={@current_user}>
      <div class="max-w-3xl mx-auto px-6 md:px-10 py-6 space-y-6">

        <%!-- Header --%>
        <div class="pb-5 border-b border-base-300 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Team</h1>
            <p class="text-sm text-base-content/50 mt-0.5">
              {length(@users)} members · set weekly hour goals per person
            </p>
          </div>
          <span class="badge badge-primary badge-sm gap-1">
            <.icon name="ri-shield-star-line" class="size-3" /> Admin only
          </span>
        </div>

        <%!-- Legend --%>
        <div class="flex items-start gap-2 text-xs text-base-content/50 bg-base-200 rounded-lg px-4 py-3">
          <.icon name="ri-information-line" class="size-4 shrink-0 mt-0.5" />
          <span>
            Weekly goal is used in Reports to show each member's progress.
            Default is <strong>{trunc(@default_goal)}h</strong> (7h × 5 days).
            Click any goal to edit it. Set lower for part-timers.
          </span>
        </div>

        <%!-- User rows --%>
        <div class="divide-y divide-base-200">
          <div
            :for={user <- @users}
            class="flex items-center gap-4 py-3 group"
          >
            <%!-- Avatar --%>
            <div class="w-9 h-9 rounded-full bg-primary text-primary-content flex items-center justify-center shrink-0">
              <span class="text-sm font-bold leading-none select-none">
                {to_string(user.email) |> String.first() |> String.upcase()}
              </span>
            </div>

            <%!-- Email + role --%>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium truncate">{to_string(user.email)}</p>
              <p class="text-xs text-base-content/40 mt-0.5">
                {if user.role == :admin, do: "Admin", else: "Member"}
                · {effective_goal(user.weekly_hours_goal) |> trunc()}h / week
              </p>
            </div>

            <%!-- Weekly goal — click to edit --%>
            <div class="shrink-0 flex items-center gap-2">
              <span class="text-xs text-base-content/40">Weekly goal</span>

              <%!-- View mode: click to open edit --%>
              <span
                :if={@editing_goal_id != to_string(user.id)}
                phx-click="edit_goal"
                phx-value-id={user.id}
                class={[
                  "font-mono text-sm font-semibold cursor-text px-2 py-0.5 rounded",
                  "hover:bg-base-300 transition-colors min-w-14 text-center",
                  is_nil(user.weekly_hours_goal) && "text-base-content/40"
                ]}
                title="Click to edit"
              >
                {format_goal(user.weekly_hours_goal)}
              </span>

              <%!-- Edit mode: number input --%>
              <div :if={@editing_goal_id == to_string(user.id)}
                   class="flex items-center gap-1">
                <input
                  id={"goal-#{user.id}"}
                  type="number"
                  step="0.5"
                  min="1"
                  max="80"
                  value={user.weekly_hours_goal || @default_goal}
                  phx-blur="save_goal"
                  phx-value-id={user.id}
                  phx-keydown="keydown_goal"
                  phx-hook="AutoFocus"
                  class="input input-bordered input-sm w-20 font-mono text-center"
                />
                <span class="text-xs text-base-content/40">h/wk</span>
              </div>
            </div>
          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end
end
