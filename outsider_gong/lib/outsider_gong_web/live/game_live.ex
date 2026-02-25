defmodule OutsiderGongWeb.GameLive do
  use OutsiderGongWeb, :live_view

  require Logger

  @topic "spacetimedb:player"
  @refresh_delay_ms 100
  @bonus_points 10
  # 6 positions around the main button: {side, vertical}
  @bonus_positions ~w(top-left top-right mid-left mid-right low-left low-right)

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(OutsiderGong.PubSub, @topic)
      :timer.send_interval(500, self(), :tick)
      schedule_bonus_check()
    end

    session_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:player_name, "")
      |> assign(:joined, false)
      |> assign(:players, fetch_players())
      |> assign(:tick, 0)
      |> assign(:bonus_visible, false)
      |> assign(:bonus_position, "top-left")
      |> assign(:bonus_popping, false)
      |> assign(:bonus_points, @bonus_points)
      |> assign(:click_count, 0)

    {:ok, socket}
  end

  # --- Events ---

  def handle_event("join", %{"name" => name}, socket) when name != "" do
    sid = socket.assigns.session_id

    Spacetimedbex.Client.call_reducer(
      Spacetimedbex.Phoenix,
      "join_game",
      %{"session_id" => sid, "name" => name}
    )

    schedule_refresh()
    {:noreply, assign(socket, joined: true, player_name: name)}
  end

  def handle_event("join", _params, socket), do: {:noreply, socket}

  def handle_event("click", _params, socket) do
    Spacetimedbex.Client.call_reducer(
      Spacetimedbex.Phoenix,
      "click",
      %{"session_id" => socket.assigns.session_id}
    )

    click_count = socket.assigns.click_count + 1
    socket = assign(socket, click_count: click_count)

    # Check if we should spawn bonus on score milestones (every 50 clicks, 50% chance)
    socket =
      if rem(click_count, 50) == 0 and :rand.uniform() < 0.5 and not socket.assigns.bonus_visible do
        spawn_bonus(socket)
      else
        socket
      end

    schedule_refresh()
    {:noreply, socket}
  end

  def handle_event("bonus_click", _params, socket) do
    if socket.assigns.bonus_visible and not socket.assigns.bonus_popping do
      Spacetimedbex.Client.call_reducer(
        Spacetimedbex.Phoenix,
        "bonus_click",
        %{"session_id" => socket.assigns.session_id, "points" => @bonus_points}
      )

      # Start pop animation, then hide after animation completes
      Process.send_after(self(), :bonus_animation_done, 600)
      schedule_refresh()
      {:noreply, assign(socket, bonus_popping: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("leave", _params, socket) do
    Spacetimedbex.Client.call_reducer(
      Spacetimedbex.Phoenix,
      "leave_game",
      %{"session_id" => socket.assigns.session_id}
    )

    schedule_refresh()
    {:noreply, assign(socket, joined: false, click_count: 0)}
  end

  # --- Info handlers ---

  def handle_info(:refresh_players, socket) do
    {:noreply, assign(socket, players: fetch_players())}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign(socket, players: fetch_players(), tick: socket.assigns.tick + 1)}
  end

  def handle_info(:maybe_spawn_bonus, socket) do
    schedule_bonus_check()

    socket =
      if socket.assigns.joined and not socket.assigns.bonus_visible do
        # ~50% chance each check (checks every 30-90s)
        if :rand.uniform() < 0.5 do
          spawn_bonus(socket)
        else
          socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:bonus_animation_done, socket) do
    {:noreply, assign(socket, bonus_visible: false, bonus_popping: false)}
  end

  def handle_info({:spacetimedb, _action, "player", _row}, socket) do
    {:noreply, assign(socket, players: fetch_players())}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Helpers ---

  defp schedule_refresh do
    Process.send_after(self(), :refresh_players, @refresh_delay_ms)
  end

  defp schedule_bonus_check do
    # Random interval between 30-90 seconds
    delay = :rand.uniform(60_000) + 30_000
    Process.send_after(self(), :maybe_spawn_bonus, delay)
  end

  defp spawn_bonus(socket) do
    position = Enum.random(@bonus_positions)
    assign(socket, bonus_visible: true, bonus_position: position, bonus_popping: false)
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
          <div class="click-zone">
            <button phx-click="click" class="click-btn">Click</button>
            <%= if @bonus_visible do %>
              <button
                phx-click="bonus_click"
                class={"bonus-btn bonus-#{@bonus_position}" <> if(@bonus_popping, do: " bonus-pop", else: "")}
              >
                +{@bonus_points}
              </button>
              <%= if @bonus_popping do %>
                <div class={"bonus-ring bonus-#{@bonus_position}"}></div>
              <% end %>
            <% end %>
          </div>
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
