defmodule Uptime.Accounts do
  @moduledoc """
  The Accounts context.

  There is no sign up and no password: only emails listed in the `:admin_emails`
  config (set from the `ADMIN_EMAILS` environment variable) can receive a magic
  link, and the allowlist is checked again whenever a link or a session is used,
  so removing an email from the list revokes its access.
  """

  import Ecto.Query, warn: false
  alias Uptime.Repo

  alias Uptime.Accounts.{User, UserToken, UserNotifier}

  ## Allowlist

  @doc """
  Returns whether the email is in the admin allowlist (case-insensitive).
  """
  def admin_email?(email) when is_binary(email) do
    normalize_email(email) in admin_emails()
  end

  def admin_email?(_email), do: false

  defp admin_emails do
    :uptime
    |> Application.get_env(:admin_emails, [])
    |> Enum.map(&normalize_email/1)
  end

  defp normalize_email(email), do: email |> String.trim() |> String.downcase()

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  Users that are no longer in the admin allowlist are treated as not logged in.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    with {user, _token_inserted_at} = result <- Repo.one(query),
         true <- admin_email?(user.email) do
      result
    else
      _ -> nil
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Magic link

  @doc """
  Gets the user with the given magic link token, as long as it is still an admin.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query),
         true <- admin_email?(user.email) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link. The link can only be used once.
  """
  def login_user_by_magic_link(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, user_token} <- Repo.one(query),
         true <- admin_email?(user.email) do
      Repo.delete!(user_token)
      {:ok, user}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Delivers the magic link login instructions to the given email.

  Nothing is created or sent unless the email is in the admin allowlist; in that
  case the user is created on first use. Returns `{:error, :not_authorized}` for
  other emails, which callers must not disclose to the visitor.
  """
  def deliver_login_instructions(email, magic_link_url_fun)
      when is_binary(email) and is_function(magic_link_url_fun, 1) do
    if admin_email?(email) do
      with {:ok, user} <- get_or_create_user(normalize_email(email)) do
        {encoded_token, user_token} = UserToken.build_email_token(user)
        Repo.insert!(user_token)
        UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
      end
    else
      {:error, :not_authorized}
    end
  end

  defp get_or_create_user(email) do
    case Repo.get_by(User, email: email) do
      nil -> %User{} |> User.email_changeset(%{email: email}) |> Repo.insert()
      user -> {:ok, user}
    end
  end
end
