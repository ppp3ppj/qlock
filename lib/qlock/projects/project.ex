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
      # Automatically sets user_id from the authenticated actor,
      # so callers never need to pass it manually.
      change relate_actor(:user)
    end

    # Deletes all related categories first, then removes the project.
    # See Qlock.Projects.Changes.CascadeDeleteCategories for full rationale.
    destroy :destroy_with_categories do
      require_atomic? false
      change Qlock.Projects.Changes.CascadeDeleteCategories
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
