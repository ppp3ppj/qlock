defmodule QlockWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use QlockWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_page, :atom, default: nil
  attr :current_user, :any, default: nil
  attr :current_scope, :map, default: nil

  slot :inner_block, required: true
  slot :drawer

  def app(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden">
      <%!-- Narrow icon sidebar --%>
      <aside class="hidden lg:flex flex-col items-center w-14 bg-base-200 border-r border-base-300 py-3 shrink-0">
        <%!-- Logo --%>
        <a href={~p"/"} class="mb-3 flex items-center justify-center">
          <img src={~p"/images/logo.svg"} width="28" />
        </a>

        <div class="divider my-0 w-8" />

        <%!-- Nav icons --%>
        <ul class="flex flex-col items-center gap-0.5 flex-1 mt-2 w-full px-1.5">
          <li class="tooltip tooltip-right w-full" data-tip="Home">
            <.link
              navigate={~p"/"}
              class={[
                "btn btn-ghost btn-square btn-sm w-full",
                @current_page == :home && "bg-base-300 text-primary"
              ]}
            >
              <.icon name="ri-home-line" class="size-5" />
            </.link>
          </li>
          <li class="tooltip tooltip-right w-full" data-tip="Projects">
            <.link
              navigate={~p"/projects"}
              class={[
                "btn btn-ghost btn-square btn-sm w-full",
                @current_page == :projects && "bg-base-300 text-primary"
              ]}
            >
              <.icon name="ri-folder-line" class="size-5" />
            </.link>
          </li>
          <li class="tooltip tooltip-right w-full" data-tip="Time Entries (read-only)">
            <.link
              navigate={~p"/time"}
              class={[
                "btn btn-ghost btn-square btn-sm w-full",
                @current_page == :time && "bg-base-300 text-primary"
              ]}
            >
              <.icon name="ri-time-line" class="size-5" />
            </.link>
          </li>

          <%!-- Settings pushed to bottom of nav --%>
          <li class="tooltip tooltip-right w-full mt-auto" data-tip="Settings">
            <.link
              navigate={~p"/settings"}
              class={[
                "btn btn-ghost btn-square btn-sm w-full",
                @current_page == :settings && "bg-base-300 text-primary"
              ]}
            >
              <.icon name="ri-settings-3-line" class="size-5" />
            </.link>
          </li>
        </ul>

        <%!-- User avatar --%>
        <div class="flex flex-col items-center mt-2 w-full px-1.5" :if={@current_user}>
          <div class="divider my-0 w-8" />
          <div class="mt-2">
            <.user_menu user={@current_user} />
          </div>
        </div>
      </aside>

      <%!-- Content column --%>
      <div class="flex flex-col flex-1 min-w-0 overflow-hidden">
        <%!-- Mobile topbar --%>
        <div class="navbar bg-base-100 border-b border-base-300 lg:hidden sticky top-0 z-30 min-h-12 px-4">
          <div class="flex gap-1">
            <.link navigate={~p"/"} class="btn btn-ghost btn-square btn-sm">
              <.icon name="ri-home-line" class="size-5" />
            </.link>
            <.link navigate={~p"/projects"} class="btn btn-ghost btn-square btn-sm">
              <.icon name="ri-folder-line" class="size-5" />
            </.link>
            <.link navigate={~p"/time"} class="btn btn-ghost btn-square btn-sm">
              <.icon name="ri-time-line" class="size-5" />
            </.link>
          </div>
          <span class="font-semibold ml-2 text-sm">Qlock</span>
        </div>

        <%!-- Drawer + main content --%>
        <div class="flex flex-1 overflow-hidden">
          <%!-- Secondary drawer (optional, page-specific) --%>
          <div
            :if={@drawer != []}
            class="hidden lg:flex flex-col w-52 xl:w-60 border-r border-base-300 bg-base-100 overflow-y-auto shrink-0"
          >
            {render_slot(@drawer)}
          </div>

          <%!-- Scrollable main content — pages center themselves --%>
          <main class="flex-1 overflow-y-auto scroll-smooth">
            {render_slot(@inner_block)}
          </main>
        </div>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="ri-loader-4-line" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="ri-loader-4-line" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  attr :user, :any, required: true

  def user_menu(assigns) do
    ~H"""
    <div
      role="button"
      onclick="document.getElementById('user-modal').showModal()"
      class="cursor-pointer hover:opacity-80 transition-opacity"
    >
      <div class="bg-primary text-primary-content rounded-full w-8 h-8 flex items-center justify-center">
        <span class="text-xs font-bold leading-none select-none">
          {String.first(to_string(@user.email)) |> String.upcase()}
        </span>
      </div>
    </div>

    <dialog id="user-modal" class="modal modal-middle">
      <div class="modal-box max-w-xs p-6 flex flex-col items-center gap-4">
        <div class="bg-primary text-primary-content rounded-full w-16 h-16 flex items-center justify-center">
          <span class="text-2xl font-bold leading-none select-none">
            {String.first(to_string(@user.email)) |> String.upcase()}
          </span>
        </div>

        <p class="text-sm text-base-content/70 font-medium truncate w-full text-center">
          {to_string(@user.email)}
        </p>

        <div class="divider my-0 w-full" />

        <div class="flex flex-col gap-2 w-full">
          <.link
            method="delete"
            href={~p"/sign-out"}
            class="btn btn-error btn-outline w-full gap-2"
          >
            <.icon name="ri-logout-box-r-line" class="size-4" />
            Sign out
          </.link>

          <form method="dialog" class="w-full">
            <button class="btn w-full">Cancel</button>
          </form>
        </div>
      </div>

      <form method="dialog" class="modal-backdrop">
        <button>close</button>
      </form>
    </dialog>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="ri-computer-line" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="ri-sun-line" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="ri-moon-line" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
