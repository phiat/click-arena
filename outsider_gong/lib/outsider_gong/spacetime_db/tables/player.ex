defmodule OutsiderGong.SpacetimeDB.Tables.Player do
  @moduledoc """
  Generated struct for the `player` table.
  """

  defstruct [:identity, :name, :score, :joined_at]

  @type t :: %__MODULE__{
          identity: integer(),
          name: String.t(),
          score: non_neg_integer(),
          joined_at: integer()
        }

  @doc "Convert a row map (string keys) to a struct."
  def from_row(row) when is_map(row) do
    %__MODULE__{
      identity: Map.get(row, "identity"),
      name: Map.get(row, "name"),
      score: Map.get(row, "score"),
      joined_at: Map.get(row, "joined_at")
    }
  end
end