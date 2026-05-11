defmodule Qlock.Projects do
  use Ash.Domain, otp_app: :qlock, extensions: [AshAdmin.Domain, AshJsonApi.Domain]

  admin do
    show? true
  end

  resources do
    resource Qlock.Projects.Project
    resource Qlock.Projects.Category
  end
end
