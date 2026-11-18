defmodule UptimeWeb.SitesLive do
  use UptimeWeb, :live_view

  alias Uptime.Monitoring
  alias Uptime.Monitoring.Site

  @impl true
  def mount(_params, _session, socket) do
    sites = Monitoring.list_sites()

    {:ok,
     socket
     |> assign(:page_title, "Sites")
     |> assign(:checking_ids, MapSet.new())
     |> assign_form(Monitoring.change_site(%Site{}))
     |> stream(:sites, sites)}
  end

  @impl true
  def handle_event("validate", %{"site" => params}, socket) do
    changeset =
      %Site{}
      |> Monitoring.change_site(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"site" => params}, socket) do
    case Monitoring.create_site(params) do
      {:ok, site} ->
        {:noreply,
         socket
         |> stream_insert(:sites, site, at: 0)
         |> assign_form(Monitoring.change_site(%Site{}))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("check", %{"id" => id}, socket) do
    site = Monitoring.get_site!(id)

    if MapSet.member?(socket.assigns.checking_ids, site.id) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> update(:checking_ids, &MapSet.put(&1, site.id))
       |> stream_insert(:sites, site)
       |> start_async({:check, site.id}, fn -> Monitoring.check_site(site) end)}
    end
  end

  @impl true
  def handle_async({:check, id}, {:ok, {:ok, site}}, socket) do
    {:noreply,
     socket
     |> update(:checking_ids, &MapSet.delete(&1, id))
     |> stream_insert(:sites, site)}
  end

  def handle_async({:check, id}, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> update(:checking_ids, &MapSet.delete(&1, id))
     |> stream_insert(:sites, Monitoring.get_site!(id))
     |> put_flash(:error, "Não foi possível concluir a verificação.")}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m %H:%M:%S UTC")
end
