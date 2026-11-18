defmodule UptimeWeb.UserSessionControllerTest do
  use UptimeWeb.ConnCase, async: true

  import Uptime.AccountsFixtures
  alias Uptime.Accounts

  setup do
    %{user: user_fixture()}
  end

  defp magic_link_token(user) do
    extract_user_token(fn url -> Accounts.deliver_login_instructions(user.email, url) end)
  end

  describe "POST /users/log-in" do
    test "logs the user in with the magic link", %{conn: conn, user: user} do
      token = magic_link_token(user)

      conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => token}})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/sites"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Bem-vindo"

      # the logged in user can open the admin area
      conn = get(conn, ~p"/sites")
      assert html_response(conn, 200) =~ user.email
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      token = magic_link_token(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token, "remember_me" => "true"}
        })

      assert conn.resp_cookies["_uptime_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/sites"
    end

    test "goes back to the page that required login", %{conn: conn, user: user} do
      token = magic_link_token(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/sites")
        |> post(~p"/users/log-in", %{"user" => %{"token" => token}})

      assert redirected_to(conn) == "/sites"
    end

    test "redirects to the login page when the link is invalid", %{conn: conn} do
      conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => "invalid"}})

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "inválido ou expirou"
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end

    test "does not accept a link for a user that left the allowlist", %{conn: conn, user: user} do
      token = magic_link_token(user)
      disallow_admin_email(user.email)

      conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => token}})

      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end

    test "has no password login", %{conn: conn, user: user} do
      assert_error_sent 400, fn ->
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "hello world!"}
        })
      end
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "saiu"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end
  end
end
