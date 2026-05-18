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
       form: nil
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket,
      entries: load_entries(socket.assigns.selected_date, socket.assigns.current_user),
      form: nil
    )
  end

  defp apply_action(socket, :new, _params) do
    form =
      AshPhoenix.Form.for_create(TimeEntry, :create,
        as: "entry",
        actor: socket.assigns.current_user,
        domain: TimeTracking
      )

    assign(socket, form: to_form(form), categories: [], raw_duration: "", duration_error: nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    entry =
      Ash.get!(TimeEntry, id,
        actor: socket.assigns.current_user,
        domain: TimeTracking,
        load: [:project, :category]
      )

    form =
      AshPhoenix.Form.for_update(entry, :update,
        as: "entry",
        actor: socket.assigns.current_user,
        domain: TimeTracking
      )

    categories =
      if entry.project_id, do: load_categories(entry.project_id), else: []

    assign(socket,
      form: to_form(%{form | errors: true}),
      categories: categories,
      raw_duration: format_duration(entry.duration_seconds),
      duration_error: nil
    )
  end

  # --- Date navigation ---

  @impl true
  def handle_event("prev_day", _params, socket) do
    date = Date.add(socket.assigns.selected_date, -1)
    {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
  end

  @impl true
  def handle_event("next_day", _params, socket) do
    if Date.compare(socket.assigns.selected_date, Date.utc_today()) != :lt do
      {:noreply, socket}
    else
      date = Date.add(socket.assigns.selected_date, 1)
      {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
    end
  end

  @impl true
  def handle_event("today", _params, socket) do
    date = Date.utc_today()
    {:noreply, assign(socket, selected_date: date, entries: load_entries(date, socket.assigns.current_user))}
  end

  # --- Form events ---

  @impl true
  def handle_event("validate", %{"entry" => params}, socket) do
    categories =
      case Map.get(params, "project_id", "") do
        "" -> []
        id -> load_categories(id)
      end

    raw = Map.get(params, "duration_seconds", "")
    {parsed, duration_error} = validate_duration(raw)
    params = Map.put(params, "duration_seconds", parsed)

    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> Map.put(:errors, true)
      |> to_form()

    {:noreply, assign(socket, form: form, categories: categories, raw_duration: raw, duration_error: duration_error)}
  end

  @impl true
  def handle_event("save_entry", %{"entry" => params}, socket) do
    raw = Map.get(params, "duration_seconds", "")
    {parsed, duration_error} = validate_duration(raw)

    date_error =
      case Date.from_iso8601(Map.get(params, "date", "")) do
        {:ok, d} ->
          if Date.compare(d, Date.utc_today()) == :gt, do: "cannot be a future date"
        _ ->
          nil
      end

    cond do
      duration_error ->
        form =
          socket.assigns.form.source
          |> AshPhoenix.Form.validate(Map.put(params, "duration_seconds", nil))
          |> Map.put(:errors, true)
          |> to_form()

        {:noreply, assign(socket, form: form, raw_duration: raw, duration_error: duration_error)}

      date_error ->
        form =
          socket.assigns.form.source
          |> AshPhoenix.Form.validate(params)
          |> Map.put(:errors, true)
          |> to_form()

        {:noreply,
         socket
         |> assign(form: form, raw_duration: raw, duration_error: nil)
         |> put_flash(:error, "Date #{date_error}")}

      true ->
        params = Map.put(params, "duration_seconds", parsed)

        case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
          {:ok, _entry} ->
            {:noreply, push_navigate(socket, to: ~p"/time")}

          {:error, form} ->
            {:noreply, assign(socket, form: to_form(form), raw_duration: raw, duration_error: nil)}
        end
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

  # Returns {seconds_string, nil} on success or {nil, error_message} on failure.
  # User input: "H:MM" (hours:minutes) or a plain integer (minutes).
  defp validate_duration(""), do: {nil, "can't be blank"}

  defp validate_duration(str) do
    parse_int = fn s ->
      case Integer.parse(String.trim(s)) do
        {n, ""} -> {:ok, n}
        _ -> :error
      end
    end

    result =
      case String.split(str, ":", parts: 2) do
        [h_str, m_str] ->
          with {:ok, h} <- parse_int.(h_str),
               {:ok, m} <- parse_int.(m_str),
               true <- m in 0..59 do
            {:ok, "#{(h * 60 + m) * 60}"}
          else
            _ -> :invalid
          end

        [h_str] ->
          case parse_int.(h_str) do
            {:ok, m} -> {:ok, "#{m * 60}"}  # treat plain number as minutes → convert to seconds
            _ -> :invalid
          end
      end

    case result do
      {:ok, minutes} -> {minutes, nil}
      :invalid -> {nil, "must be in H:MM format (e.g. 1:30)"}
    end
  end

  defp format_duration(seconds) do
    total_minutes = div(seconds, 60)
    h = div(total_minutes, 60)
    m = rem(total_minutes, 60)
    "#{h}:#{String.pad_leading("#{m}", 2, "0")}"
  end

  defp format_date(date), do: Calendar.strftime(date, "%d %B %Y")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:time} current_user={@current_user}>
      <div class="max-w-2xl mx-auto">

        <%= if @live_action == :index do %>
          <%!-- Date navigation --%>
          <% is_today = @selected_date == Date.utc_today() %>
          <div class="flex items-center justify-between py-4 border-b border-base-300 mb-4">
            <button phx-click="prev_day" class="btn btn-ghost btn-sm btn-square">
              <.icon name="ri-arrow-left-s-line" class="size-5" />
            </button>
            <span class="font-semibold text-base">{format_date(@selected_date)}</span>
            <button
              phx-click="next_day"
              class="btn btn-ghost btn-sm btn-square"
              disabled={is_today}
            >
              <.icon name="ri-arrow-right-s-line" class="size-5" />
            </button>
          </div>

          <div :if={is_today} class="mb-4">
            <.link navigate={~p"/time/new"} class="btn btn-primary btn-sm gap-2">
              <.icon name="ri-add-line" class="size-4" /> Add Entry
            </.link>
          </div>

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
                <span class="font-mono text-sm font-semibold">
                  {format_duration(entry.duration_seconds)}
                </span>
                <.link navigate={~p"/time/#{entry.id}/edit"} class="btn btn-ghost btn-xs">
                  <.icon name="ri-pencil-line" class="size-3.5" />
                </.link>
                <button
                  phx-click="delete_entry"
                  phx-value-id={entry.id}
                  data-confirm="Delete this entry?"
                  class="btn btn-ghost btn-xs text-error"
                >
                  <.icon name="ri-delete-bin-line" class="size-3.5" />
                </button>
              </div>
            </div>

            <div :if={@entries == []} class="flex flex-col items-center justify-center py-20 gap-3 text-base-content/30">
              <.icon name="ri-time-line" class="size-14" />
              <p class="text-sm">No time tracked for this day</p>
            </div>
          </div>

          <div class="flex items-center pt-4 mt-4 border-t border-base-300">
            <button phx-click="today" class="flex items-center gap-1.5 text-sm text-base-content/60 hover:text-base-content transition-colors">
              <.icon name="ri-calendar-line" class="size-4" /> Today
            </button>
          </div>

        <% else %>
          <%!-- New / Edit form page --%>
          <div class="py-4 border-b border-base-300 mb-6 flex items-center gap-3">
            <.link navigate={~p"/time"} class="btn btn-ghost btn-sm btn-square">
              <.icon name="ri-arrow-left-line" class="size-4" />
            </.link>
            <h1 class="font-semibold text-base">
              {if @live_action == :new, do: "New Entry", else: "Edit Entry"}
            </h1>
          </div>

          <.form
            for={@form}
            phx-change="validate"
            phx-submit="save_entry"
            class="space-y-4"
            novalidate
          >
            <div class="grid grid-cols-2 gap-4">
              <.input
                field={@form[:date]}
                type="date"
                label="Date"
                value={Date.to_iso8601(@selected_date)}
                max={Date.to_iso8601(Date.utc_today())}
              />
              <%!-- Duration: raw string kept in @raw_duration; @duration_error for format errors --%>
              <div class="form-control">
                <label class="label"><span class="label-text">Time (H:MM)</span></label>
                <input
                  type="text"
                  name="entry[duration_seconds]"
                  value={@raw_duration}
                  class={["input input-bordered w-full", @duration_error && "input-error"]}
                  placeholder="1:30"
                />
                <div :if={@duration_error} class="label">
                  <span class="label-text-alt text-error">{@duration_error}</span>
                </div>
              </div>
            </div>

            <.input field={@form[:task_name]} type="textarea" label="Task name" rows={3} />

            <div class="grid grid-cols-2 gap-4">
              <div class="form-control">
                <label class="label"><span class="label-text">Project</span></label>
                <select name="entry[project_id]" class="select select-bordered w-full">
                  <option value="">— None —</option>
                  <option
                    :for={p <- @projects}
                    value={p.id}
                    selected={@form[:project_id].value == p.id}
                  >
                    {p.name}
                  </option>
                </select>
              </div>

              <div class="form-control">
                <label class="label"><span class="label-text">Category</span></label>
                <select
                  name="entry[category_id]"
                  class="select select-bordered w-full"
                  disabled={@categories == []}
                >
                  <option value="">— None —</option>
                  <option
                    :for={c <- @categories}
                    value={c.id}
                    selected={@form[:category_id].value == c.id}
                  >
                    {c.name}
                  </option>
                </select>
              </div>
            </div>

            <label class="label cursor-pointer justify-start gap-3 p-0">
              <input type="hidden" name="entry[overtime]" value="false" />
              <input
                type="checkbox"
                name="entry[overtime]"
                value="true"
                class="checkbox checkbox-sm"
                checked={@form[:overtime].value == true}
              />
              <span class="label-text">Over time</span>
            </label>

            <div class="flex justify-end gap-2 pt-2">
              <.link navigate={~p"/time"} class="btn btn-sm">Cancel</.link>
              <button type="submit" class="btn btn-primary btn-sm">
                {if @live_action == :new, do: "Add", else: "Save"}
              </button>
            </div>
          </.form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
