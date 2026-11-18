defmodule UptimeWeb.UserSessionController do
  use UptimeWeb, :controller

  alias Uptime.Accounts
  alias UptimeWeb.UserAuth

  # magic link login
  def create(conn, %{"user" => %{"token" => token} = user_params}) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Bem-vindo de volta!")
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "O link é inválido ou expirou.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Você saiu da sua conta.")
    |> UserAuth.log_out_user()
  end
end
