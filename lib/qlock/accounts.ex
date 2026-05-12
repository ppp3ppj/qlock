defmodule Qlock.Accounts do
  use Ash.Domain, otp_app: :qlock, extensions: [AshAdmin.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  resources do
    resource Qlock.Accounts.Token
    resource Qlock.Accounts.User
  end
end
