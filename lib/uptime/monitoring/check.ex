defmodule Uptime.Monitoring.Check do
  use Ecto.Schema

  alias Uptime.Monitoring.Site

  schema "checks" do
    field :up, :boolean
    field :status_code, :integer
    field :response_time_ms, :integer
    field :error, :string

    belongs_to :site, Site

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
