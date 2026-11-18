defmodule Uptime.Monitoring do
  @moduledoc """
  Sites monitorados e o histórico de checagens de cada um.
  """

  import Ecto.Query

  alias Uptime.Repo
  alias Uptime.Monitoring.{Check, Checker, Site}

  @doc "Lista os sites (mais recentes primeiro), cada um com `last_check` preenchido."
  def list_sites do
    last_checks =
      from c in Check,
        distinct: c.site_id,
        order_by: [asc: c.site_id, desc: c.inserted_at, desc: c.id]

    sites = Repo.all(from s in Site, order_by: [desc: s.id])

    by_site =
      last_checks
      |> Repo.all()
      |> Map.new(&{&1.site_id, &1})

    Enum.map(sites, &%{&1 | last_check: Map.get(by_site, &1.id)})
  end

  @doc "Busca um site com `last_check` preenchido."
  def get_site!(id) do
    site = Repo.get!(Site, id)

    last_check =
      Repo.one(
        from c in Check,
          where: c.site_id == ^site.id,
          order_by: [desc: c.inserted_at, desc: c.id],
          limit: 1
      )

    %{site | last_check: last_check}
  end

  def change_site(%Site{} = site, attrs \\ %{}), do: Site.changeset(site, attrs)

  def create_site(attrs) do
    %Site{}
    |> Site.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Acessa a URL do site e grava o resultado como uma nova `Check`.

  Devolve o site com `last_check` atualizado.
  """
  def check_site(%Site{} = site) do
    result = Checker.run(site.url)

    {:ok, check} =
      %Check{site_id: site.id}
      |> Ecto.Changeset.change(result)
      |> Repo.insert()

    {:ok, %{site | last_check: check}}
  end
end
