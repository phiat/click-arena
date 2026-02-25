use spacetimedb::{table, reducer, ReducerContext, Table, Timestamp};

#[table(accessor = player, public)]
pub struct Player {
    #[primary_key]
    identity: spacetimedb::Identity,
    name: String,
    score: u64,
    joined_at: Timestamp,
}

#[reducer]
pub fn join_game(ctx: &ReducerContext, name: String) {
    // Remove existing entry if re-joining
    if let Some(existing) = ctx.db.player().identity().find(ctx.sender()) {
        ctx.db.player().identity().delete(existing.identity);
    }
    ctx.db.player().insert(Player {
        identity: ctx.sender(),
        name,
        score: 0,
        joined_at: ctx.timestamp,
    });
}

#[reducer]
pub fn click(ctx: &ReducerContext) {
    if let Some(mut p) = ctx.db.player().identity().find(ctx.sender()) {
        let new_score = p.score + 1;
        ctx.db.player().identity().delete(p.identity);
        p.score = new_score;
        ctx.db.player().insert(p);
    }
}

#[reducer]
pub fn leave_game(ctx: &ReducerContext) {
    if let Some(existing) = ctx.db.player().identity().find(ctx.sender()) {
        ctx.db.player().identity().delete(existing.identity);
    }
}
