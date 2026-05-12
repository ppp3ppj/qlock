defmodule QlockWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [Qlock.Accounts],
    open_api: "/open_api"
end
