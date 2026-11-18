defmodule UptimeWeb.UserLive.LoginTest do
  use UptimeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Uptime.AccountsFixtures

  alias Uptime.Accounts.User

  test "renders the login page with only the magic link form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    assert has_element?(view, "#login_form_magic")
    refute has_element?(view, "#login_form_password")
    refute has_element?(view, "input[type=password]")
    refute has_element?(view, "a[href='/users/register']")
  end

  test "sends the magic link to an allowlisted email", %{conn: conn} do
    email = unique_user_email()
    allow_admin_email(email)

    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    {:ok, conn_view, _html} =
      view
      |> form("#login_form_magic", user: %{email: email})
      |> render_submit()
      |> follow_redirect(conn, ~p"/users/log-in")

    assert has_element?(conn_view, "#flash-info")

    user = Uptime.Repo.get_by!(User, email: email)
    assert login_token_count(user) == 1
    assert_received {:email, %{to: [{_, ^email}]}}
  end

  test "shows the same answer for an email that is not allowed and sends nothing", %{conn: conn} do
    email = unique_user_email()

    {:ok, view, _html} = live(conn, ~p"/users/log-in")

    {:ok, conn_view, _html} =
      view
      |> form("#login_form_magic", user: %{email: email})
      |> render_submit()
      |> follow_redirect(conn, ~p"/users/log-in")

    assert has_element?(conn_view, "#flash-info")
    refute has_element?(conn_view, "#flash-error")

    refute Uptime.Repo.get_by(User, email: email)
    refute_received {:email, _}
  end
end
