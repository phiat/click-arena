use spacetimedb::{table, reducer, ReducerContext, Table, Timestamp};

#[table(accessor = player, public)]
pub struct Player {
    #[primary_key]
    session_id: String,
    name: String,
    score: u64,
    joined_at: Timestamp,
}

#[reducer]
pub fn join_game(ctx: &ReducerContext, session_id: String, name: String) {
    // Remove any existing entry for this session_id
    if let Some(existing) = ctx.db.player().session_id().find(&session_id) {
        ctx.db.player().session_id().delete(existing.session_id);
    }
    // Remove any existing entry with the same name (prevents duplicates)
    let dupes: Vec<_> = ctx.db.player().iter().filter(|p| p.name == name).collect();
    for dupe in dupes {
        ctx.db.player().session_id().delete(dupe.session_id);
    }
    ctx.db.player().insert(Player {
        session_id,
        name,
        score: 0,
        joined_at: ctx.timestamp,
    });
}

#[reducer]
pub fn click(ctx: &ReducerContext, session_id: String) {
    if let Some(mut p) = ctx.db.player().session_id().find(&session_id) {
        let new_score = p.score + 1;
        ctx.db.player().session_id().delete(p.session_id.clone());
        p.score = new_score;
        ctx.db.player().insert(p);
    }
}

#[reducer]
pub fn bonus_click(ctx: &ReducerContext, session_id: String, points: u64) {
    if let Some(mut p) = ctx.db.player().session_id().find(&session_id) {
        let new_score = p.score + points;
        ctx.db.player().session_id().delete(p.session_id.clone());
        p.score = new_score;
        ctx.db.player().insert(p);
    }
}

#[reducer]
pub fn leave_game(ctx: &ReducerContext, session_id: String) {
    if let Some(existing) = ctx.db.player().session_id().find(&session_id) {
        ctx.db.player().session_id().delete(existing.session_id);
    }
}
