defmodule QlockWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [Qlock.Accounts, Qlock.Projects, Qlock.TimeTracking],
    open_api: "/open_api"
end
