defmodule OutsiderGongWeb.GameLive do
  use OutsiderGongWeb, :live_view

  require Logger

  @topic "spacetimedb:player"
  @refresh_delay_ms 100

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(OutsiderGong.PubSub, @topic)
      # Poll for updates every 500ms as a fallback
      :timer.send_interval(500, self(), :tick)
    end

    socket =
      socket
      |> assign(:player_name, "")
      |> assign(:joined, false)
      |> assign(:players, fetch_players())
      |> assign(:tick, 0)

    {:ok, socket}
  end

  def handle_event("join", %{"name" => name}, socket) when name != "" do
    Spacetimedbex.Client.call_reducer(Spacetimedbex.Phoenix, "join_game", %{"name" => name})
    schedule_refresh()
    {:noreply, assign(socket, joined: true, player_name: name)}
  end

  def handle_event("join", _params, socket), do: {:noreply, socket}

  def handle_event("click", _params, socket) do
    Spacetimedbex.Client.call_reducer(Spacetimedbex.Phoenix, "click", %{})
    schedule_refresh()
    {:noreply, socket}
  end

  def handle_event("leave", _params, socket) do
    Spacetimedbex.Client.call_reducer(Spacetimedbex.Phoenix, "leave_game", %{})
    schedule_refresh()
    {:noreply, assign(socket, joined: false)}
  end

  def handle_info(:refresh_players, socket) do
    {:noreply, assign(socket, players: fetch_players())}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, players: fetch_players(), tick: socket.assigns.tick + 1)}
  end

  def handle_info({:spacetimedb, _action, "player", _row}, socket) do
    {:noreply, assign(socket, players: fetch_players())}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp schedule_refresh do
    Process.send_after(self(), :refresh_players, @refresh_delay_ms)
  end

  defp fetch_players do
    Spacetimedbex.Phoenix.get_all("player")
    |> Enum.map(fn p ->
      %{name: p["name"], score: p["score"]}
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  def render(assigns) do
    ~H"""
    <div class="arena">
      <div class="geo-accent"></div>
      <div class="geo-accent-2"></div>

      <h1 class="arena-title">Click Arena</h1>
      <p class="arena-subtitle">SpacetimeDB + Elixir</p>

      <%= if !@joined do %>
        <form phx-submit="join" class="join-form">
          <input
            type="text"
            name="name"
            placeholder="Your name"
            class="join-input"
            autofocus
          />
          <button type="submit" class="join-btn">Enter</button>
        </form>
      <% else %>
        <div class="play-area">
          <p class="playing-as">Playing as <strong>{@player_name}</strong></p>
          <button phx-click="click" class="click-btn">Click</button>
          <br />
          <button phx-click="leave" class="leave-btn">Leave game</button>
        </div>
      <% end %>

      <div class="divider"></div>

      <p class="board-header">Leaderboard</p>

      <%= if @players == [] do %>
        <p class="board-empty">No players yet</p>
      <% else %>
        <%= for {player, idx} <- Enum.with_index(@players, 1) do %>
          <div class="board-row">
            <span class="board-rank">{idx}</span>
            <span class="board-name">{player.name}</span>
            <span class="board-score">{player.score}</span>
          </div>
        <% end %>
      <% end %>

      <p class="arena-footer">
        {length(@players)} player(s)
      </p>
    </div>
    """
  end
end
