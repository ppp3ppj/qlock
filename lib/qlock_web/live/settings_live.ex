defmodule QlockWeb.SettingsLive do
  use QlockWeb, :live_view

  on_mount {QlockWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_page={:settings} current_user={@current_user}>
      <div class="max-w-2xl mx-auto px-6 md:px-10 py-6">
      <.header>Settings</.header>

      <div class="mt-6 max-w-md space-y-4">
        <div class="card bg-base-200 p-5 space-y-4">
          <h2 class="font-semibold text-sm text-base-content/70 uppercase tracking-wide">
            Appearance
          </h2>

          <div class="flex items-center justify-between gap-4">
            <div>
              <p class="text-sm font-medium">Theme</p>
              <p class="text-xs text-base-content/50">Choose your preferred color theme</p>
            </div>

            <select
              id="theme-select"
              class="select select-bordered select-sm w-32"
              onchange="this.dataset.phxTheme = this.value; this.dispatchEvent(new CustomEvent('phx:set-theme', {bubbles: true}))"
            >
              <option value="system">System</option>
              <option value="light">Light</option>
              <option value="dark">Dark</option>
            </select>
          </div>
        </div>
      </div>

      <script>
        (function() {
          var sel = document.getElementById('theme-select');
          if (sel) sel.value = localStorage.getItem('phx:theme') || 'system';
        })();
      </script>
      </div>
    </Layouts.app>
    """
  end
end
