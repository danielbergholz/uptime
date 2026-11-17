defmodule UptimeWeb.PageControllerTest do
  use UptimeWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ ~s(id="app-name")
  end
end
