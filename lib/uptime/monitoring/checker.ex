defmodule Uptime.Monitoring.Checker do
  @moduledoc """
  Faz uma requisição GET para a URL e devolve se o site respondeu e em quanto tempo.

  Os defaults do Req não servem para um botão manual: ele retenta 3x (com backoff)
  em 5xx/timeout/econnrefused, `receive_timeout` vale por chunk e não há timeout total.
  Aqui desligamos o retry (senão o tempo medido incluiria as tentativas) e impomos um
  teto total por fora com `Task.yield/2`.
  """

  @default_timeout 10_000

  @type result :: %{
          up: boolean(),
          status_code: integer() | nil,
          response_time_ms: non_neg_integer(),
          error: String.t() | nil
        }

  @spec run(String.t()) :: result()
  def run(url) do
    timeout = Application.get_env(:uptime, :checker_timeout, @default_timeout)
    started = System.monotonic_time(:millisecond)

    task = Task.async(fn -> request(url, timeout) end)

    outcome =
      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, outcome} -> outcome
        {:exit, reason} -> {:error, "falha inesperada: #{inspect(reason)}"}
        nil -> {:error, "sem resposta em #{format_timeout(timeout)}"}
      end

    elapsed = System.monotonic_time(:millisecond) - started
    build_result(outcome, elapsed)
  end

  defp format_timeout(ms) when rem(ms, 1000) == 0, do: "#{div(ms, 1000)}s"
  defp format_timeout(ms), do: "#{ms}ms"

  defp request(url, timeout) do
    opts =
      [
        retry: false,
        connect_options: [timeout: min(5_000, timeout)],
        receive_timeout: timeout,
        request_timeout: timeout,
        max_redirects: 5
      ] ++ Application.get_env(:uptime, :checker_req_options, [])

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: status}} -> {:ok, status}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  defp build_result({:ok, status}, elapsed) do
    %{
      up: status < 400,
      status_code: status,
      response_time_ms: elapsed,
      error: if(status >= 400, do: "HTTP #{status}")
    }
  end

  defp build_result({:error, message}, elapsed) do
    %{
      up: false,
      status_code: nil,
      response_time_ms: elapsed,
      error: String.slice(message, 0, 255)
    }
  end
end
