defmodule Qlock.Projects.Category do
  use Ash.Resource,
    otp_app: :qlock,
    domain: Qlock.Projects,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "categories"
    repo Qlock.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :project_id]
    end

    update :update do
      accept [:name]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :project, Qlock.Projects.Project do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end
end
