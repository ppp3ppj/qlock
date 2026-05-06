defmodule Qlock.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Qlock.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:qlock, :token_signing_secret)
  end
end
