defmodule QlockWeb.ProjectsLive.Show do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  alias Qlock.Projects
  alias Qlock.Projects.Category

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = load_project(id, socket.assigns.current_user)
    {:ok, assign(socket, project: project, show_form: false)}
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
  def handle_event("save_category", %{"name" => name}, socket) do
    project = socket.assigns.project

    Category
    |> Ash.Changeset.for_create(:create, %{name: name, project_id: project.id},
      actor: socket.assigns.current_user
    )
    |> Ash.create(domain: Projects)
    |> case do
      {:ok, _category} ->
        project = load_project(project.id, socket.assigns.current_user)
        {:noreply, assign(socket, project: project, show_form: false)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to add category: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Ash.get!(Category, id, actor: socket.assigns.current_user, domain: Projects)
    Ash.destroy!(category, actor: socket.assigns.current_user, domain: Projects)
    project = load_project(socket.assigns.project.id, socket.assigns.current_user)
    {:noreply, assign(socket, project: project)}
  end

  defp load_project(id, actor) do
    Ash.get!(Qlock.Projects.Project, id,
      load: [:categories],
      actor: actor,
      domain: Projects
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@project.name}
        <:subtitle>Categories</:subtitle>
        <:actions>
          <.button navigate={~p"/projects"}>← Back</.button>
          <.button phx-click="show_form" :if={!@show_form}>+ Add Category</.button>
        </:actions>
      </.header>

      <div :if={@show_form} class="card bg-base-200 p-4 my-4">
        <form phx-submit="save_category" class="flex gap-2 items-end">
          <div class="form-control flex-1">
            <label class="label"><span class="label-text">Category Name</span></label>
            <input
              type="text"
              name="name"
              class="input input-bordered w-full"
              placeholder="e.g. Meeting"
              required
              autofocus
            />
          </div>
          <button type="submit" class="btn btn-primary">Add</button>
          <button type="button" phx-click="cancel" class="btn">Cancel</button>
        </form>
      </div>

      <.table id="categories" rows={@project.categories}>
        <:col :let={category} label="Category">{category.name}</:col>
        <:action :let={category}>
          <.button
            phx-click="delete_category"
            phx-value-id={category.id}
            data-confirm="Delete this category?"
          >
            Delete
          </.button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end
end
