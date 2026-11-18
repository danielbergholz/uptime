defmodule Uptime.AccountsTest do
  use Uptime.DataCase, async: true

  alias Uptime.Accounts
  alias Uptime.Accounts.{User, UserToken}

  import Uptime.AccountsFixtures

  describe "admin_email?/1" do
    test "is true only for emails in the allowlist, ignoring case and spaces" do
      email = unique_user_email()
      allow_admin_email(email)

      assert Accounts.admin_email?(email)
      assert Accounts.admin_email?("  " <> String.upcase(email) <> " ")
      refute Accounts.admin_email?(unique_user_email())
      refute Accounts.admin_email?(nil)
    end
  end

  describe "deliver_login_instructions/2" do
    test "creates the user and sends a magic link for an allowlisted email" do
      email = unique_user_email()
      allow_admin_email(email)

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(email, url)
        end)

      user = Repo.get_by!(User, email: email)
      {:ok, decoded} = Base.url_decode64(token, padding: false)
      user_token = Repo.get_by!(UserToken, token: :crypto.hash(:sha256, decoded))

      assert user_token.context == "login"
      assert user_token.sent_to == email
      assert user_token.user_id == user.id
    end

    test "reuses the existing user on later requests" do
      user = user_fixture()

      assert {:ok, _} = Accounts.deliver_login_instructions(user.email, &"/#{&1}")
      assert {:ok, _} = Accounts.deliver_login_instructions(user.email, &"/#{&1}")

      assert user_count() == 1
      assert login_token_count(user) == 2
    end

    test "sends nothing and creates nothing for an email outside the allowlist" do
      email = unique_user_email()

      assert {:error, :not_authorized} =
               Accounts.deliver_login_instructions(email, &"/#{&1}")

      assert user_count() == 0
      refute Repo.get_by(User, email: email)
      refute_received {:email, _}
    end
  end

  describe "login_user_by_magic_link/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user.email, url)
        end)

      %{user: user, token: token}
    end

    test "logs the user in and the link works only once", %{user: user, token: token} do
      assert {:ok, logged_in} = Accounts.login_user_by_magic_link(token)
      assert logged_in.id == user.id

      assert {:error, :not_found} = Accounts.login_user_by_magic_link(token)
    end

    test "rejects invalid tokens" do
      assert {:error, :not_found} = Accounts.login_user_by_magic_link("not a token!")
      assert {:error, :not_found} = Accounts.login_user_by_magic_link("bm9wZQ")
    end

    test "rejects expired tokens", %{user: user, token: token} do
      {:ok, decoded} = Base.url_decode64(token, padding: false)
      offset_user_token(:crypto.hash(:sha256, decoded), -16, :minute)

      assert {:error, :not_found} = Accounts.login_user_by_magic_link(token)
      assert login_token_count(user) == 1
    end

    test "rejects users that left the allowlist", %{user: user, token: token} do
      disallow_admin_email(user.email)

      assert {:error, :not_found} = Accounts.login_user_by_magic_link(token)
      refute Accounts.get_user_by_magic_link_token(token)
    end
  end

  describe "get_user_by_magic_link_token/1" do
    test "returns the user for a valid token without consuming it" do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user.email, url)
        end)

      assert Accounts.get_user_by_magic_link_token(token).id == user.id
      assert Accounts.get_user_by_magic_link_token(token).id == user.id
      refute Accounts.get_user_by_magic_link_token("invalid")
    end
  end

  describe "session tokens" do
    setup do
      %{user: user_fixture()}
    end

    test "generate_user_session_token/1 stores a session token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert Repo.get_by!(UserToken, token: token).context == "session"
    end

    test "get_user_by_session_token/1 returns the user for a valid token", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert {session_user, inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert %DateTime{} = inserted_at
    end

    test "get_user_by_session_token/1 rejects invalid and expired tokens", %{user: user} do
      refute Accounts.get_user_by_session_token("oops")

      token = Accounts.generate_user_session_token(user)
      offset_user_token(token, -15, :day)
      refute Accounts.get_user_by_session_token(token)
    end

    test "get_user_by_session_token/1 revokes users that left the allowlist", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert Accounts.get_user_by_session_token(token)

      disallow_admin_email(user.email)
      refute Accounts.get_user_by_session_token(token)
    end

    test "delete_user_session_token/1 deletes the token", %{user: user} do
      token = Accounts.generate_user_session_token(user)

      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end
end
