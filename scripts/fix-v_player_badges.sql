-- Fix v_player_badges view to use current schema (challenger_id, challenged_id, status)
DROP VIEW IF EXISTS public.v_player_badges;

create or replace view public.v_player_badges as
with active_event as (
  select id
    from events
   where actiu is true
   order by creat_el desc
   limit 1
),
cfg as (
  select coalesce(
           (select cooldown_min_dies
              from app_settings
             order by updated_at desc
             limit 1),
           0
         ) as cooldown_min_dies
),
lp as (
  select rp.event_id,
         rp.player_id,
         max(coalesce(m.data_joc::date, c.data_proposta::date)) as last_play_date,
         case
           when max(coalesce(m.data_joc::date, c.data_proposta::date)) is null then null
           else (current_date - max(coalesce(m.data_joc::date, c.data_proposta::date)))::int
         end as days_since_last
    from ranking_positions rp
    join active_event ae on ae.id = rp.event_id
    left join challenges c
      on c.event_id = rp.event_id
     and (c.challenger_id = rp.player_id or c.challenged_id = rp.player_id)
    left join matches m on m.challenge_id = c.id
   group by rp.event_id, rp.player_id
),
active as (
  select event_id, challenger_id as player_id
    from challenges
   where status in ('PENDING', 'ACCEPTED', 'SCHEDULED')
  union
  select event_id, challenged_id as player_id
    from challenges
   where status in ('PENDING', 'ACCEPTED', 'SCHEDULED')
)
select rp.event_id,
       rp.player_id,
       rp.posicio,
       lp.last_play_date,
       lp.days_since_last,
       (ac.player_id is not null) as has_active_challenge,
       case
         when lp.last_play_date is null then false
         when lp.days_since_last < (select cooldown_min_dies from cfg) then true
         else false
       end as in_cooldown,
       case
         when ac.player_id is not null then false
         when lp.last_play_date is not null and lp.days_since_last < (select cooldown_min_dies from cfg) then false
         else true
       end as can_be_challenged,
       greatest((select cooldown_min_dies from cfg) - lp.days_since_last, 0) as cooldown_days_left
  from ranking_positions rp
  join active_event ae on ae.id = rp.event_id
  left join lp on lp.event_id = rp.event_id and lp.player_id = rp.player_id
  left join active ac on ac.event_id = rp.event_id and ac.player_id = rp.player_id;

-- Grant permissions
GRANT SELECT ON public.v_player_badges TO authenticated;