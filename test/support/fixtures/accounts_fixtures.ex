defmodule Uptime.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Uptime.Accounts` context.
  """

  import Ecto.Query

  alias Uptime.Accounts
  alias Uptime.Accounts.{User, UserToken}

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Adds the email to the admin allowlist. Tests run concurrently, so the
  read-modify-write of the (global) application env is done under a lock.
  """
  def allow_admin_email(email) do
    update_admin_emails(fn emails -> [email | emails] end)
  end

  @doc """
  Removes the email from the admin allowlist.
  """
  def disallow_admin_email(email) do
    update_admin_emails(fn emails -> List.delete(emails, email) end)
  end

  defp update_admin_emails(fun) do
    :global.trans({{__MODULE__, :admin_emails}, self()}, fn ->
      emails = Application.get_env(:uptime, :admin_emails, [])
      Application.put_env(:uptime, :admin_emails, fun.(emails))
    end)

    :ok
  end

  @doc """
  Creates an admin user (its email is added to the allowlist).
  """
  def user_fixture(attrs \\ %{}) do
    email = Map.get(attrs, :email) || unique_user_email()
    allow_admin_email(email)

    %User{}
    |> User.email_changeset(%{email: email})
    |> Uptime.Repo.insert!()
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = UserToken.build_email_token(user)
    Uptime.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Uptime.Repo.update_all(
      from(ut in UserToken, where: ut.token == ^token),
      set: [inserted_at: dt]
    )
  end

  def login_token_count(%User{id: user_id}) do
    Uptime.Repo.aggregate(
      from(t in UserToken, where: t.user_id == ^user_id and t.context == "login"),
      :count
    )
  end

  def user_count, do: Uptime.Repo.aggregate(Accounts.User, :count)
end
