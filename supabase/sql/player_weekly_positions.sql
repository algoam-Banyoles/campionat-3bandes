create table if not exists public.player_weekly_positions (
  event_id uuid not null references events(id),
  player_id uuid not null references players(id),
  setmana integer not null,
  posicio integer not null,
  primary key (event_id, player_id, setmana)
);

-- index to speed up lookups by player
create index if not exists player_weekly_positions_player_idx on public.player_weekly_positions(player_id);
