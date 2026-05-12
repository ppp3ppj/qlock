defmodule QlockWeb.ProjectsLive.Show do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  alias Qlock.Projects
  alias Qlock.Projects.Category
  alias Qlock.Projects.ProjectMember

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = load_project(id, socket.assigns.current_user)

    {:ok,
     assign(socket,
       project: project,
       show_form: false,
       editing_category_id: nil,
       show_member_form: false
     )}
  end

  # --- Category events ---

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  @impl true
  def handle_event("edit_category", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_category_id: id)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_category_id: nil)}
  end

  @impl true
  def handle_event("update_category", %{"id" => id, "name" => name}, socket) do
    category = Ash.get!(Category, id, actor: socket.assigns.current_user, domain: Projects)

    category
    |> Ash.Changeset.for_update(:update, %{name: name}, actor: socket.assigns.current_user)
    |> Ash.update(domain: Projects)
    |> case do
      {:ok, _} ->
        project = load_project(socket.assigns.project.id, socket.assigns.current_user)
        {:noreply, assign(socket, project: project, editing_category_id: nil)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to update: #{inspect(error)}")}
    end
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
      {:ok, _} ->
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

  # --- Member events ---

  @impl true
  def handle_event("show_member_form", _params, socket) do
    {:noreply, assign(socket, show_member_form: true)}
  end

  @impl true
  def handle_event("cancel_member", _params, socket) do
    {:noreply, assign(socket, show_member_form: false)}
  end

  @impl true
  def handle_event("add_member", %{"email" => email}, socket) do
    project = socket.assigns.project

    # Look up the user by email. authorize?: false is intentional here —
    # the User resource's policies only allow AshAuthentication internals
    # to call get_by_email. We are already in an authenticated context so
    # bypassing policy for this read is safe.
    case Qlock.Accounts.User
         |> Ash.Query.for_read(:get_by_email, %{email: email})
         |> Ash.read_one(domain: Qlock.Accounts, authorize?: false) do
      {:ok, nil} ->
        {:noreply, put_flash(socket, :error, "No user found with email #{email}")}

      {:ok, user} ->
        ProjectMember
        |> Ash.Changeset.for_create(:create, %{project_id: project.id, user_id: user.id},
          actor: socket.assigns.current_user
        )
        |> Ash.create(domain: Projects)
        |> case do
          {:ok, _} ->
            project = load_project(project.id, socket.assigns.current_user)
            {:noreply, assign(socket, project: project, show_member_form: false)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not add member — they may already be a member")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No user found with email #{email}")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    member = Ash.get!(ProjectMember, id, actor: socket.assigns.current_user, domain: Projects)
    Ash.destroy!(member, actor: socket.assigns.current_user, domain: Projects)
    project = load_project(socket.assigns.project.id, socket.assigns.current_user)
    {:noreply, assign(socket, project: project)}
  end

  defp load_project(id, actor) do
    Ash.get!(Qlock.Projects.Project, id,
      load: [:categories, project_members: [:user]],
      actor: actor,
      domain: Projects
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:projects} current_user={@current_user}>
      <.header>
        {@project.name}
        <:actions>
          <.button navigate={~p"/projects"}>← Back</.button>
        </:actions>
      </.header>

      <%!-- Categories section --%>
      <div class="mt-6">
        <div class="flex items-center justify-between mb-2">
          <h2 class="font-semibold text-sm text-base-content/70 uppercase tracking-wide">
            Categories
          </h2>
          <.button phx-click="show_form" :if={!@show_form}>+ Add Category</.button>
        </div>

        <div :if={@show_form} class="card bg-base-200 p-4 mb-3">
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
          <:col :let={category} label="Name">
            <span :if={@editing_category_id != category.id}>{category.name}</span>
            <form
              :if={@editing_category_id == category.id}
              phx-submit="update_category"
              phx-value-id={category.id}
              class="flex gap-2 items-center"
            >
              <input
                type="text"
                name="name"
                value={category.name}
                class="input input-bordered input-sm"
                required
                autofocus
              />
              <button type="submit" class="btn btn-xs btn-primary">Save</button>
              <button type="button" phx-click="cancel_edit" class="btn btn-xs">Cancel</button>
            </form>
          </:col>
          <:action :let={category}>
            <.button
              :if={@editing_category_id != category.id}
              phx-click="edit_category"
              phx-value-id={category.id}
            >
              Edit
            </.button>
            <.button
              :if={@editing_category_id != category.id}
              phx-click="delete_category"
              phx-value-id={category.id}
              data-confirm="Delete this category?"
            >
              Delete
            </.button>
          </:action>
        </.table>
      </div>

      <%!-- Members section --%>
      <div class="mt-8">
        <div class="flex items-center justify-between mb-2">
          <h2 class="font-semibold text-sm text-base-content/70 uppercase tracking-wide">
            Members
          </h2>
          <.button phx-click="show_member_form" :if={!@show_member_form}>
            + Add Member
          </.button>
        </div>

        <div :if={@show_member_form} class="card bg-base-200 p-4 mb-3">
          <form phx-submit="add_member" class="flex gap-2 items-end">
            <div class="form-control flex-1">
              <label class="label"><span class="label-text">User Email</span></label>
              <input
                type="email"
                name="email"
                class="input input-bordered w-full"
                placeholder="user@example.com"
                required
                autofocus
              />
            </div>
            <button type="submit" class="btn btn-primary">Add</button>
            <button type="button" phx-click="cancel_member" class="btn">Cancel</button>
          </form>
        </div>

        <.table id="members" rows={@project.project_members}>
          <:col :let={member} label="Email">
            {to_string(member.user.email)}
          </:col>
          <:action :let={member}>
            <.button
              phx-click="remove_member"
              phx-value-id={member.id}
              data-confirm="Remove this member?"
            >
              Remove
            </.button>
          </:action>
        </.table>
      </div>
    </Layouts.app>
    """
  end
end
