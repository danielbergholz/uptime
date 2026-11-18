defmodule Uptime.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table(:sites) do
      add :name, :string, null: false
      add :url, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
