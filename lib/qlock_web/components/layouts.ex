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

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen">
      <%!-- Icon sidebar --%>
      <aside class="hidden lg:flex flex-col items-center w-14 bg-base-200 border-r border-base-300 py-3 gap-1 shrink-0">
        <%!-- Logo --%>
        <a href={~p"/"} class="mb-3">
          <img src={~p"/images/logo.svg"} width="28" />
        </a>

        <div class="divider my-0" />

        <%!-- Nav icons --%>
        <ul class="flex flex-col items-center gap-1 flex-1 mt-1">
          <li class="tooltip tooltip-right" data-tip="Home">
            <a
              href={~p"/"}
              class={[
                "btn btn-ghost btn-square btn-sm",
                @current_page == :home && "bg-base-300 text-primary"
              ]}
            >
              <.icon name="hero-home" class="size-5" />
            </a>
          </li>
          <li class="tooltip tooltip-right" data-tip="Projects">
            <a
              href={~p"/projects"}
              class={[
                "btn btn-ghost btn-square btn-sm",
                @current_page == :projects && "bg-base-300 text-primary"
              ]}
            >
              <.icon name="hero-folder" class="size-5" />
            </a>
          </li>
        </ul>

        <%!-- User menu --%>
        <div class="flex flex-col items-center gap-1 mt-auto mb-2" :if={@current_user}>
          <.user_menu user={@current_user} />
          <div class="divider my-0" />
        </div>

        <%!-- Theme toggle at bottom --%>
        <div class="flex flex-col items-center gap-1">
          <button
            class="btn btn-ghost btn-square btn-sm tooltip tooltip-right"
            data-tip="System"
            phx-click={JS.dispatch("phx:set-theme")}
            data-phx-theme="system"
          >
            <.icon name="hero-computer-desktop-micro" class="size-4" />
          </button>
          <button
            class="btn btn-ghost btn-square btn-sm tooltip tooltip-right"
            data-tip="Light"
            phx-click={JS.dispatch("phx:set-theme")}
            data-phx-theme="light"
          >
            <.icon name="hero-sun-micro" class="size-4" />
          </button>
          <button
            class="btn btn-ghost btn-square btn-sm tooltip tooltip-right"
            data-tip="Dark"
            phx-click={JS.dispatch("phx:set-theme")}
            data-phx-theme="dark"
          >
            <.icon name="hero-moon-micro" class="size-4" />
          </button>
        </div>
      </aside>

      <%!-- Mobile topbar --%>
      <div class="flex flex-col flex-1 min-w-0">
        <div class="navbar bg-base-100 border-b border-base-300 lg:hidden sticky top-0 z-30">
          <div class="flex gap-2">
            <a href={~p"/"} class="btn btn-ghost btn-square btn-sm">
              <.icon name="hero-home" class="size-5" />
            </a>
            <a href={~p"/projects"} class="btn btn-ghost btn-square btn-sm">
              <.icon name="hero-folder" class="size-5" />
            </a>
          </div>
          <span class="font-bold ml-2">Qlock</span>
        </div>

        <main class="flex-1 p-6 max-w-5xl w-full">
          {render_slot(@inner_block)}
        </main>
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
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
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
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
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
    <div class="dropdown dropdown-right">
      <div tabindex="0" role="button" class="cursor-pointer hover:opacity-80 transition-opacity">
        <div class="bg-primary text-primary-content rounded-full w-8 h-8 flex items-center justify-center">
          <span class="text-xs font-bold leading-none select-none">
            {String.first(to_string(@user.email)) |> String.upcase()}
          </span>
        </div>
      </div>

      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box z-50 w-52 p-2 shadow-lg border border-base-300 ml-2"
      >
        <li class="px-3 py-2 text-xs text-base-content/60 font-medium truncate">
          {to_string(@user.email)}
        </li>
        <div class="divider my-0" />
        <li>
          <.link method="delete" href={~p"/sign-out"} class="gap-2 text-error hover:bg-error/10">
            <.icon name="hero-arrow-right-on-rectangle" class="size-4" />
            Sign out
          </.link>
        </li>
      </ul>
    </div>
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
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
