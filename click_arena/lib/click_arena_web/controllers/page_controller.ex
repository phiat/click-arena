defmodule ClickArenaWeb.PageController do
  use ClickArenaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
