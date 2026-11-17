-- Moonlight: groups, participants and reactions for the web app.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
-- Also turn on anonymous sign-ins: Authentication → Sign In / Providers → "Allow anonymous sign-ins".
--
-- How identity works (CONCEPT.md §8): the web app signs in anonymously, then joins the group with
-- its code and the participant name. The name links the person to the events their phone sends
-- (test_events.participant), so it must match what the Shortcuts / Android app use.
--
-- All reads and writes from the web app go through the security-definer functions below, which
-- check group membership. The tables themselves stay closed to the public key.

create table if not exists public.groups (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  join_code        text not null unique,
  timezone         text not null default 'Europe/Amsterdam',
  challenge_start  date not null,
  challenge_nights integer not null default 14,
  created_at       timestamptz not null default now()
);

create table if not exists public.participants (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups (id) on delete cascade,
  auth_user   uuid unique references auth.users (id) on delete set null,
  name        text not null check (char_length(name) between 1 and 40),
  goal_start  time not null default '21:00',
  platform    text not null check (platform in ('ios', 'android')),
  created_at  timestamptz not null default now(),
  unique (group_id, name)
);

create table if not exists public.reactions (
  target_id   uuid not null references public.participants (id) on delete cascade,
  night_date  date not null,
  from_id     uuid not null references public.participants (id) on delete cascade,
  emoji       text not null check (emoji in ('🌙','👏','🔥','😴','❤️','🛌','🦉','🦥','🥱')),
  created_at  timestamptz not null default now(),
  primary key (target_id, night_date, from_id)
);

alter table public.groups       enable row level security;
alter table public.participants enable row level security;
alter table public.reactions    enable row level security;
-- No policies: nothing is readable or writable directly with the public key.

-- The trial group, with a random 6-character join code. Read it afterwards with:
--   select name, join_code from public.groups;
insert into public.groups (name, join_code, challenge_start)
select 'Moonlight test', upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)), current_date
where not exists (select 1 from public.groups);

-- ---------------------------------------------------------------- helpers

create or replace function public.my_participant()
returns public.participants
language sql stable security definer set search_path = public as $$
  select * from public.participants where auth_user = auth.uid() limit 1;
$$;

-- ---------------------------------------------------------------- join

-- Joins the group with the given code. Re-joining with the same name (new phone, cleared browser)
-- takes over the existing participant, so history is kept.
create or replace function public.join_group(p_code text, p_name text, p_goal time, p_platform text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  g public.groups;
  pid uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into g from public.groups where join_code = upper(trim(p_code));
  if g.id is null then raise exception 'unknown group code' using errcode = 'P0002'; end if;

  -- Leave any previous link of this browser.
  update public.participants set auth_user = null where auth_user = auth.uid();

  insert into public.participants (group_id, auth_user, name, goal_start, platform)
  values (g.id, auth.uid(), trim(p_name), p_goal, p_platform)
  on conflict (group_id, name) do update
    set auth_user = excluded.auth_user, goal_start = excluded.goal_start, platform = excluded.platform
  returning id into pid;
  return pid;
end;
$$;

-- ---------------------------------------------------------------- read everything for the app

-- Returns the caller's group, members, raw events since the challenge start (minus a day), the
-- Android precise nights, and reactions. The web app computes nights from the events with the
-- same rule as analysis/summarize_nights.py.
create or replace function public.group_data()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.participants;
  g public.groups;
  since timestamptz;
begin
  me := public.my_participant();
  if me.id is null then return null; end if;
  select * into g from public.groups where id = me.group_id;
  since := (g.challenge_start - 1)::timestamp at time zone g.timezone;

  return jsonb_build_object(
    'me', me.id,
    'group', jsonb_build_object(
      'name', g.name, 'timezone', g.timezone,
      'challenge_start', g.challenge_start, 'challenge_nights', g.challenge_nights),
    'members', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.name, 'goal', to_char(p.goal_start, 'HH24:MI'), 'platform', p.platform)
        order by p.created_at), '[]')
      from public.participants p where p.group_id = g.id),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_array(e.participant, e.kind, e.occurred_at) order by e.occurred_at), '[]')
      from public.test_events e
      where e.occurred_at >= since
        and e.participant in (select name from public.participants where group_id = g.id)),
    'android_nights', (
      select coalesce(jsonb_agg(jsonb_build_object('participant', n.participant, 'night', n.night_date)), '[]')
      from public.test_android_nights n
      where n.night_date >= g.challenge_start - 1
        and n.participant in (select name from public.participants where group_id = g.id)),
    'reactions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'target', r.target_id, 'night', r.night_date, 'from', r.from_id, 'emoji', r.emoji)), '[]')
      from public.reactions r join public.participants t on t.id = r.target_id
      where t.group_id = g.id)
  );
end;
$$;

-- ---------------------------------------------------------------- writes

create or replace function public.set_reaction(p_target uuid, p_night date, p_emoji text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.participants;
begin
  me := public.my_participant();
  if me.id is null then raise exception 'not in a group'; end if;
  if p_target = me.id then raise exception 'no reactions to yourself'; end if;
  if not exists (select 1 from public.participants where id = p_target and group_id = me.group_id) then
    raise exception 'not in your group';
  end if;
  if p_emoji is null then
    delete from public.reactions where target_id = p_target and night_date = p_night and from_id = me.id;
  else
    insert into public.reactions (target_id, night_date, from_id, emoji)
    values (p_target, p_night, me.id, p_emoji)
    on conflict (target_id, night_date, from_id) do update set emoji = excluded.emoji, created_at = now();
  end if;
end;
$$;

create or replace function public.update_goal(p_goal time)
returns void
language sql security definer set search_path = public as $$
  update public.participants set goal_start = p_goal where auth_user = auth.uid();
$$;

revoke all on function public.my_participant() from public, anon;
revoke all on function public.join_group(text, text, time, text) from public, anon;
revoke all on function public.group_data() from public, anon;
revoke all on function public.set_reaction(uuid, date, text) from public, anon;
revoke all on function public.update_goal(time) from public, anon;
grant execute on function public.join_group(text, text, time, text) to authenticated;
grant execute on function public.group_data() to authenticated;
grant execute on function public.set_reaction(uuid, date, text) to authenticated;
grant execute on function public.update_goal(time) to authenticated;
