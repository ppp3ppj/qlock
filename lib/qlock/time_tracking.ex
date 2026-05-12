defmodule Qlock.TimeTracking do
  use Ash.Domain, otp_app: :qlock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Qlock.TimeTracking.TimeEntry
  end
end
