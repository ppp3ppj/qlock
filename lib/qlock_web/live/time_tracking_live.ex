defmodule QlockWeb.TimeTrackingLive do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  require Ash.Query

  alias Qlock.TimeTracking
  alias Qlock.TimeTracking.TimeEntry

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       selected_date: Date.utc_today(),
       entries: [],
       projects: load_projects(socket.assigns.current_user),
       categories: [],
       form_project_id: nil,
       editing_entry: nil
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket,
      entries: load_entries(socket.assigns.selected_date, socket.assigns.current_user),
      editing_entry: nil
    )
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, editing_entry: nil, categories: [], form_project_id: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    entry =
      Ash.get!(TimeEntry, id,
        actor: socket.assigns.current_user,
        domain: TimeTracking,
        load: [:project, :category]
      )

    categories =
      if entry.project_id,
        do: load_categories(entry.project_id),
        else: []

    assign(socket,
      editing_entry: entry,
      form_project_id: entry.project_id,
      categories: categories
    )
  end

  # --- Date navigation (index only) ---

  @impl true
  def handle_event("prev_day", _params, socket) do
    date = Date.add(socket.assigns.selected_date, -1)
    {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
  end

  @impl true
  def handle_event("next_day", _params, socket) do
    date = Date.add(socket.assigns.selected_date, 1)
    {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
  end

  @impl true
  def handle_event("today", _params, socket) do
    date = Date.utc_today()
    {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
  end

  # --- Form events (new + edit) ---

  @impl true
  def handle_event("project_changed", %{"project_id" => ""}, socket) do
    {:noreply, assign(socket, form_project_id: nil, categories: [])}
  end

  @impl true
  def handle_event("project_changed", %{"project_id" => project_id}, socket) do
    {:noreply, assign(socket, form_project_id: project_id, categories: load_categories(project_id))}
  end

  @impl true
  def handle_event("save_entry", params, socket) do
    %{"task_name" => task_name, "duration" => duration_str, "date" => date_str, "overtime" => overtime} = params

    attrs = %{
      task_name: task_name,
      duration_minutes: parse_duration(duration_str),
      date: Date.from_iso8601!(date_str),
      overtime: overtime == "true",
      project_id: params |> Map.get("project_id", "") |> nilify(),
      category_id: params |> Map.get("category_id", "") |> nilify()
    }

    result =
      case socket.assigns.live_action do
        :new ->
          TimeEntry
          |> Ash.Changeset.for_create(:create, attrs, actor: socket.assigns.current_user)
          |> Ash.create(domain: TimeTracking)

        :edit ->
          socket.assigns.editing_entry
          |> Ash.Changeset.for_update(:update, attrs, actor: socket.assigns.current_user)
          |> Ash.update(domain: TimeTracking)
      end

    case result do
      {:ok, _} ->
        {:noreply, push_navigate(socket, to: ~p"/time")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    entry = Ash.get!(TimeEntry, id, actor: socket.assigns.current_user, domain: TimeTracking)
    Ash.destroy!(entry, actor: socket.assigns.current_user, domain: TimeTracking)
    date = socket.assigns.selected_date
    {:noreply, assign(socket, entries: load_entries(date, socket.assigns.current_user))}
  end

  # --- Helpers ---

  defp load_entries(date, actor) do
    TimeEntry
    |> Ash.Query.filter(date: date)
    |> Ash.read!(actor: actor, domain: TimeTracking, load: [:project, :category])
  end

  defp load_projects(actor) do
    Qlock.Projects.Project
    |> Ash.read!(actor: actor, domain: Qlock.Projects)
  end

  defp load_categories(project_id) do
    Qlock.Projects.Category
    |> Ash.Query.filter(project_id: project_id)
    |> Ash.read!(domain: Qlock.Projects, authorize?: false)
  end

  defp parse_duration(""), do: 0
  defp parse_duration(str) do
    case String.split(str, ":") do
      [h, m] -> String.to_integer(h) * 60 + String.to_integer(m)
      [h] -> String.to_integer(h) * 60
    end
  end

  defp format_duration(minutes) do
    "#{div(minutes, 60)}:#{String.pad_leading("#{rem(minutes, 60)}", 2, "0")}"
  end

  defp nilify(""), do: nil
  defp nilify(val), do: val

  defp format_date(date), do: Calendar.strftime(date, "%d %B %Y")

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:time} current_user={@current_user}>
      <div class="max-w-2xl mx-auto">

        <%= if @live_action == :index do %>
          <%!-- Date navigation --%>
          <div class="flex items-center justify-between py-4 border-b border-base-300 mb-4">
            <button phx-click="prev_day" class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-chevron-left" class="size-5" />
            </button>
            <span class="font-semibold text-base">{format_date(@selected_date)}</span>
            <button phx-click="next_day" class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-chevron-right" class="size-5" />
            </button>
          </div>

          <div class="mb-4">
            <.link navigate={~p"/time/new"} class="btn btn-primary btn-sm gap-2">
              <.icon name="hero-plus" class="size-4" /> Add Entry
            </.link>
          </div>

          <%!-- Entries --%>
          <div class="space-y-2">
            <div
              :for={entry <- @entries}
              class="card bg-base-200 px-4 py-3 flex flex-row items-start justify-between gap-3"
            >
              <div class="flex-1 min-w-0">
                <p class="font-medium text-sm">{entry.task_name}</p>
                <p class="text-xs text-base-content/50 mt-0.5">
                  <span :if={entry.project}>{entry.project.name}</span>
                  <span :if={entry.project && entry.category}> / </span>
                  <span :if={entry.category}>{entry.category.name}</span>
                </p>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                <span :if={entry.overtime} class="badge badge-warning badge-sm">OT</span>
                <span class="font-mono text-sm font-semibold">{format_duration(entry.duration_minutes)}</span>
                <.link navigate={~p"/time/#{entry.id}/edit"} class="btn btn-ghost btn-xs">
                  <.icon name="hero-pencil" class="size-3.5" />
                </.link>
                <button
                  phx-click="delete_entry"
                  phx-value-id={entry.id}
                  data-confirm="Delete this entry?"
                  class="btn btn-ghost btn-xs text-error"
                >
                  <.icon name="hero-trash" class="size-3.5" />
                </button>
              </div>
            </div>

            <div :if={@entries == []} class="flex flex-col items-center justify-center py-20 gap-3 text-base-content/30">
              <.icon name="hero-clock" class="size-14" />
              <p class="text-sm">No time tracked for this day</p>
            </div>
          </div>

          <div class="flex items-center justify-between pt-4 mt-4 border-t border-base-300">
            <button phx-click="today" class="flex items-center gap-1.5 text-sm text-base-content/60 hover:text-base-content transition-colors">
              <.icon name="hero-calendar" class="size-4" /> Today
            </button>
          </div>

        <% else %>
          <%!-- New / Edit form page --%>
          <div class="py-4 border-b border-base-300 mb-6 flex items-center gap-3">
            <.link navigate={~p"/time"} class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-arrow-left" class="size-4" />
            </.link>
            <h1 class="font-semibold text-base">
              {if @live_action == :new, do: "New Entry", else: "Edit Entry"}
            </h1>
          </div>

          <form phx-submit="save_entry" class="space-y-4">
            <div class="grid grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text">Date</span></label>
                <input
                  type="date"
                  name="date"
                  value={if @editing_entry, do: Date.to_iso8601(@editing_entry.date), else: Date.to_iso8601(@selected_date)}
                  class="input input-bordered w-full"
                  required
                />
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Time (H:MM)</span></label>
                <input
                  type="text"
                  name="duration"
                  value={if @editing_entry, do: format_duration(@editing_entry.duration_minutes), else: ""}
                  class="input input-bordered w-full"
                  placeholder="1:30"
                  pattern="[0-9]+:[0-5][0-9]"
                  title="Format: H:MM"
                  required
                  autofocus
                />
              </div>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Task name</span>
                <span class="label-text-alt text-error">required</span>
              </label>
              <textarea
                name="task_name"
                class="textarea textarea-bordered w-full"
                placeholder="What did you work on?"
                rows="3"
                required
              >{if @editing_entry, do: @editing_entry.task_name}</textarea>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text">Project</span></label>
                <select
                  name="project_id"
                  class="select select-bordered w-full"
                  phx-change="project_changed"
                >
                  <option value="">— None —</option>
                  <option
                    :for={p <- @projects}
                    value={p.id}
                    selected={@editing_entry && @editing_entry.project_id == p.id}
                  >
                    {p.name}
                  </option>
                </select>
              </div>
              <div class="form-control">
                <label class="label"><span class="label-text">Category</span></label>
                <select name="category_id" class="select select-bordered w-full" disabled={@categories == []}>
                  <option value="">— None —</option>
                  <option
                    :for={c <- @categories}
                    value={c.id}
                    selected={@editing_entry && @editing_entry.category_id == c.id}
                  >
                    {c.name}
                  </option>
                </select>
              </div>
            </div>

            <div class="flex items-center justify-between pt-2">
              <label class="label cursor-pointer gap-3 p-0">
                <input type="hidden" name="overtime" value="false" />
                <input
                  type="checkbox"
                  name="overtime"
                  value="true"
                  class="checkbox checkbox-sm"
                  checked={@editing_entry && @editing_entry.overtime}
                />
                <span class="label-text">Over time</span>
              </label>

              <div class="flex gap-2">
                <.link navigate={~p"/time"} class="btn btn-sm">Cancel</.link>
                <button type="submit" class="btn btn-primary btn-sm">
                  {if @live_action == :new, do: "Add", else: "Save"}
                </button>
              </div>
            </div>
          </form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
