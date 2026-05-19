defmodule Mix.Tasks.Qlock.PromoteAdmin do
  use Mix.Task

  @shortdoc "Promote a user to admin role by email"

  @moduledoc """
  Promotes an existing user to the :admin role.

  ## Usage

      mix qlock.promote_admin user@example.com

  The user must already be registered. This command bypasses authorization
  and is intended to be run on the server by a system operator.
  """

  def run([email]) do
    Mix.Task.run("app.start")

    email
    |> String.trim()
    |> find_and_promote()
  end

  def run(_) do
    Mix.shell().error("Usage: mix qlock.promote_admin <email>")
    exit({:shutdown, 1})
  end

  defp find_and_promote(email) do
    case Ash.get(Qlock.Accounts.User, %{email: email},
           action: :get_by_email,
           domain: Qlock.Accounts,
           authorize?: false
         ) do
      {:ok, nil} ->
        Mix.shell().error("No user found with email: #{email}")
        exit({:shutdown, 1})

      {:ok, user} ->
        promote(user, email)

      {:error, error} ->
        Mix.shell().error("Error looking up user: #{inspect(error)}")
        exit({:shutdown, 1})
    end
  end

  defp promote(user, email) do
    case Ash.update(user, %{}, action: :promote_to_admin, domain: Qlock.Accounts, authorize?: false) do
      {:ok, _updated} ->
        Mix.shell().info("OK: #{email} is now an admin")

      {:error, error} ->
        Mix.shell().error("Failed to promote: #{inspect(error)}")
        exit({:shutdown, 1})
    end
  end
end
