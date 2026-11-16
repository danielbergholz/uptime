defmodule UptimeWeb.PageController do
  use UptimeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
