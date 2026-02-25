defmodule OutsiderGong.SpacetimeDB.Reducers do
  @moduledoc """
  Generated reducer functions.
  """

  @doc "Call the `click` reducer."
  @spec click(GenServer.server()) :: :ok | {:error, term()}
  def click(client) do
    Spacetimedbex.Client.call_reducer(client, "click", %{})
  end

  @doc "Call the `join_game` reducer."
  @spec join_game(GenServer.server(), name :: String.t()) :: :ok | {:error, term()}
  def join_game(client, name) do
    Spacetimedbex.Client.call_reducer(client, "join_game", %{"name" => name})
  end

  @doc "Call the `leave_game` reducer."
  @spec leave_game(GenServer.server()) :: :ok | {:error, term()}
  def leave_game(client) do
    Spacetimedbex.Client.call_reducer(client, "leave_game", %{})
  end
end