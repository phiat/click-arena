defmodule OutsiderGongWeb.PageController do
  use OutsiderGongWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
