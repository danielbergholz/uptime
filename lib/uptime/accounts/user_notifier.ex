defmodule Uptime.Accounts.UserNotifier do
  import Swoosh.Email

  alias Uptime.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Uptime", Application.get_env(:uptime, :mail_from, "contact@example.com")})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    deliver(user.email, "Seu link de acesso ao Uptime", """

    ==============================

    Olá, #{user.email},

    Para entrar na área de admin, acesse o link abaixo (válido por 15 minutos):

    #{url}

    Se você não pediu este e-mail, pode ignorá-lo.

    ==============================
    """)
  end
end
