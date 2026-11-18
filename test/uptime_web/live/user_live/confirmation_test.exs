defmodule UptimeWeb.UserLive.ConfirmationTest do
  use UptimeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Uptime.AccountsFixtures

  alias Uptime.Accounts

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user.email, url)
      end)

    %{user: user, token: token}
  end

  test "renders the login confirmation for a valid link", %{conn: conn, token: token} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in/#{token}")

    assert has_element?(view, "#login_form")
  end

  test "logs in with the link, once", %{conn: conn, token: token} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in/#{token}")

    form = form(view, "#login_form", %{"user" => %{"token" => token}})
    render_submit(form)

    conn = follow_trigger_action(form, conn)

    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Bem-vindo"
    assert get_session(conn, :user_token)
    assert redirected_to(conn) == ~p"/sites"

    # the link cannot be used again
    {:ok, _view, html} =
      live(build_conn(), ~p"/users/log-in/#{token}")
      |> follow_redirect(build_conn(), ~p"/users/log-in")

    assert html =~ "inválido ou expirou"
  end

  test "does not open for a user that left the allowlist", %{
    conn: conn,
    user: user,
    token: token
  } do
    disallow_admin_email(user.email)

    {:ok, _view, html} =
      live(conn, ~p"/users/log-in/#{token}")
      |> follow_redirect(conn, ~p"/users/log-in")

    assert html =~ "inválido ou expirou"
  end

  test "redirects to the login page for an invalid token", %{conn: conn} do
    {:ok, _view, html} =
      live(conn, ~p"/users/log-in/invalid-token")
      |> follow_redirect(conn, ~p"/users/log-in")

    assert html =~ "inválido ou expirou"
  end
end
