-- Moonlight: nights reported by the native iPhone app (Screen Time).
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- Apple's Screen Time API never hands out raw usage. The app's DeviceActivity monitor only learns
-- that a usage threshold (2, 5, 15 or 60 minutes) was reached during the night window, and when.
-- So each night is stored as "at least N minutes" plus the time the first threshold was crossed.
--
-- The monitor extension reports with the public key (like the Android app), through
-- report_screen_time_night() below, so the table itself stays closed.

create table if not exists public.screen_time_nights (
  participant   text not null,
  night_date    date not null,
  window_start  timestamptz not null,
  window_end    timestamptz not null,
  minutes_at_least integer not null check (minutes_at_least in (0, 2, 5, 15, 60)),
  crossed_at    timestamptz,        -- when 2 minutes were reached; null on a phone-free night
  reported_at   timestamptz not null default now(),
  primary key (participant, night_date)
);

alter table public.screen_time_nights enable row level security;

-- Upsert one night. A later report can only raise the minutes (thresholds only go up), so a late
-- or repeated upload never turns a broken night back into a phone-free one.
create or replace function public.report_screen_time_night(
  p_participant text, p_night date, p_window_start timestamptz, p_window_end timestamptz,
  p_minutes integer, p_crossed_at timestamptz)
returns void
language sql security definer set search_path = public as $$
  insert into public.screen_time_nights
    (participant, night_date, window_start, window_end, minutes_at_least, crossed_at)
  values (trim(p_participant), p_night, p_window_start, p_window_end, p_minutes, p_crossed_at)
  on conflict (participant, night_date) do update set
    minutes_at_least = greatest(screen_time_nights.minutes_at_least, excluded.minutes_at_least),
    crossed_at = coalesce(screen_time_nights.crossed_at, excluded.crossed_at),
    window_start = excluded.window_start,
    window_end = excluded.window_end,
    reported_at = now();
$$;

revoke all on function public.report_screen_time_night(text, date, timestamptz, timestamptz, integer, timestamptz) from public;
grant execute on function public.report_screen_time_night(text, date, timestamptz, timestamptz, integer, timestamptz) to anon, authenticated;

-- group_data(): same as in 0002, plus the Screen Time nights.
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
    'screen_time_nights', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'participant', s.participant, 'night', s.night_date,
        'minutes', s.minutes_at_least, 'crossed_at', s.crossed_at)), '[]')
      from public.screen_time_nights s
      where s.night_date >= g.challenge_start - 1
        and s.participant in (select name from public.participants where group_id = g.id)),
    'reactions', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'target', r.target_id, 'night', r.night_date, 'from', r.from_id, 'emoji', r.emoji)), '[]')
      from public.reactions r join public.participants t on t.id = r.target_id
      where t.group_id = g.id)
  );
end;
$$;
