defmodule Qlock.Projects.Changes.CascadeDeleteCategories do
  @moduledoc """
  Destroys all categories belonging to a project before the project itself
  is deleted.

  We cannot rely on SQLite ON DELETE CASCADE because SQLite does not support
  altering an existing foreign key constraint — the cascade would need to have
  been declared at table-creation time. This Change handles it at the Ash
  level instead, which works regardless of database engine or schema state.

  Runs inside `before_action` so the category deletes and the project delete
  share the same transaction. If the category bulk-destroy fails, the project
  is NOT deleted and the transaction is rolled back automatically.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      changeset.data
      # Load without authorization — we are already inside an authorized
      # destroy action, so re-checking policies on each category is redundant.
      |> Ash.load!([categories: []], domain: Qlock.Projects, authorize?: false)
      |> Map.get(:categories)
      # bulk_destroy sends a single batch operation instead of N individual
      # queries, which is significantly more efficient for large category sets.
      |> Ash.bulk_destroy(:destroy, %{},
        domain: Qlock.Projects,
        actor: context.actor,
        authorize?: false
      )

      changeset
    end)
  end
end
