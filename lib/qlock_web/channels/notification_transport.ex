defmodule QlockWeb.NotificationTransport do
  @moduledoc """
  Raw WebSocket transport for real-time nudge notifications.

  sandqlock connects here via tauri-plugin-websocket:
    ws://localhost:4000/ws/notifications?token=<jwt>

  Protocol is plain JSON — no Phoenix Channel overhead.
  Server only pushes, never reads messages from the client.

  Message format pushed to client:
    {"type": "nudge", "message": "You've logged 12h this week..."}
  """

  @behaviour Phoenix.Socket.Transport

  # ── Transport callbacks ────────────────────────────────────────────────────

  def child_spec(_opts) do
    # Stateless transport — no background process needed
    %{
      id: __MODULE__,
      start: {Task, :start_link, [fn -> :ok end]},
      restart: :transient
    }
  end

  def connect(transport_info) do
    token = get_in(transport_info, [:params, "token"])

    with true <- is_binary(token) and token != "",
         {:ok, %{"sub" => subject}, _} <-
           AshAuthentication.Jwt.verify(token, Qlock.Accounts.User),
         {:ok, user} when not is_nil(user) <-
           Qlock.Accounts.User
           |> Ash.Query.for_read(:get_by_subject, %{subject: subject})
           |> Ash.read_one(domain: Qlock.Accounts, authorize?: false) do
      {:ok, %{user_id: to_string(user.id)}}
    else
      _ -> :error
    end
  end

  def init(state) do
    # Subscribe to this user's PubSub topic so we receive {:nudge, message}
    Phoenix.PubSub.subscribe(Qlock.PubSub, "notifications:#{state.user_id}")
    {:ok, state}
  end

  # Ignore any messages sent from the client
  def handle_in(_msg, state), do: {:ok, state}

  # Admin nudged this user — push JSON to the WebSocket client
  # payload is either a plain string (legacy) or %{message: str, mode: str}
  def handle_info({:nudge, %{message: message, mode: mode}}, state) do
    payload = Jason.encode!(%{type: "nudge", message: message, mode: mode})
    {:push, {:text, payload}, state}
  end

  def handle_info({:nudge, message}, state) when is_binary(message) do
    payload = Jason.encode!(%{type: "nudge", message: message, mode: "notify"})
    {:push, {:text, payload}, state}
  end

  def handle_info(_other, state), do: {:ok, state}

  def terminate(_reason, _state), do: :ok
end
