defmodule OutsiderGong.SpacetimeDB.Client do
  @moduledoc """
  Generated SpacetimeDB client.

  Customize the callbacks below to handle events from your SpacetimeDB module.
  """

  use Spacetimedbex.Client

  def config do
    %{
      host: System.get_env("SPACETIMEDB_HOST", "localhost:3000"),
      database: System.get_env("SPACETIMEDB_DATABASE", "clickarena"),
      subscriptions: ["SELECT * FROM player"]
    }
  end

  # --- Callbacks (uncomment and customize as needed) ---

  # def on_connect(identity, connection_id, token, state) do
  #   {:ok, state}
  # end

  # def on_subscribe_applied(table_name, rows, state) do
  #   {:ok, state}
  # end

  # def on_insert(table_name, row, state) do
  #   {:ok, state}
  # end

  # def on_delete(table_name, row, state) do
  #   {:ok, state}
  # end

  # def on_transaction(changes, state) do
  #   {:ok, state}
  # end

  # def on_reducer_result(request_id, result, state) do
  #   {:ok, state}
  # end

  # def on_disconnect(reason, state) do
  #   {:ok, state}
  # end
end