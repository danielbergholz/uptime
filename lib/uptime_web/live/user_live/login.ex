defmodule UptimeWeb.UserLive.Login do
  use UptimeWeb, :live_view

  alias Uptime.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Entrar</p>
            <:subtitle>
              Área restrita. Enviaremos um link de acesso para o seu e-mail.
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>Você está usando o adapter de e-mail local.</p>
            <p>
              Para ver os e-mails enviados, acesse a <.link href="/dev/mailbox" class="underline">caixa de e-mails</.link>.
            </p>
          </div>
        </div>

        <.form for={@form} id="login_form_magic" phx-submit="submit_magic">
          <.input
            field={@form[:email]}
            type="email"
            label="E-mail"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            Receber link de acesso <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"email" => nil}, as: "user"))}
  end

  @impl true
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    # The answer is the same for any email, so nobody can find out who is an admin.
    _ = Accounts.deliver_login_instructions(email, &url(~p"/users/log-in/#{&1}"))

    info = "Se o e-mail estiver autorizado, você receberá o link de acesso em instantes."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:uptime, Uptime.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
