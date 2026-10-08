-- GymBlock cloud schema. Every row belongs to one account (auth.users) and only that account can
-- read or write it (row-level security). Product analytics rows can be inserted before sign-in
-- (install id only) and are never readable from the app. Tables are prefixed gb_ because this
-- Supabase project is shared with other apps.
--
-- Run in the Supabase SQL editor (project tlcmpgxuyngsbjuhring) or with `supabase db push`.
-- Repeat-safe: every statement is `if not exists` / `create or replace`.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------------------------
-- Profile: one row per account. Everything from the app's Profile, baseline answers as JSON.
-- ---------------------------------------------------------------------------------------------
create table if not exists public.gb_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '' check (char_length(name) <= 60),
  language text not null default 'en' check (language in ('en', 'es')),
  gender text check (gender in ('male', 'female', 'other')),
  height_cm numeric(5,1) check (height_cm between 50 and 300),
  body_weight_kg numeric(5,1) check (body_weight_kg between 20 and 400),
  unit text not null default 'kg' check (unit in ('kg', 'lb')),
  rest_seconds integer check (rest_seconds between 10 and 900),
  rest_alerts boolean,
  time_sets boolean,
  haptics_enabled boolean,
  sound_enabled boolean,
  focus_enabled boolean,
  block_whole_phone boolean not null default true,
  blocked_apps text[] not null default '{}',
  preferred_split_id uuid,
  onboarded boolean not null default false,
  onboarding_step text,
  onboarding_version integer,
  pledged boolean not null default false,
  baseline jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Splits: a named, ordered list of exercises. Exercises are stored as they were at save time.
-- ---------------------------------------------------------------------------------------------
create table if not exists public.gb_splits (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 50),
  exercises jsonb not null default '[]'::jsonb,
  position integer not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists gb_splits_user on public.gb_splits(user_id, position);

