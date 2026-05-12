defmodule Qlock.Projects.ProjectMember do
  use Ash.Resource,
    otp_app: :qlock,
    domain: Qlock.Projects,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "project_members"
    repo Qlock.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:project_id, :user_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :destroy]) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :project, Qlock.Projects.Project do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, Qlock.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end
  end
end
