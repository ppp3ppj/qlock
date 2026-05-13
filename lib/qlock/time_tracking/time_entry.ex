defmodule Qlock.TimeTracking.TimeEntry do
  use Ash.Resource,
    otp_app: :qlock,
    domain: Qlock.TimeTracking,
    data_layer: AshSqlite.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "time_entries"
    repo Qlock.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:task_name, :duration_minutes, :date, :overtime, :project_id, :category_id]
      change relate_actor(:user)
    end

    update :update do
      accept [:task_name, :duration_minutes, :date, :overtime, :project_id, :category_id]
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

    attribute :task_name, :string do
      allow_nil? false
      public? true
    end

    attribute :duration_minutes, :integer do
      allow_nil? false
      public? true
    end

    attribute :date, :date do
      allow_nil? false
      public? true
    end

    attribute :overtime, :boolean do
      default false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Qlock.Accounts.User

    belongs_to :project, Qlock.Projects.Project do
      allow_nil? true
      attribute_writable? true
      public? true
    end

    belongs_to :category, Qlock.Projects.Category do
      allow_nil? true
      attribute_writable? true
      public? true
    end
  end
end
