defmodule Uptime.Repo.Migrations.CreateChecks do
  use Ecto.Migration

  def change do
    create table(:checks) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :up, :boolean, null: false
      add :status_code, :integer
      add :response_time_ms, :integer
      add :error, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:checks, [:site_id, :inserted_at])
  end
end
