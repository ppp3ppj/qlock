defmodule QlockWeb.ProjectsLive.Index do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  alias Qlock.Projects
  alias Qlock.Projects.Project

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(show_form: false) |> load_projects()}
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  @impl true
  def handle_event("save", %{"name" => name}, socket) do
    Project
    |> Ash.Changeset.for_create(:create, %{name: name}, actor: socket.assigns.current_user)
    |> Ash.create(domain: Projects)
    |> case do
      {:ok, _project} ->
        {:noreply, socket |> put_flash(:info, "Project created") |> assign(show_form: false) |> load_projects()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to create project")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    project = Ash.get!(Project, id, actor: socket.assigns.current_user, domain: Projects)
    Ash.destroy!(project, actor: socket.assigns.current_user, domain: Projects)
    {:noreply, socket |> put_flash(:info, "Project deleted") |> load_projects()}
  end

  defp load_projects(socket) do
    projects = Ash.read!(Project, actor: socket.assigns.current_user, domain: Projects)
    assign(socket, projects: projects)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:projects} current_user={@current_user}>
      <.header>
        Projects
        <:actions>
          <.button phx-click="show_form" :if={!@show_form}>+ New Project</.button>
        </:actions>
      </.header>

      <div :if={@show_form} class="card bg-base-200 p-4 my-4">
        <form phx-submit="save" class="flex gap-2 items-end">
          <div class="form-control flex-1">
            <label class="label"><span class="label-text">Project Name</span></label>
            <input
              type="text"
              name="name"
              class="input input-bordered w-full"
              placeholder="e.g. DevOps"
              required
              autofocus
            />
          </div>
          <button type="submit" class="btn btn-primary">Create</button>
          <button type="button" phx-click="cancel" class="btn">Cancel</button>
        </form>
      </div>

      <.table
        id="projects"
        rows={@projects}
        row_click={fn project -> JS.navigate(~p"/projects/#{project.id}") end}
      >
        <:col :let={project} label="Name">{project.name}</:col>
        <:action :let={project}>
          <.button navigate={~p"/projects/#{project.id}"}>View</.button>
          <.button
            phx-click="delete"
            phx-value-id={project.id}
            data-confirm="Delete this project and all its categories?"
          >
            Delete
          </.button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end
end
