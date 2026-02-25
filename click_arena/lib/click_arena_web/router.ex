defmodule ClickArenaWeb.Router do
  use ClickArenaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ClickArenaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ClickArenaWeb do
    pipe_through :browser

    live "/", GameLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ClickArenaWeb do
  #   pipe_through :api
  # end
end
