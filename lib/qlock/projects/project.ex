defmodule Qlock.Projects.Project do
  use Ash.Resource,
    otp_app: :qlock,
    domain: Qlock.Projects,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "projects"
    repo Qlock.Repo
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      accept [:name]
      change relate_actor(:user)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:update, :destroy]) do
      authorize_if relates_to_actor_via(:user)
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
