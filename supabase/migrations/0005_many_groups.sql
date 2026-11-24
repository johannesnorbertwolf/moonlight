-- Moonlight: any number of groups. Anyone can start a group in the app; others join with its
-- invite link or 6-character code.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- Measurements are now keyed by the participant's id (uuid as text) instead of the name, because
-- names are only unique within a group. The iPhone app and the Android app (connected from the web
-- app) report with the id. Groups that existed before this migration also still match measurements
-- by name (match_names), so the old test data keeps showing.
--
-- group_data() still returns each measurement row with the member's *name* in "participant", so
-- the apps' matching code doesn't change.

alter table public.groups add column if not exists owner uuid references public.participants (id) on delete set null;
alter table public.groups add column if not exists match_names boolean not null default false;
update public.groups set match_names = true where created_at < now();

-- ---------------------------------------------------------------- codes

-- 6 characters without look-alikes (no 0/O, 1/I/L): 31^6 ≈ 887 million codes.
create or replace function public.new_join_code()
returns text
language plpgsql volatile set search_path = public as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.groups where join_code = code);
  end loop;
  return code;
end;
$$;

-- Codes are typed by people: accept lower case, spaces and dashes.
create or replace function public.normalize_code(p_code text)
returns text
language sql immutable as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
$$;

-- ---------------------------------------------------------------- join

-- Joins (or rejoins) a group. If the name is already used in the group, this fails with
-- 'name taken' unless p_takeover is true: then it takes over that participant (same person on a new
-- phone, or a lost sign-in), so history is kept. This browser/phone leaves any previous group.
drop function if exists public.join_group(text, text, time, text);
create or replace function public.join_group(p_code text, p_name text, p_goal time, p_platform text,
                                             p_takeover boolean default false)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  g public.groups;
  existing public.participants;
  pid uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into g from public.groups where join_code = public.normalize_code(p_code);
  if g.id is null then raise exception 'unknown group code' using errcode = 'P0002'; end if;

  select * into existing from public.participants where group_id = g.id and name = trim(p_name);
  if existing.id is not null and existing.auth_user is distinct from auth.uid() and not p_takeover then
    raise exception 'name taken' using errcode = 'P0003';
  end if;

  update public.participants set auth_user = null where auth_user = auth.uid() and id is distinct from existing.id;

  insert into public.participants (group_id, auth_user, name, goal_start, platform)
  values (g.id, auth.uid(), trim(p_name), p_goal, p_platform)
  on conflict (group_id, name) do update
    set auth_user = excluded.auth_user, goal_start = excluded.goal_start, platform = excluded.platform
  returning id into pid;
  return pid;
end;
$$;

-- Starts a new group with the caller as its first member and owner. The challenge starts with the
-- night of the day it's created (a night is dated by the evening it starts).
create or replace function public.create_group(p_group_name text, p_name text, p_goal time, p_platform text,
                                               p_timezone text default 'Europe/Amsterdam')
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  gid uuid;
  code text;
  pid uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if char_length(trim(coalesce(p_group_name, ''))) not between 1 and 40 then
    raise exception 'group name must be 1 to 40 characters';
  end if;
  perform now() at time zone p_timezone; -- fails on an unknown time zone
  code := public.new_join_code();
  insert into public.groups (name, join_code, timezone, challenge_start)
  values (trim(p_group_name), code, p_timezone, (now() at time zone p_timezone)::date)
  returning id into gid;
  pid := public.join_group(code, p_name, p_goal, p_platform, false);
  update public.groups set owner = pid where id = gid;
  return pid;
end;
$$;

-- What the join screen and the invite page show before someone joins. Public: knowing the code is
-- what lets you in anyway.
create or replace function public.group_info(p_code text)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'name', g.name,
    'code', g.join_code,
    'members', (select count(*) from public.participants p where p.group_id = g.id))
  from public.groups g where g.join_code = public.normalize_code(p_code);
$$;

-- ---------------------------------------------------------------- leave and remove

