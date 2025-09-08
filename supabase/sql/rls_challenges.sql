-- Row Level Security policies for challenges and dependencies

-- Enable RLS on challenges
alter table public.challenges enable row level security;

-- Allow authenticated users to select from challenges
create policy "Authenticated users can select challenges"
  on public.challenges
  for select
  to authenticated
  using (true);

-- Players can create a challenge for themselves when allowed
create policy "Players can insert challenges"
  on public.challenges
  for insert
  to authenticated
  with check (
    auth.jwt()->>'email' = (
      select email from public.players where id = reptador_id
    )
    and (
      select ok from public.can_create_challenge(event_id, reptador_id, reptat_id)
    )
  );

-- Admins can insert challenges regardless of checks
create policy "Admins can insert challenges"
  on public.challenges
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.admins where email = auth.jwt()->>'email'
    )
  );

-- Admins can update challenge status fields
create policy "Admins can update challenges"
  on public.challenges
  for update
  to authenticated
  using (
    exists (
      select 1 from public.admins where email = auth.jwt()->>'email'
    )
  )
  with check (
    exists (
      select 1 from public.admins where email = auth.jwt()->>'email'
    )
  );

-- Ensure SELECT access for supporting tables
alter table public.players enable row level security;
create policy "Authenticated users can select players"
  on public.players
  for select
  to authenticated
  using (true);

alter table public.events enable row level security;
create policy "Authenticated users can select events"
  on public.events
  for select
  to authenticated
  using (true);

alter table public.ranking_positions enable row level security;
create policy "Authenticated users can select ranking_positions"
  on public.ranking_positions
  for select
  to authenticated
  using (true);
