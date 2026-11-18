defmodule Uptime.Monitoring.Site do
  use Ecto.Schema
  import Ecto.Changeset

  alias Uptime.Monitoring.Check

  schema "sites" do
    field :name, :string
    field :url, :string

    has_many :checks, Check

    # Preenchido por Monitoring.list_sites/0 e check_site/1; não é coluna.
    field :last_check, :any, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(site, attrs) do
    site
    |> cast(attrs, [:name, :url])
    |> update_change(:name, &String.trim/1)
    |> update_change(:url, &String.trim/1)
    |> validate_required([:name, :url])
    |> validate_length(:name, max: 100)
    |> validate_length(:url, max: 2048)
    |> validate_change(:url, &validate_http_url/2)
  end

  defp validate_http_url(:url, url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and host not in [nil, ""] ->
        []

      _ ->
        [url: "deve começar com http:// ou https:// e ter um domínio"]
    end
  end
end
