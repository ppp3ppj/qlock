defmodule Qlock.Projects.Category do
  use Ash.Resource,
    otp_app: :qlock,
    domain: Qlock.Projects,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  sqlite do
    table "categories"
    repo Qlock.Repo
  end

  json_api do
    type "category"

    routes do
      base "/categories"

      index :read
      get :read
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :project_id]
    end

    update :update do
      accept [:name, :description]
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

    attribute :description, :string do
      allow_nil? true
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
