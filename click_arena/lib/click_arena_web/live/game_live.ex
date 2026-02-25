defmodule ClickArenaWeb.GameLive do
  use ClickArenaWeb, :live_view

  require Logger

  @player_topic "spacetimedb:player"
  @bonus_topic "spacetimedb:bonus"
  @refresh_delay_ms 100
  @bonus_points 10
  # 6 positions around the main button: {side, vertical}
  @bonus_positions ~w(top-left top-right mid-left mid-right low-left low-right)

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(ClickArena.PubSub, @player_topic)
      Phoenix.PubSub.subscribe(ClickArena.PubSub, @bonus_topic)
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
      |> assign(:bonuses, fetch_bonuses())
      |> assign(:popping, %{})
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

    # 10% chance every 20 clicks to spawn a bonus if slots available
    if rem(click_count, 20) == 0 and :rand.uniform() < 0.1 and length(socket.assigns.bonuses) < 6 do
      call_spawn_bonus(socket.assigns.bonuses)
    end

    schedule_refresh()
    {:noreply, socket}
  end

  def handle_event("bonus_click", %{"id" => bonus_id}, socket) do
    bonus_id = if is_binary(bonus_id), do: String.to_integer(bonus_id), else: bonus_id

    if not Map.has_key?(socket.assigns.popping, bonus_id) do
      # Snapshot the bonus data before it leaves the DB
      bonus = Enum.find(socket.assigns.bonuses, &(&1.id == bonus_id))

      Spacetimedbex.Client.call_reducer(
        Spacetimedbex.Phoenix,
        "claim_bonus",
        %{"session_id" => socket.assigns.session_id, "bonus_id" => bonus_id}
      )

      # Start pop animation, then clean up after it completes
      Process.send_after(self(), {:bonus_animation_done, bonus_id}, 800)
      schedule_refresh()
      popping = if bonus, do: Map.put(socket.assigns.popping, bonus_id, bonus), else: socket.assigns.popping
      {:noreply, assign(socket, popping: popping)}
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

    if socket.assigns.joined and length(socket.assigns.bonuses) < 6 do
      # ~50% chance each check (checks every 30-90s)
      if :rand.uniform() < 0.5 do
        call_spawn_bonus(socket.assigns.bonuses)
      end
    end

    {:noreply, socket}
  end

  def handle_info({:bonus_animation_done, bonus_id}, socket) do
    {:noreply, assign(socket, popping: Map.delete(socket.assigns.popping, bonus_id))}
  end

  def handle_info({:spacetimedb, _action, "player", _row}, socket) do
    {:noreply, assign(socket, players: fetch_players())}
  end

  def handle_info({:spacetimedb, _action, "bonus", _row}, socket) do
    new_bonuses = fetch_bonuses()
    new_ids = MapSet.new(new_bonuses, & &1.id)

    # Bonuses that disappeared (claimed by someone) — animate them out
    vanished =
      for bonus <- socket.assigns.bonuses,
          not MapSet.member?(new_ids, bonus.id),
          not Map.has_key?(socket.assigns.popping, bonus.id),
          into: %{} do
        Process.send_after(self(), {:bonus_animation_done, bonus.id}, 800)
        {bonus.id, bonus}
      end

    popping = Map.merge(socket.assigns.popping, vanished)
    {:noreply, assign(socket, bonuses: new_bonuses, popping: popping)}
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

  defp call_spawn_bonus(current_bonuses) do
    taken = MapSet.new(current_bonuses, & &1.position)
    free = Enum.reject(@bonus_positions, &MapSet.member?(taken, &1))

    case free do
      [] -> :noop
      positions ->
        position = Enum.random(positions)

        Spacetimedbex.Client.call_reducer(
          Spacetimedbex.Phoenix,
          "spawn_bonus",
          %{"position" => position, "points" => @bonus_points}
        )
    end
  end

  defp fetch_bonuses do
    Spacetimedbex.Phoenix.get_all("bonus")
    |> Enum.map(fn b ->
      %{id: b["id"], position: b["position"], points: b["points"]}
    end)
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
            <%!-- Live bonuses (not currently popping) --%>
            <%= for bonus <- @bonuses, not Map.has_key?(@popping, bonus.id) do %>
              <button
                phx-click="bonus_click"
                phx-value-id={bonus.id}
                class={"bonus-btn bonus-#{bonus.position}"}
              >
                +{bonus.points}
              </button>
            <% end %>
            <%!-- Popping bonuses (animating into center button) --%>
            <%= for {_id, bonus} <- @popping do %>
              <div class={"bonus-btn bonus-#{bonus.position} bonus-genie"}>
                +{bonus.points}
              </div>
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