-- Deletes a participant with everything measured and reacted for them.
create or replace function public.delete_participant(p public.participants)
returns void
language plpgsql security definer set search_path = public as $$
declare
  keys text[] := array[p.id::text];
begin
  if (select match_names from public.groups where id = p.group_id) then keys := keys || p.name; end if;
  delete from public.test_events where participant = any (keys);
  delete from public.test_android_nights where participant = any (keys);
  delete from public.screen_time_nights where participant = any (keys);
  delete from public.participants where id = p.id; -- reactions go with it (on delete cascade)
end;
$$;

-- "Leave group and delete my data".
create or replace function public.leave_group()
returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.participants;
begin
  me := public.my_participant();
  if me.id is null then return; end if;
  perform public.delete_participant(me);
end;
$$;

-- The group's owner can remove a member (and their data).
create or replace function public.remove_member(p_member uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.participants;
  target public.participants;
begin
  me := public.my_participant();
  select * into target from public.participants where id = p_member;
  if me.id is null or target.id is null or target.group_id <> me.group_id then raise exception 'not in your group'; end if;
  if (select owner from public.groups where id = me.group_id) is distinct from me.id then raise exception 'only the owner can remove members'; end if;
  if target.id = me.id then raise exception 'use leave_group'; end if;
  perform public.delete_participant(target);
end;
$$;

-- ---------------------------------------------------------------- read everything for the app

-- Same as in 0004, plus the group's code and owner, and measurements matched by participant id
-- (and by name for groups from before this migration). Rows carry the member's name.
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
      'name', g.name, 'timezone', g.timezone, 'code', g.join_code, 'owner', g.owner,
      'challenge_start', g.challenge_start, 'challenge_nights', g.challenge_nights),
    'members', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.name, 'goal', to_char(p.goal_start, 'HH24:MI'), 'platform', p.platform)
        order by p.created_at), '[]')
      from public.participants p where p.group_id = g.id),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_array(p.name, e.kind, e.occurred_at) order by e.occurred_at), '[]')
      from public.test_events e
      join public.participants p on p.group_id = g.id
        and (e.participant = p.id::text or (g.match_names and e.participant = p.name))
      where e.occurred_at >= since),
    'android_nights', (
      select coalesce(jsonb_agg(jsonb_build_object('participant', p.name, 'night', n.night_date)), '[]')
      from public.test_android_nights n
      join public.participants p on p.group_id = g.id
        and (n.participant = p.id::text or (g.match_names and n.participant = p.name))
      where n.night_date >= g.challenge_start - 1),
    'screen_time_nights', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'participant', p.name, 'night', s.night_date,
        'minutes', s.minutes_at_least, 'crossed_at', s.crossed_at)), '[]')
      from public.screen_time_nights s
      join public.participants p on p.group_id = g.id
        and (s.participant = p.id::text or (g.match_names and s.participant = p.name))
      where s.night_date >= g.challenge_start - 1),
    'reactions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'target', r.target_id, 'night', r.night_date, 'from', r.from_id, 'emoji', r.emoji)), '[]')
      from public.reactions r join public.participants t on t.id = r.target_id
      where t.group_id = g.id)
  );
end;
$$;

-- ---------------------------------------------------------------- permissions

revoke all on function public.new_join_code() from public, anon, authenticated;
revoke all on function public.delete_participant(public.participants) from public, anon, authenticated;
revoke all on function public.join_group(text, text, time, text, boolean) from public, anon;
revoke all on function public.create_group(text, text, time, text, text) from public, anon;
revoke all on function public.leave_group() from public, anon;
revoke all on function public.remove_member(uuid) from public, anon;
grant execute on function public.join_group(text, text, time, text, boolean) to authenticated;
grant execute on function public.create_group(text, text, time, text, text) to authenticated;
grant execute on function public.leave_group() to authenticated;
grant execute on function public.remove_member(uuid) to authenticated;
grant execute on function public.group_info(text) to anon, authenticated;
