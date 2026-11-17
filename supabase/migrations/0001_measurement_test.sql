-- Moonlight measurement test: raw usage events from iPhone (Shortcuts) and Android.
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.
--
-- Security model for the test: the phones use the public (anon/publishable) key and may only
-- INSERT. Nobody can read the data with that key. Reading happens in the dashboard or with the
-- secret (service role) key from analysis/summarize_nights.py.

create table if not exists public.test_events (
  id           bigint generated always as identity primary key,
  participant  text        not null check (char_length(participant) between 1 and 40),
  platform     text        not null check (platform in ('ios', 'android')),
  kind         text        not null check (kind in ('open', 'close', 'screen_off')),
  occurred_at  timestamptz not null default now(),
  received_at  timestamptz not null default now(),
  source       text        not null default 'unknown' check (char_length(source) <= 40),
  -- Android uploads the same night again if the job is re-run; this keeps rows unique.
  unique (participant, platform, kind, occurred_at)
);

create index if not exists test_events_participant_time
  on public.test_events (participant, occurred_at);

-- Android only, test only: the precise usage measured by the phone itself, to judge how good
-- the open/close estimate is.
create table if not exists public.test_android_nights (
  participant      text        not null check (char_length(participant) between 1 and 40),
  night_date       date        not null,
  window_start     timestamptz not null,
  window_end       timestamptz not null,
  precise_seconds  integer     not null check (precise_seconds >= 0),
  crossed_at       timestamptz,
  opens            integer     not null check (opens >= 0),
  computed_at      timestamptz not null default now(),
  primary key (participant, night_date)
);

alter table public.test_events         enable row level security;
alter table public.test_android_nights enable row level security;

-- Insert-only for the phones.
drop policy if exists "phones insert events" on public.test_events;
create policy "phones insert events" on public.test_events
  for insert to anon with check (true);

drop policy if exists "phones insert nights" on public.test_android_nights;
create policy "phones insert nights" on public.test_android_nights
  for insert to anon with check (true);

-- Android re-uploads a night with an upsert, which needs UPDATE on its own rows.
drop policy if exists "phones update nights" on public.test_android_nights;
create policy "phones update nights" on public.test_android_nights
  for update to anon using (true) with check (true);

-- Upserts also need SELECT for conflict detection in PostgREST; allow it only on the nights
-- table, which holds nothing more than what the group will see anyway.
drop policy if exists "phones read nights" on public.test_android_nights;
create policy "phones read nights" on public.test_android_nights
  for select to anon using (true);

grant insert on public.test_events to anon;
grant insert, update, select on public.test_android_nights to anon;
