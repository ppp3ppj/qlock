defmodule QlockWeb.BulkTimeEntriesController do
  use QlockWeb, :controller

  # POST /api/json/time-entries/bulk
  # Body: { "entries": [{ "id": "client-uuid", "task_name": "...", ... }] }
  # Response: { "created": [{ "id": "...", "inserted_at": "...", "updated_at": "..." }], "errors": [] }
  #
  # Uses client-provided UUIDs so no ID reconciliation is needed on the client side.
  # Failed entries are returned in `errors`; the client retries them individually on the next sync.

  def create(conn, %{"entries" => entries}) when is_list(entries) do
    actor = conn.assigns[:current_user]

    %Ash.BulkResult{records: records, errors: errors} =
      Ash.bulk_create(
        entries,
        Qlock.TimeTracking.TimeEntry,
        :create,
        actor: actor,
        return_records?: true,
        return_errors?: true,
        stop_on_error?: false,
        authorize?: true
      )

    created =
      Enum.map(records, fn entry ->
        %{
          id: entry.id,
          inserted_at: format_dt(entry.inserted_at),
          updated_at: format_dt(entry.updated_at)
        }
      end)

    error_messages =
      Enum.map(errors, fn
        %{changeset: cs} -> %{message: inspect(cs.errors)}
        other -> %{message: inspect(other)}
      end)

    json(conn, %{created: created, errors: error_messages})
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "expected {\"entries\": [...]}"})
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: DateTime.to_iso8601(dt)
end
