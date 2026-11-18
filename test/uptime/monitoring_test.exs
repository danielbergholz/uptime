defmodule Uptime.MonitoringTest do
  use Uptime.DataCase, async: true

  import Uptime.MonitoringFixtures

  alias Uptime.Monitoring
  alias Uptime.Monitoring.{Check, Site}

  @stub Uptime.Monitoring.Checker

  describe "create_site/1" do
    test "cria com nome e URL válidos" do
      assert {:ok, %Site{name: "Blog", url: "https://blog.test"}} =
               Monitoring.create_site(%{name: " Blog ", url: "https://blog.test"})
    end

    test "exige nome e URL" do
      assert {:error, changeset} = Monitoring.create_site(%{})
      assert %{name: ["can't be blank"], url: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejeita URLs que não são http(s) com domínio" do
      for url <- ["foo", "ftp://x.com", "https://", "javascript:alert(1)"] do
        assert {:error, changeset} = Monitoring.create_site(%{name: "x", url: url})
        assert %{url: [_]} = errors_on(changeset)
      end
    end
  end

  describe "check_site/1" do
    test "site que responde 200 fica no ar, com status e tempo guardados" do
      Req.Test.stub(@stub, &Plug.Conn.send_resp(&1, 200, "ok"))
      site = site_fixture()

      assert {:ok, %Site{last_check: check}} = Monitoring.check_site(site)
      assert %Check{up: true, status_code: 200, error: nil} = check
      assert is_integer(check.response_time_ms) and check.response_time_ms >= 0
      assert Repo.aggregate(Check, :count) == 1
    end

    test "status >= 400 fica fora do ar e NÃO faz retry" do
      test_pid = self()

      Req.Test.stub(@stub, fn conn ->
        send(test_pid, :requested)
        Plug.Conn.send_resp(conn, 503, "down")
      end)

      {:ok, %Site{last_check: check}} = Monitoring.check_site(site_fixture())

      assert %Check{up: false, status_code: 503, error: "HTTP 503"} = check
      assert_received :requested
      refute_received :requested
    end

    test "erro de rede fica fora do ar com a mensagem do erro" do
      Req.Test.stub(@stub, &Req.Test.transport_error(&1, :econnrefused))

      {:ok, %Site{last_check: check}} = Monitoring.check_site(site_fixture())

      assert %Check{up: false, status_code: nil, error: error} = check
      assert error =~ "connection refused"
    end

    test "site que não responde dentro do teto fica fora do ar" do
      Req.Test.stub(@stub, fn conn ->
        Process.sleep(2_000)
        Plug.Conn.send_resp(conn, 200, "tarde demais")
      end)

      {:ok, %Site{last_check: check}} = Monitoring.check_site(site_fixture())

      assert %Check{up: false, status_code: nil, error: "sem resposta em 200ms"} = check
      assert check.response_time_ms < 1_000
    end
  end

  describe "list_sites/0" do
    test "traz a última checagem de cada site" do
      site = site_fixture()
      other = site_fixture(%{name: "Outro"})

      Req.Test.stub(@stub, &Plug.Conn.send_resp(&1, 500, ""))
      {:ok, _} = Monitoring.check_site(site)
      Req.Test.stub(@stub, &Plug.Conn.send_resp(&1, 200, ""))
      {:ok, _} = Monitoring.check_site(site)

      sites = Map.new(Monitoring.list_sites(), &{&1.id, &1})
      assert %Check{up: true} = sites[site.id].last_check
      assert sites[other.id].last_check == nil
    end
  end
end