-- ---------------------------------------------------------------------------------------------
-- Workouts: one row per session (finished or still running), and one row per logged set.
-- ---------------------------------------------------------------------------------------------
create table if not exists public.gb_workouts (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  split_id uuid,
  name text not null default '' check (char_length(name) <= 60),
  started_at timestamptz not null,
  ended_at timestamptz,
  paused_seconds numeric(10,1) not null default 0,
  duration_seconds numeric(10,1),
  exercises jsonb not null default '[]'::jsonb,
  set_count integer not null default 0,
  total_reps integer not null default 0,
  volume_kg numeric(12,2) not null default 0,
  state jsonb,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists gb_workouts_user_started on public.gb_workouts(user_id, started_at desc);

create table if not exists public.gb_sets (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_id uuid not null references public.gb_workouts(id) on delete cascade,
  position integer not null default 0,
  exercise_id text not null check (char_length(exercise_id) <= 64),
  exercise_name text not null check (char_length(exercise_name) <= 80),
  exercise_area text not null default '' check (char_length(exercise_area) <= 40),
  timed boolean not null default false,
  weight_kg numeric(7,2) not null default 0,
  reps integer not null default 0 check (reps between 0 and 999),
  minutes numeric(8,2) not null default 0,
  logged_at timestamptz not null,
  warmup boolean not null default false,
  unsuccessful boolean not null default false,
  timing_unknown boolean not null default false,
  set_seconds numeric(10,1),
  gap_before_seconds numeric(10,1),
  gap_source_id uuid,
  gap_unknown boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists gb_sets_workout on public.gb_sets(workout_id, position);
create index if not exists gb_sets_user_exercise on public.gb_sets(user_id, exercise_id, logged_at desc);

-- ---------------------------------------------------------------------------------------------
-- Devices: one row per install, so every event and account can be tied to the hardware it ran on.
-- ---------------------------------------------------------------------------------------------
create table if not exists public.gb_devices (
  install_id uuid primary key,
  user_id uuid references auth.users(id) on delete set null,
  model text not null default '' check (char_length(model) <= 60),
  os_version text not null default '' check (char_length(os_version) <= 30),
  app_version text not null default '' check (char_length(app_version) <= 30),
  build text not null default '' check (char_length(build) <= 30),
  locale text not null default '' check (char_length(locale) <= 20),
  time_zone text not null default '' check (char_length(time_zone) <= 60),
  notifications text check (notifications in ('authorized', 'denied', 'not_determined')),
  reduce_motion boolean,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Subscription snapshot from RevenueCat, so entitlement history lives next to the account.
-- ---------------------------------------------------------------------------------------------
create table if not exists public.gb_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  entitled boolean not null default false,
  product_id text,
  will_renew boolean,
  expires_at timestamptz,
  original_purchase_at timestamptz,
  store text,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Product analytics: every screen, tap, choice, workout step, purchase and error the app sees.
-- Properties are a small JSON object of fixed keys and bounded values: never free text.
-- ---------------------------------------------------------------------------------------------
create table if not exists public.gb_events (
  id uuid primary key,
  install_id uuid not null,
  session_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  name text not null check (name ~ '^[a-z0-9_.]{1,64}$'),
  screen text check (screen ~ '^[a-z0-9_.]{1,64}$'),
  properties jsonb not null default '{}'::jsonb check (pg_column_size(properties) <= 4096),
  duration_ms integer check (duration_ms between 0 and 86400000),
  app_version text not null default '',
  build text not null default '',
  os_version text not null default '',
  device_model text not null default '',
  locale text not null default '',
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists gb_events_occurred on public.gb_events(occurred_at desc);
create index if not exists gb_events_user on public.gb_events(user_id, occurred_at desc);
create index if not exists gb_events_install on public.gb_events(install_id, session_id, occurred_at);
create index if not exists gb_events_name on public.gb_events(name, occurred_at desc);

-- ---------------------------------------------------------------------------------------------
-- updated_at maintenance.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['gb_profiles', 'gb_splits', 'gb_workouts', 'gb_sets', 'gb_subscriptions'] loop
    execute format('drop trigger if exists %I_touch on public.%I', t, t);
    execute format('create trigger %I_touch before update on public.%I for each row execute function public.gb_touch_updated_at()', t, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------------------------
-- Row-level security: owners only. Events: insert-only from the app.
-- ---------------------------------------------------------------------------------------------
alter table public.gb_profiles enable row level security;
alter table public.gb_splits enable row level security;
alter table public.gb_workouts enable row level security;
alter table public.gb_sets enable row level security;
alter table public.gb_devices enable row level security;
alter table public.gb_subscriptions enable row level security;
alter table public.gb_events enable row level security;

do $$
declare t text;
begin
  foreach t in array array['gb_splits', 'gb_workouts', 'gb_sets'] loop
    execute format('drop policy if exists "owner reads" on public.%I', t);
    execute format('create policy "owner reads" on public.%I for select to authenticated using (user_id = auth.uid())', t);
    execute format('drop policy if exists "owner writes" on public.%I', t);
    execute format('create policy "owner writes" on public.%I for insert to authenticated with check (user_id = auth.uid())', t);
    execute format('drop policy if exists "owner updates" on public.%I', t);
    execute format('create policy "owner updates" on public.%I for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
    execute format('drop policy if exists "owner deletes" on public.%I', t);
    execute format('create policy "owner deletes" on public.%I for delete to authenticated using (user_id = auth.uid())', t);
  end loop;
end $$;

drop policy if exists "owner reads" on public.gb_profiles;
create policy "owner reads" on public.gb_profiles for select to authenticated using (id = auth.uid());
drop policy if exists "owner writes" on public.gb_profiles;
create policy "owner writes" on public.gb_profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "owner updates" on public.gb_profiles;
create policy "owner updates" on public.gb_profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "owner reads" on public.gb_subscriptions;
create policy "owner reads" on public.gb_subscriptions for select to authenticated using (user_id = auth.uid());
drop policy if exists "owner writes" on public.gb_subscriptions;
create policy "owner writes" on public.gb_subscriptions for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "owner updates" on public.gb_subscriptions;
create policy "owner updates" on public.gb_subscriptions for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- A device row is written by the install that owns it, before or after sign-in.
revoke all on public.gb_devices from anon, authenticated;
grant insert, update on public.gb_devices to anon, authenticated;
drop policy if exists "anonymous device rows carry no account" on public.gb_devices;
create policy "anonymous device rows carry no account" on public.gb_devices for insert to anon with check (user_id is null);
drop policy if exists "anonymous device rows stay anonymous" on public.gb_devices;
create policy "anonymous device rows stay anonymous" on public.gb_devices for update to anon using (user_id is null) with check (user_id is null);
drop policy if exists "account device rows belong to the sender" on public.gb_devices;
create policy "account device rows belong to the sender" on public.gb_devices for insert to authenticated with check (user_id is null or user_id = auth.uid());
drop policy if exists "account device rows are updated by their owner" on public.gb_devices;
create policy "account device rows are updated by their owner" on public.gb_devices for update to authenticated using (user_id is null or user_id = auth.uid()) with check (user_id is null or user_id = auth.uid());

revoke all on public.gb_events from anon, authenticated;
grant insert on public.gb_events to anon, authenticated;
drop policy if exists "anonymous events have no account identity" on public.gb_events;
create policy "anonymous events have no account identity" on public.gb_events for insert to anon with check (user_id is null);
drop policy if exists "account events belong to the sender" on public.gb_events;
create policy "account events belong to the sender" on public.gb_events for insert to authenticated with check (user_id is null or user_id = auth.uid());

-- ---------------------------------------------------------------------------------------------
-- Delete account: everything, then the auth user. Called from Settings → Delete account.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_delete_account() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  delete from public.gb_sets where user_id = uid;
  delete from public.gb_workouts where user_id = uid;
  delete from public.gb_splits where user_id = uid;
  delete from public.gb_subscriptions where user_id = uid;
  delete from public.gb_profiles where id = uid;
  update public.gb_devices set user_id = null where user_id = uid;
  update public.gb_events set user_id = null where user_id = uid;
  delete from auth.users where id = uid;
end $$;
revoke all on function public.gb_delete_account() from public, anon;
grant execute on function public.gb_delete_account() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Reporting views (service role / dashboard only).
-- ---------------------------------------------------------------------------------------------
create or replace view public.gb_daily_actives with (security_invoker = false) as
  select date_trunc('day', occurred_at)::date as day,
         count(distinct install_id) as installs,
         count(distinct user_id) filter (where user_id is not null) as accounts,
         count(*) as events
  from public.gb_events group by 1 order by 1 desc;

create or replace view public.gb_onboarding_funnel with (security_invoker = false) as
  select properties->>'step' as step,
         count(distinct install_id) as installs_reached
  from public.gb_events
  where name = 'screen' and screen like 'onboarding.%'
  group by 1 order by 2 desc;

create or replace view public.gb_workout_stats with (security_invoker = false) as
  select user_id, count(*) as workouts, sum(set_count) as sets, sum(volume_kg) as volume_kg,
         sum(duration_seconds) / 60 as minutes, min(started_at) as first_workout, max(started_at) as last_workout
  from public.gb_workouts where ended_at is not null and deleted_at is null group by user_id;

revoke all on public.gb_daily_actives, public.gb_onboarding_funnel, public.gb_workout_stats from anon, authenticated;
