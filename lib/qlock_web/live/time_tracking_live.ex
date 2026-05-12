defmodule QlockWeb.TimeTrackingLive do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  require Ash.Query

  alias Qlock.TimeTracking
  alias Qlock.TimeTracking.TimeEntry

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    projects = load_projects(socket.assigns.current_user)

    {:ok,
     assign(socket,
       selected_date: today,
       entries: load_entries(today, socket.assigns.current_user),
       projects: projects,
       categories: [],
       show_form: false,
       form_project_id: nil
     )}
  end

  # --- Date navigation ---

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

  # --- Form ---

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, show_form: true, form_project_id: nil, categories: [])}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  @impl true
  def handle_event("project_changed", %{"project_id" => ""}, socket) do
    {:noreply, assign(socket, form_project_id: nil, categories: [])}
  end

  @impl true
  def handle_event("project_changed", %{"project_id" => project_id}, socket) do
    categories = load_categories(project_id)
    {:noreply, assign(socket, form_project_id: project_id, categories: categories)}
  end

  @impl true
  def handle_event("save_entry", params, socket) do
    %{
      "task_name" => task_name,
      "duration" => duration_str,
      "date" => date_str,
      "overtime" => overtime
    } = params

    project_id = Map.get(params, "project_id", "") |> nilify()
    category_id = Map.get(params, "category_id", "") |> nilify()
    duration_minutes = parse_duration(duration_str)
    date = Date.from_iso8601!(date_str)
    is_overtime = overtime == "true"

    TimeEntry
    |> Ash.Changeset.for_create(:create, %{
        task_name: task_name,
        duration_minutes: duration_minutes,
        date: date,
        overtime: is_overtime,
        project_id: project_id,
        category_id: category_id
      },
      actor: socket.assigns.current_user
    )
    |> Ash.create(domain: TimeTracking)
    |> case do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(show_form: false)
         |> reload_entries()}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to save: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    entry = Ash.get!(TimeEntry, id, actor: socket.assigns.current_user, domain: TimeTracking)
    Ash.destroy!(entry, actor: socket.assigns.current_user, domain: TimeTracking)
    {:noreply, reload_entries(socket)}
  end

  # --- Helpers ---

  defp reload_entries(socket) do
    assign(socket,
      entries: load_entries(socket.assigns.selected_date, socket.assigns.current_user)
    )
  end

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
    h = div(minutes, 60)
    m = rem(minutes, 60)
    "#{h}:#{String.pad_leading("#{m}", 2, "0")}"
  end

  defp nilify(""), do: nil
  defp nilify(val), do: val

  defp format_date(date) do
    Calendar.strftime(date, "%d %B %Y")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:time} current_user={@current_user}>
      <div class="flex flex-col h-full max-w-2xl mx-auto">

        <%!-- Date navigation bar --%>
        <div class="flex items-center justify-between py-4 border-b border-base-300 mb-4">
          <button phx-click="prev_day" class="btn btn-ghost btn-sm btn-square">
            <.icon name="hero-chevron-left" class="size-5" />
          </button>

          <span class="font-semibold text-base">{format_date(@selected_date)}</span>

          <button phx-click="next_day" class="btn btn-ghost btn-sm btn-square">
            <.icon name="hero-chevron-right" class="size-5" />
          </button>
        </div>

        <%!-- Add button --%>
        <div class="mb-4">
          <button
            phx-click="show_form"
            class="btn btn-primary btn-sm gap-2"
            onclick="document.getElementById('entry-modal').showModal()"
          >
            <.icon name="hero-plus" class="size-4" /> Add Entry
          </button>
        </div>

        <%!-- Entries list --%>
        <div class="flex-1 space-y-2">
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
              <span
                :if={entry.overtime}
                class="badge badge-warning badge-sm"
              >
                OT
              </span>
              <span class="font-mono text-sm font-semibold">
                {format_duration(entry.duration_minutes)}
              </span>
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

          <%!-- Empty state --%>
          <div :if={@entries == []} class="flex flex-col items-center justify-center py-20 gap-3 text-base-content/30">
            <.icon name="hero-clock" class="size-14" />
            <p class="text-sm">No time tracked for this day</p>
          </div>
        </div>

        <%!-- Bottom bar --%>
        <div class="flex items-center justify-between pt-4 mt-4 border-t border-base-300">
          <button phx-click="today" class="flex items-center gap-1.5 text-sm text-base-content/60 hover:text-base-content transition-colors">
            <.icon name="hero-calendar" class="size-4" /> Today
          </button>
        </div>
      </div>

      <%!-- Add Entry Modal --%>
      <dialog id="entry-modal" class="modal modal-middle">
        <div class="modal-box max-w-sm">
          <h3 class="font-bold text-lg mb-4">Add Time Entry</h3>

          <form phx-submit="save_entry" class="space-y-4">
            <%!-- Date --%>
            <div class="form-control">
              <label class="label"><span class="label-text">Date</span></label>
              <input
                type="date"
                name="date"
                value={Date.to_iso8601(@selected_date)}
                class="input input-bordered w-full"
                required
              />
            </div>

            <%!-- Task name --%>
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
              />
            </div>

            <%!-- Duration --%>
            <div class="form-control">
              <label class="label"><span class="label-text">Time (HH:MM)</span></label>
              <input
                type="text"
                name="duration"
                class="input input-bordered w-full"
                placeholder="1:30"
                pattern="[0-9]+:[0-5][0-9]"
                title="Format: H:MM (e.g. 1:30)"
                required
              />
            </div>

            <%!-- Project --%>
            <div class="form-control">
              <label class="label"><span class="label-text">Project</span></label>
              <select
                name="project_id"
                class="select select-bordered w-full"
                phx-change="project_changed"
              >
                <option value="">— None —</option>
                <option :for={p <- @projects} value={p.id}>{p.name}</option>
              </select>
            </div>

            <%!-- Category (filtered by project) --%>
            <div class="form-control" :if={@categories != []}>
              <label class="label"><span class="label-text">Category</span></label>
              <select name="category_id" class="select select-bordered w-full">
                <option value="">— None —</option>
                <option :for={c <- @categories} value={c.id}>{c.name}</option>
              </select>
            </div>

            <%!-- Overtime --%>
            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-3">
                <input type="hidden" name="overtime" value="false" />
                <input type="checkbox" name="overtime" value="true" class="checkbox checkbox-sm" />
                <span class="label-text">Over time</span>
              </label>
            </div>

            <div class="modal-action mt-2">
              <button
                type="button"
                class="btn"
                onclick="document.getElementById('entry-modal').close()"
                phx-click="cancel_form"
              >
                Cancel
              </button>
              <button type="submit" class="btn btn-primary">Add</button>
            </div>
          </form>
        </div>

        <form method="dialog" class="modal-backdrop">
          <button phx-click="cancel_form">close</button>
        </form>
      </dialog>
    </Layouts.app>
    """
  end
end
