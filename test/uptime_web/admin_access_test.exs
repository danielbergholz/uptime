defmodule UptimeWeb.AdminAccessTest do
  use UptimeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Uptime.AccountsFixtures

  test "a página inicial continua aberta para qualquer um", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html_response(conn, 200) =~ ~s(id="app-name")
    assert html_response(conn, 200) =~ ~s(id="log-in-link")
  end

  test "/sites exige login e manda para a tela de entrada", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/sites")

    conn = get(conn, ~p"/sites")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "não existem cadastro, senha nem configurações da conta", %{conn: conn} do
    assert get(conn, "/users/register").status == 404
    assert get(conn, "/users/settings").status == 404
    assert post(conn, "/users/update-password", %{}).status == 404
  end

  test "admin logado acessa /sites", %{conn: conn} do
    conn = conn |> log_in_user(user_fixture()) |> get(~p"/sites")
    assert html_response(conn, 200) =~ ~s(id="log-out-link")

    {:ok, view, _html} = live(conn)
    assert has_element?(view, "#site-form")
  end

  test "quem saiu da lista ADMIN_EMAILS perde o acesso", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    assert {:ok, _view, _html} = live(conn, ~p"/sites")

    disallow_admin_email(user.email)

    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/sites")
  end
end
