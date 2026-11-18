defmodule Uptime.MonitoringFixtures do
  alias Uptime.Monitoring

  def site_fixture(attrs \\ %{}) do
    {:ok, site} =
      attrs
      |> Enum.into(%{name: "Meu site", url: "https://example.com"})
      |> Monitoring.create_site()

    site
  end
end
