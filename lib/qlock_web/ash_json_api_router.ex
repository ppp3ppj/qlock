defmodule QlockWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [Qlock.Accounts, Qlock.Projects],
    open_api: "/open_api"
end
