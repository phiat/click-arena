# Click Arena

![Click Arena](click-arena.png)

A real-time multiplayer clicking game built with **Phoenix LiveView** and **SpacetimeDB**.

Players join with a name, compete for clicks on a shared leaderboard, and race to claim bonus buttons that appear for all players simultaneously.

## Stack

- **Frontend**: Phoenix LiveView (Elixir) — no JavaScript needed for real-time updates
- **Backend DB**: SpacetimeDB (Rust WASM module) — server-authoritative game state
- **Bridge**: [Spacetimedbex](https://github.com/phiat/spacetimedbex) — Elixir client for SpacetimeDB over WebSocket
- **Styling**: Hand-written CSS, neo-Bauhaus dark theme

## Running locally

### Prerequisites

- Elixir 1.17+
- SpacetimeDB CLI (`spacetime`) with a local instance running on port 3000
- Rust toolchain with `wasm32-unknown-unknown` target

### SpacetimeDB module

```bash
cd click_arena_module
cargo build --target wasm32-unknown-unknown --release
spacetime publish clickarena
```

### Phoenix server

```bash
cd click_arena
mix setup
mix phx.server
```

Configure via environment variables:

| Variable | Default | Description |
|---|---|---|
| `SPACETIMEDB_HOST` | `localhost:3000` | SpacetimeDB host |
| `SPACETIMEDB_DATABASE` | `clickarena5` | Database name from `spacetime publish` |
| `SECRET_KEY_BASE` | auto-generated (dev) | Phoenix secret key (required in prod) |

Visit [localhost:4000](http://localhost:4000).

## How it works

1. Players join by entering a name — this calls the `join_game` reducer in SpacetimeDB
2. Clicking the big button calls the `click` reducer, incrementing score by 1
3. Bonus buttons (+10 points) spawn as shared state in SpacetimeDB — all players see them simultaneously
4. Up to 6 bonuses can be active at once, each in a different position around the click button
5. First player to click a bonus claims it — it disappears for everyone with a genie animation (fizzle then fly into the main button)
6. Bonuses spawn via click milestones (10% chance every 20 clicks) and a random timer (every 30-90 seconds)
7. The leaderboard updates in real-time via SpacetimeDB subscriptions piped through Phoenix PubSub
8. Re-joining with the same name reclaims your leaderboard slot (no duplicates)

## Architecture

```
Browser ←WebSocket→ Phoenix LiveView ←WebSocket→ SpacetimeDB
                         ↕
                    Phoenix PubSub
                    (player + bonus table subscriptions)
```

**SpacetimeDB tables**: `Player` (session_id, name, score) and `Bonus` (id, position, points)

**Reducers**: `join_game`, `click`, `spawn_bonus`, `claim_bonus`, `leave_game`

## License

MIT
