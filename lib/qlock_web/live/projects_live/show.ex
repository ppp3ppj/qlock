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
       editing_project_name: false,
       editing_project_desc: false,
       show_form: false,
       editing_category_id: nil,
       editing_category_desc_id: nil,
       show_member_form: false
     )}
  end

  # --- Project name (click → input, blur → save, Escape → cancel) ---

  def handle_event("edit_project_name", _, socket),
    do: {:noreply, assign(socket, editing_project_name: true)}

  def handle_event("save_project_name", %{"value" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, editing_project_name: false)}
    else
      socket.assigns.project
      |> Ash.Changeset.for_update(:update, %{name: name}, actor: socket.assigns.current_user)
      |> Ash.update(domain: Projects)
      |> case do
        {:ok, _} ->
          project = load_project(socket.assigns.project.id, socket.assigns.current_user)
          {:noreply, assign(socket, project: project, editing_project_name: false)}

        {:error, _} ->
          {:noreply, assign(socket, editing_project_name: false)}
      end
    end
  end

  def handle_event("keydown_project_name", %{"key" => "Escape"}, socket),
    do: {:noreply, assign(socket, editing_project_name: false)}

  def handle_event("keydown_project_name", _, socket), do: {:noreply, socket}

  # --- Project description (click → textarea, blur → save, Escape → cancel) ---

  def handle_event("edit_project_desc", _, socket),
    do: {:noreply, assign(socket, editing_project_desc: true)}

  def handle_event("save_project_desc", %{"value" => desc}, socket) do
    socket.assigns.project
    |> Ash.Changeset.for_update(:update, %{description: desc}, actor: socket.assigns.current_user)
    |> Ash.update(domain: Projects)
    |> case do
      {:ok, _} ->
        project = load_project(socket.assigns.project.id, socket.assigns.current_user)
        {:noreply, assign(socket, project: project, editing_project_desc: false)}

      {:error, _} ->
        {:noreply, assign(socket, editing_project_desc: false)}
    end
  end

  def handle_event("keydown_project_desc", %{"key" => "Escape"}, socket),
    do: {:noreply, assign(socket, editing_project_desc: false)}

  def handle_event("keydown_project_desc", _, socket), do: {:noreply, socket}

  # --- Category section: add ---

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: true)}

  def handle_event("cancel", _, socket),
    do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save_category", %{"name" => name}, socket) do
    Category
    |> Ash.Changeset.for_create(:create, %{name: name, project_id: socket.assigns.project.id},
      actor: socket.assigns.current_user
    )
    |> Ash.create(domain: Projects)
    |> case do
      {:ok, _} ->
        project = load_project(socket.assigns.project.id, socket.assigns.current_user)
        {:noreply, assign(socket, project: project, show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add section")}
    end
  end

  # --- Category name (click → input, blur → save, Escape → cancel) ---

  def handle_event("edit_category", %{"id" => id}, socket),
    do: {:noreply, assign(socket, editing_category_id: id, editing_category_desc_id: nil)}

  def handle_event("save_category_name", %{"id" => id, "value" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, assign(socket, editing_category_id: nil)}
    else
      Ash.get!(Category, id, actor: socket.assigns.current_user, domain: Projects)
      |> Ash.Changeset.for_update(:update, %{name: name}, actor: socket.assigns.current_user)
      |> Ash.update(domain: Projects)
      |> case do
        {:ok, _} ->
          project = load_project(socket.assigns.project.id, socket.assigns.current_user)
          {:noreply, assign(socket, project: project, editing_category_id: nil)}

        {:error, _} ->
          {:noreply, assign(socket, editing_category_id: nil)}
      end
    end
  end

  def handle_event("keydown_category_name", %{"key" => "Escape"}, socket),
    do: {:noreply, assign(socket, editing_category_id: nil)}

  def handle_event("keydown_category_name", _, socket), do: {:noreply, socket}

  # --- Category description (click → textarea, blur → save, Escape → cancel) ---

  def handle_event("edit_category_desc", %{"id" => id}, socket),
    do: {:noreply, assign(socket, editing_category_desc_id: id, editing_category_id: nil)}

  def handle_event("save_category_desc", %{"id" => id, "value" => desc}, socket) do
    Ash.get!(Category, id, actor: socket.assigns.current_user, domain: Projects)
    |> Ash.Changeset.for_update(:update, %{description: desc}, actor: socket.assigns.current_user)
    |> Ash.update(domain: Projects)
    |> case do
      {:ok, _} ->
        project = load_project(socket.assigns.project.id, socket.assigns.current_user)
        {:noreply, assign(socket, project: project, editing_category_desc_id: nil)}

      {:error, _} ->
        {:noreply, assign(socket, editing_category_desc_id: nil)}
    end
  end

  def handle_event("keydown_category_desc", %{"key" => "Escape"}, socket),
    do: {:noreply, assign(socket, editing_category_desc_id: nil)}

  def handle_event("keydown_category_desc", _, socket), do: {:noreply, socket}

  # --- Category delete ---

  def handle_event("delete_category", %{"id" => id}, socket) do
    Ash.get!(Category, id, actor: socket.assigns.current_user, domain: Projects)
    |> Ash.destroy!(actor: socket.assigns.current_user, domain: Projects)

    project = load_project(socket.assigns.project.id, socket.assigns.current_user)
    {:noreply, assign(socket, project: project)}
  end

  # --- Members ---

  def handle_event("show_member_form", _, socket),
    do: {:noreply, assign(socket, show_member_form: true)}

  def handle_event("cancel_member", _, socket),
    do: {:noreply, assign(socket, show_member_form: false)}

  def handle_event("add_member", %{"email" => email}, socket) do
    project = socket.assigns.project

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
            {:noreply,
             put_flash(socket, :error, "Could not add member — they may already be a member")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No user found with email #{email}")}
    end
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    Ash.get!(ProjectMember, id, actor: socket.assigns.current_user, domain: Projects)
    |> Ash.destroy!(actor: socket.assigns.current_user, domain: Projects)

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
      <div class="relative w-full max-w-[65rem] px-4 sm:pl-8 sm:pr-16 md:pl-16 pt-4 sm:py-5 mx-auto space-y-10">

        <%!-- Project header --%>
        <div class="pb-6 border-b border-base-300 space-y-4">

          <%!-- Title: click to edit, blur to save --%>
          <div class="flex items-start justify-between gap-3">
            <h1
              :if={!@editing_project_name}
              phx-click="edit_project_name"
              class="text-3xl font-semibold cursor-text px-1 -mx-1 rounded hover:bg-base-200 transition-colors"
            >
              {@project.name}
            </h1>

            <input
              :if={@editing_project_name}
              id="project-name-input"
              type="text"
              value={@project.name}
              phx-blur="save_project_name"
              phx-keydown="keydown_project_name"
              phx-hook="AutoFocus"
              class="text-3xl font-semibold w-full bg-transparent border-b-2 border-primary outline-none px-1 -mx-1"
            />

            <.link navigate={~p"/projects"} class="btn btn-ghost btn-sm shrink-0 mt-1">
              ← Back
            </.link>
          </div>

          <%!-- Description: click to edit, blur to save --%>
          <div
            :if={!@editing_project_desc}
            phx-click="edit_project_desc"
            class="cursor-text rounded-lg px-2 py-1 -mx-2 hover:bg-base-200 transition-colors min-h-8"
          >
            <div :if={@project.description} class="markdown">
              {Phoenix.HTML.raw(Qlock.Markdown.to_html(@project.description))}
            </div>
            <p :if={!@project.description} class="text-base-content/40 italic text-sm">
              Click to add a project description... (supports Markdown)
            </p>
          </div>

          <textarea
            :if={@editing_project_desc}
            id="project-desc-textarea"
            phx-blur="save_project_desc"
            phx-keydown="keydown_project_desc"
            phx-hook="AutoFocus"
            class="textarea textarea-bordered w-full font-mono text-sm min-h-32"
            rows="6"
            placeholder="Write in Markdown...&#10;&#10;**bold**, *italic*, `code`, ## Heading, - list"
          >{@project.description}</textarea>
        </div>

        <%!-- Sections --%>
        <div class="space-y-8">
          <div class="flex items-center justify-between">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50">
              Sections
            </p>
            <button
              :if={!@show_form}
              phx-click="show_form"
              class="btn btn-ghost btn-sm gap-1"
            >
              <.icon name="ri-add-line" class="size-4" /> Add Section
            </button>
          </div>

          <%!-- New section form --%>
          <div :if={@show_form} class="border border-dashed border-base-300 rounded-xl p-5">
            <form phx-submit="save_category" class="space-y-2">
              <input
                id="new-section-input"
                type="text"
                name="name"
                class="input input-bordered w-full"
                placeholder="Section name..."
                required
                phx-hook="AutoFocus"
              />
              <div class="flex gap-2">
                <button type="submit" class="btn btn-primary btn-sm">Add</button>
                <button type="button" phx-click="cancel" class="btn btn-sm">Cancel</button>
              </div>
            </form>
          </div>

          <%!-- Each section --%>
          <div
            :for={category <- @project.categories}
            class="border-l-4 border-base-300 pl-5 space-y-3 hover:border-primary transition-colors group"
          >
            <%!-- Section title: click to edit --%>
            <div class="flex items-start justify-between gap-3">
              <h2
                :if={@editing_category_id != category.id}
                phx-click="edit_category"
                phx-value-id={category.id}
                class="text-lg font-semibold cursor-text px-1 -mx-1 rounded hover:bg-base-200 transition-colors"
              >
                {category.name}
              </h2>

              <input
                :if={@editing_category_id == category.id}
                id={"cat-name-#{category.id}"}
                type="text"
                value={category.name}
                phx-blur="save_category_name"
                phx-value-id={category.id}
                phx-keydown="keydown_category_name"
                phx-value-id={category.id}
                phx-hook="AutoFocus"
                class="text-lg font-semibold w-full bg-transparent border-b-2 border-primary outline-none px-1 -mx-1"
              />

              <button
                :if={@editing_category_id != category.id}
                phx-click="delete_category"
                phx-value-id={category.id}
                data-confirm={"Delete section \"#{category.name}\"?"}
                class="btn btn-ghost btn-xs text-error opacity-0 group-hover:opacity-100 transition-opacity shrink-0"
              >
                <.icon name="ri-delete-bin-line" class="size-3.5" />
              </button>
            </div>

            <%!-- Section description: click to edit --%>
            <div
              :if={@editing_category_desc_id != category.id}
              phx-click="edit_category_desc"
              phx-value-id={category.id}
              class="cursor-text rounded-lg px-2 py-1 -mx-2 hover:bg-base-200 transition-colors min-h-6"
            >
              <div :if={category.description} class="markdown text-sm">
                {Phoenix.HTML.raw(Qlock.Markdown.to_html(category.description))}
              </div>
              <p :if={!category.description} class="text-base-content/40 italic text-xs">
                Click to add a description...
              </p>
            </div>

            <textarea
              :if={@editing_category_desc_id == category.id}
              id={"cat-desc-#{category.id}"}
              phx-blur="save_category_desc"
              phx-value-id={category.id}
              phx-keydown="keydown_category_desc"
              phx-value-id={category.id}
              phx-hook="AutoFocus"
              class="textarea textarea-bordered w-full font-mono text-sm"
              rows="4"
              placeholder="Describe this section in Markdown..."
            >{category.description}</textarea>
          </div>

          <p
            :if={@project.categories == [] && !@show_form}
            class="text-base-content/40 text-sm text-center py-6"
          >
            No sections yet — click "Add Section" to get started.
          </p>
        </div>

        <%!-- Members --%>
        <div class="space-y-4 border-t border-base-300 pt-8">
          <div class="flex items-center justify-between">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50">
              Members
            </p>
            <button
              :if={!@show_member_form}
              phx-click="show_member_form"
              class="btn btn-ghost btn-sm gap-1"
            >
              <.icon name="ri-user-add-line" class="size-4" /> Add Member
            </button>
          </div>

          <div :if={@show_member_form} class="card bg-base-200 p-4">
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

          <div class="space-y-1">
            <div
              :for={member <- @project.project_members}
              class="flex items-center justify-between px-2 py-2 rounded-lg hover:bg-base-200 group"
            >
              <div class="flex items-center gap-3">
                <div class="bg-primary text-primary-content rounded-full w-7 h-7 flex items-center justify-center text-xs font-bold shrink-0">
                  {String.first(to_string(member.user.email)) |> String.upcase()}
                </div>
                <span class="text-sm">{to_string(member.user.email)}</span>
              </div>
              <button
                phx-click="remove_member"
                phx-value-id={member.id}
                data-confirm="Remove this member?"
                class="btn btn-ghost btn-xs text-error opacity-0 group-hover:opacity-100 transition-opacity"
              >
                Remove
              </button>
            </div>

            <p
              :if={@project.project_members == []}
              class="text-base-content/40 text-sm text-center py-4"
            >
              No members yet.
            </p>
          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end
end
