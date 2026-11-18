defmodule UptimeWeb.SitesLiveTest do
  use UptimeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Uptime.MonitoringFixtures

  @stub Uptime.Monitoring.Checker

  setup :register_and_log_in_user

  test "cadastra um site e ele aparece na lista", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sites")

    assert has_element?(view, "#sites-empty")

    view
    |> form("#site-form", site: %{name: "Blog", url: "https://blog.test"})
    |> render_submit()

    site = Uptime.Monitoring.list_sites() |> hd()
    assert has_element?(view, "#sites-#{site.id}")
    assert has_element?(view, "#status-#{site.id}")
    assert has_element?(view, "#check-#{site.id}")
  end

  test "valida a URL no formulário e não grava", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sites")

    view
    |> form("#site-form", site: %{name: "Blog", url: "foo"})
    |> render_submit()

    assert has_element?(view, "#site_url.input-error")
    assert has_element?(view, "#sites-empty")
    assert Uptime.Monitoring.list_sites() == []
  end

  test "Verificar agora mostra no ar e o tempo de resposta", %{conn: conn} do
    test_pid = self()

    # Segura a resposta até o teste liberar, para observar o estado "verificando"
    Req.Test.stub(@stub, fn conn ->
      send(test_pid, {:in_flight, self()})

      receive do
        :go -> Plug.Conn.send_resp(conn, 200, "ok")
      end
    end)

    site = site_fixture()
    {:ok, view, _html} = live(conn, ~p"/sites")

    view |> element("#check-#{site.id}") |> render_click()
    assert_receive {:in_flight, request_pid}
    assert has_element?(view, "#check-#{site.id}[disabled]")

    send(request_pid, :go)
    render_async(view)

    refute has_element?(view, "#check-#{site.id}[disabled]")
    assert has_element?(view, "#status-#{site.id}.text-success")
    assert has_element?(view, "#details-#{site.id}")
  end

  test "Verificar agora num site fora do ar mostra o erro", %{conn: conn} do
    Req.Test.stub(@stub, &Req.Test.transport_error(&1, :econnrefused))
    site = site_fixture()
    {:ok, view, _html} = live(conn, ~p"/sites")

    view |> element("#check-#{site.id}") |> render_click()
    render_async(view)

    assert has_element?(view, "#status-#{site.id}.text-error")
  end
end
