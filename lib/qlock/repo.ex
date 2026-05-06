defmodule Qlock.Repo do
  use AshSqlite.Repo,
    otp_app: :qlock
end
