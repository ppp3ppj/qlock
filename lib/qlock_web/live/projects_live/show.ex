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
       show_member_picker: false,
       member_search: "",
       member_search_results: []
     )}
  end

  # --- Project name (click → input, blur → save, Escape → cancel) ---

  @impl true
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

  def handle_event("show_member_picker", _, socket) do
    results = non_members(socket.assigns.project, "")
    {:noreply, assign(socket, show_member_picker: true, member_search: "", member_search_results: results)}
  end

  def handle_event("hide_member_picker", _, socket),
    do: {:noreply, assign(socket, show_member_picker: false, member_search: "", member_search_results: [])}

  def handle_event("search_members", %{"value" => q}, socket) do
    results = non_members(socket.assigns.project, q)
    {:noreply, assign(socket, member_search: q, member_search_results: results)}
  end

  def handle_event("add_member_by_id", %{"id" => user_id}, socket) do
    project = socket.assigns.project

    ProjectMember
    |> Ash.Changeset.for_create(:create, %{project_id: project.id, user_id: user_id},
      actor: socket.assigns.current_user
    )
    |> Ash.create(domain: Projects)
    |> case do
      {:ok, _} ->
        project = load_project(project.id, socket.assigns.current_user)
        results = non_members(project, socket.assigns.member_search)
        {:noreply, assign(socket, project: project, member_search_results: results)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add member")}
    end
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    Ash.get!(ProjectMember, id, actor: socket.assigns.current_user, domain: Projects)
    |> Ash.destroy!(actor: socket.assigns.current_user, domain: Projects)

    project = load_project(socket.assigns.project.id, socket.assigns.current_user)
    {:noreply, assign(socket, project: project)}
  end

  defp non_members(project, search) do
    member_user_ids = MapSet.new(project.project_members, & &1.user_id)

    {:ok, all_users} = Ash.read(Qlock.Accounts.User, domain: Qlock.Accounts, authorize?: false)

    q = String.downcase(search)

    all_users
    |> Enum.reject(&MapSet.member?(member_user_ids, &1.id))
    |> Enum.filter(&String.contains?(String.downcase(to_string(&1.email)), q))
    |> Enum.take(8)
  end

  @avatar_colors ~w[#e74c3c #e67e22 #f39c12 #27ae60 #16a085
                    #2980b9 #8e44ad #c0392b #1abc9c #d35400
                    #3498db #2ecc71]

  defp avatar_color(email) do
    idx = :erlang.phash2(to_string(email), length(@avatar_colors))
    Enum.at(@avatar_colors, idx)
  end

  defp initials(email) do
    email |> to_string() |> String.split("@") |> List.first() |> String.first() |> String.upcase()
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
      <%!-- Drawer: section/TOC navigation for this project --%>
      <:drawer>
        <div class="p-4 space-y-1">
          <p class="text-xs font-semibold uppercase tracking-widest text-base-content/40 px-2 mb-3 truncate">
            {@project.name}
          </p>

          <a
            href="#project-top"
            class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-base-200 text-sm text-base-content/70 transition-colors"
          >
            <.icon name="ri-file-text-line" class="size-4 shrink-0 text-base-content/40" />
            Overview
          </a>

          <div class="pt-2">
            <p class="text-xs font-semibold uppercase tracking-widest text-base-content/30 px-2 mb-1">
              Sections
            </p>
            <p
              :if={@project.categories == []}
              class="px-2 py-1 text-xs text-base-content/30 italic"
            >
              No sections yet
            </p>
            <a
              :for={cat <- @project.categories}
              href={"#section-#{cat.id}"}
              class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-base-200 text-sm text-base-content/70 transition-colors"
            >
              <span class="w-1 h-1 rounded-full bg-base-content/30 shrink-0 ml-1"></span>
              <span class="truncate">{cat.name}</span>
            </a>
          </div>

          <div class="pt-2">
            <a
              href="#members"
              class="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-base-200 text-sm text-base-content/70 transition-colors"
            >
              <.icon name="ri-team-line" class="size-4 shrink-0 text-base-content/40" />
              Members
              <span class="ml-auto text-xs text-base-content/30">
                {length(@project.project_members)}
              </span>
            </a>
          </div>
        </div>
      </:drawer>

      <div id="project-top" class="max-w-3xl mx-auto px-6 md:px-10 py-6 space-y-10">

        <%!-- Project header --%>
        <div class="pb-6 border-b border-base-300 space-y-4">

          <%!-- Title: click to edit, blur to save --%>
          <div class="flex items-start justify-between gap-3">
            <h1
              :if={!@editing_project_name}
              phx-click="edit_project_name"
              class="flex-1 text-3xl font-semibold cursor-text px-1 -mx-1 rounded hover:bg-base-200 transition-colors"
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
              class="flex-1 text-3xl font-semibold bg-transparent border-b-2 border-primary outline-none px-1 -mx-1"
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
        <div id="sections" class="space-y-8">
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
            id={"section-#{category.id}"}
            class="border-l-4 border-base-300 pl-5 space-y-3 hover:border-primary transition-colors group"
          >
            <%!-- Section title: click to edit --%>
            <div class="flex items-start justify-between gap-3">
              <h2
                :if={@editing_category_id != category.id}
                phx-click="edit_category"
                phx-value-id={category.id}
                class="flex-1 text-lg font-semibold cursor-text px-1 -mx-1 rounded hover:bg-base-200 transition-colors"
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
                class="flex-1 text-lg font-semibold bg-transparent border-b-2 border-primary outline-none px-1 -mx-1"
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
        <div id="members" class="space-y-4 border-t border-base-300 pt-8">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <p class="text-xs font-semibold uppercase tracking-widest text-base-content/50">
                Members
              </p>
              <span class="flex items-center gap-1.5 text-xs bg-base-200 px-2 py-0.5 rounded-full">
                <span class="w-2 h-2 bg-success rounded-full inline-block"></span>
                {length(@project.project_members)}
              </span>
            </div>
            <button
              :if={!@show_member_picker}
              phx-click="show_member_picker"
              class="btn btn-ghost btn-sm gap-1"
            >
              <.icon name="ri-user-add-line" class="size-4" /> Add Member
            </button>
            <button
              :if={@show_member_picker}
              phx-click="hide_member_picker"
              class="btn btn-ghost btn-sm"
            >
              Done
            </button>
          </div>

          <%!-- Member list --%>
          <div class="space-y-1">
            <div
              :for={member <- @project.project_members}
              class="flex items-center justify-between px-2 py-2 rounded-lg hover:bg-base-200 group"
            >
              <div class="flex items-center gap-3">
                <div
                  class="rounded-full w-8 h-8 flex items-center justify-center text-xs font-bold shrink-0 text-white"
                  style={"background-color: #{avatar_color(member.user.email)}"}
                >
                  {initials(member.user.email)}
                </div>
                <span class="text-sm">{to_string(member.user.email)}</span>
                <span
                  :if={member.user_id == @current_user.id}
                  class="text-xs text-base-content/40"
                >
                  (you)
                </span>
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

          <%!-- User picker --%>
          <div :if={@show_member_picker} class="border border-base-300 rounded-xl overflow-hidden">
            <div class="p-3 border-b border-base-300">
              <input
                id="member-search"
                type="text"
                value={@member_search}
                phx-keyup="search_members"
                phx-debounce="200"
                placeholder="Search users..."
                class="input input-bordered input-sm w-full"
                phx-hook="AutoFocus"
              />
            </div>

            <div :if={@member_search_results == []} class="px-4 py-6 text-center text-sm text-base-content/40">
              {if @member_search == "", do: "All users are already members", else: "No users found"}
            </div>

            <div :if={@member_search_results != []}>
              <button
                :for={user <- @member_search_results}
                phx-click="add_member_by_id"
                phx-value-id={user.id}
                class="flex items-center gap-3 w-full px-4 py-2.5 hover:bg-base-200 transition-colors text-left"
              >
                <div
                  class="rounded-full w-8 h-8 flex items-center justify-center text-xs font-bold shrink-0 text-white"
                  style={"background-color: #{avatar_color(user.email)}"}
                >
                  {initials(user.email)}
                </div>
                <span class="text-sm">{to_string(user.email)}</span>
              </button>
            </div>
          </div>
        </div>

      </div>
    </Layouts.app>
    """
  end
end
