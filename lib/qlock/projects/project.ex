defmodule Qlock.Projects.Project do
  use Ash.Resource,
    otp_app: :qlock,
    domain: Qlock.Projects,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  sqlite do
    table "projects"
    repo Qlock.Repo
  end

  json_api do
    type "project"

    routes do
      base "/projects"

      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:id, :user_id)
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:update, :destroy]) do
      authorize_if actor_attribute_equals(:id, :user_id)
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
    belongs_to :user, Qlock.Accounts.User do
      public? true
    end

    has_many :categories, Qlock.Projects.Category do
      public? true
    end
  end
end
