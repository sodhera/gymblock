-- GymBond (8 Nov 2026, docs/GYMBOND-PLAN.md): train with a friend. One invite code per account; a
-- friend who joins with it makes a bond, and both get two weeks of GymBlock Pro (a RevenueCat
-- promotional entitlement: the friend's at once, the inviter's when their current plan ends, since a
-- store subscription can't be extended). Friends see each other's first name, this week's days and
-- finished workouts, and get a push when the other finishes a workout, is about to lose a streak, or
-- nudges them. Everything is reached through the functions below; the app never writes these tables.
--
-- Needs, in the dashboard (supabase/README.md §6): the `http`, `pg_net` and `pg_cron` extensions, and
-- three Vault secrets: `revenuecat_secret_key` (sk_…), `gymbond_push_url` (the gymbond-push Edge
-- Function's URL) and `gymbond_push_key` (the shared secret the function checks). Without them the
-- bonds still form; the gifts stay pending and the pushes stay queued until they're set.
-- Repeat-safe, as the first migration.

create extension if not exists http with schema extensions;
create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ---------------------------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------------------------

-- One invite code per account, made the first time it's asked for. Six characters from an alphabet
-- with no 0/O or 1/I, so it can be read out loud.
create table if not exists public.gb_bond_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code text not null unique check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  created_at timestamptz not null default now()
);

-- A bond: the inviter whose code was used, and the friend who used it. Either can end it.
create table if not exists public.gb_bonds (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  code text not null,
  created_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by uuid,
  check (inviter_id <> friend_id)
);
create unique index if not exists gb_bonds_active_pair
  on public.gb_bonds (least(inviter_id, friend_id), greatest(inviter_id, friend_id)) where ended_at is null;
create index if not exists gb_bonds_inviter on public.gb_bonds(inviter_id) where ended_at is null;
create index if not exists gb_bonds_friend on public.gb_bonds(friend_id) where ended_at is null;

-- The gift: two weeks of Pro for each side of a bond, granted through RevenueCat when due.
create table if not exists public.gb_bond_grants (
  id uuid primary key default gen_random_uuid(),
  bond_id uuid not null references public.gb_bonds(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('inviter', 'friend')),
  due_at timestamptz not null default now(),
  granted_at timestamptz,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  unique (bond_id, user_id)
);
create index if not exists gb_bond_grants_pending on public.gb_bond_grants(due_at) where granted_at is null;

-- A nudge, one a day per direction.
create table if not exists public.gb_bond_nudges (
  id uuid primary key default gen_random_uuid(),
  bond_id uuid not null references public.gb_bonds(id) on delete cascade,
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists gb_bond_nudges_from on public.gb_bond_nudges(from_user, to_user, created_at desc);

-- Pushes to send, in the recipient's language; the gymbond-push Edge Function sends them (APNs) and
-- marks them sent. Never readable from the app.
create table if not exists public.gb_bond_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bond_id uuid references public.gb_bonds(id) on delete cascade,
  kind text not null check (kind in ('bonded', 'workout', 'streak', 'nudge')),
  title text not null check (char_length(title) <= 120),
  body text not null check (char_length(body) <= 240),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  error text
);
create index if not exists gb_bond_notifications_unsent on public.gb_bond_notifications(created_at) where sent_at is null;
create index if not exists gb_bond_notifications_user_kind on public.gb_bond_notifications(user_id, bond_id, kind, created_at desc);

-- The iPhone's push token, kept only while the account has a bond (the app registers then and clears
-- it on Log out). `apns_environment` says which APNs host to use (a Debug build is 'development').
alter table public.gb_devices add column if not exists apns_token text check (apns_token is null or apns_token ~ '^[0-9a-f]{32,200}$');
alter table public.gb_devices add column if not exists apns_environment text check (apns_environment is null or apns_environment in ('development', 'production'));
alter table public.gb_devices add column if not exists apns_updated_at timestamptz;

-- ---------------------------------------------------------------------------------------------
-- Row-level security: a party reads its own codes, bonds and grants; nothing is written directly.
-- ---------------------------------------------------------------------------------------------
alter table public.gb_bond_codes enable row level security;
alter table public.gb_bonds enable row level security;
alter table public.gb_bond_grants enable row level security;
alter table public.gb_bond_nudges enable row level security;
alter table public.gb_bond_notifications enable row level security;

drop policy if exists "owner reads" on public.gb_bond_codes;
create policy "owner reads" on public.gb_bond_codes for select to authenticated using (user_id = auth.uid());
drop policy if exists "party reads" on public.gb_bonds;
create policy "party reads" on public.gb_bonds for select to authenticated using (inviter_id = auth.uid() or friend_id = auth.uid());
drop policy if exists "owner reads" on public.gb_bond_grants;
create policy "owner reads" on public.gb_bond_grants for select to authenticated using (user_id = auth.uid());
revoke all on public.gb_bond_nudges, public.gb_bond_notifications from anon, authenticated;
revoke insert, update, delete on public.gb_bond_codes, public.gb_bonds, public.gb_bond_grants from anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------------------

-- The first name an account goes by, for the other side of a bond; "Your friend" when there's none.
create or replace function public.gb_bond_display_name(p_user uuid, p_language text default 'en') returns text
language sql stable set search_path = public as $$
  select coalesce(
    (select nullif(split_part(trim(p.name), ' ', 1), '') from public.gb_profiles p where p.id = p_user),
    case when p_language = 'es' then 'Tu amigo' else 'Your friend' end);
$$;

create or replace function public.gb_bond_language(p_user uuid) returns text
language sql stable set search_path = public as $$
  select coalesce((select language from public.gb_profiles where id = p_user), 'en');
$$;

-- The iPhone's time zone, from its latest device row; UTC when unknown.
create or replace function public.gb_bond_time_zone(p_user uuid) returns text
language sql stable set search_path = public as $$
  select coalesce((select nullif(time_zone, '') from public.gb_devices where user_id = p_user order by last_seen_at desc limit 1), 'UTC');
$$;

-- ---------------------------------------------------------------------------------------------
-- The code
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_code() returns text
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate text;
  found text;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select code into found from public.gb_bond_codes where user_id = uid;
  if found is not null then return found; end if;
  for attempt in 1..20 loop
    candidate := '';
    for i in 1..6 loop
      candidate := candidate || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    begin
      insert into public.gb_bond_codes (user_id, code) values (uid, candidate);
      return candidate;
    exception when unique_violation then
      -- Another account has this code, or this account got one meanwhile.
      select code into found from public.gb_bond_codes where user_id = uid;
      if found is not null then return found; end if;
    end;
  end loop;
  raise exception 'could not make a code';
end $$;
revoke all on function public.gb_bond_code() from public, anon;
grant execute on function public.gb_bond_code() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Joining with a code
-- ---------------------------------------------------------------------------------------------
-- Returns {status: bonded | not_found | own_code | already_bonded | limit, name, bond_id, pro_now}.
-- `pro_now` says whether the friend's two weeks were granted during the call (RevenueCat answered);
-- otherwise they land with the hourly run.
create or replace function public.gb_bond_redeem(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  clean text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  inviter uuid;
  bond uuid;
  inviter_lang text;
  my_lang text;
  inviter_due timestamptz := now();
  inviter_entitled boolean := false;
  granted boolean := false;
begin
  if uid is null then raise exception 'not signed in'; end if;
  -- Read as spoken: a 0 is an O, a 1 an I.
  clean := translate(clean, '01', 'OI');
  select user_id into inviter from public.gb_bond_codes where code = clean;
  if inviter is null then return jsonb_build_object('status', 'not_found'); end if;
  if inviter = uid then return jsonb_build_object('status', 'own_code'); end if;
  if exists (select 1 from public.gb_bonds where ended_at is null
             and least(inviter_id, friend_id) = least(inviter, uid) and greatest(inviter_id, friend_id) = greatest(inviter, uid)) then
    return jsonb_build_object('status', 'already_bonded', 'name', public.gb_bond_display_name(inviter, public.gb_bond_language(uid)));
  end if;
  if (select count(*) from public.gb_bonds where ended_at is null and (inviter_id = uid or friend_id = uid)) >= 5
     or (select count(*) from public.gb_bonds where ended_at is null and (inviter_id = inviter or friend_id = inviter)) >= 5 then
    return jsonb_build_object('status', 'limit');
  end if;

  insert into public.gb_bonds (inviter_id, friend_id, code) values (inviter, uid, clean) returning id into bond;

  -- The friend's two weeks start now. The inviter's start when their current plan ends (a store
  -- subscription can't be extended; the gift waits until it would otherwise lapse), or now if they
  -- have none.
  select entitled and coalesce(expires_at > now(), true), coalesce(expires_at, now())
    into inviter_entitled, inviter_due from public.gb_subscriptions where user_id = inviter;
  inviter_entitled := coalesce(inviter_entitled, false);
  if not inviter_entitled then inviter_due := now(); end if;
  inviter_due := coalesce(inviter_due, now());
  insert into public.gb_bond_grants (bond_id, user_id, role, due_at) values (bond, uid, 'friend', now());
  insert into public.gb_bond_grants (bond_id, user_id, role, due_at) values (bond, inviter, 'inviter', greatest(inviter_due, now()));

  -- Tell the inviter.
  inviter_lang := public.gb_bond_language(inviter);
  my_lang := public.gb_bond_language(uid);
  insert into public.gb_bond_notifications (user_id, bond_id, kind, title, body, payload) values (
    inviter, bond, 'bonded',
    case when inviter_lang = 'es' then public.gb_bond_display_name(uid, 'es') || ' se ha unido a tu GymBond'
         else public.gb_bond_display_name(uid, 'en') || ' joined your GymBond' end,
    case when inviter_entitled then
           case when inviter_lang = 'es' then 'Tus dos semanas de Pro empiezan cuando termine tu plan actual.'
                else 'Your two weeks of Pro start when your current plan ends.' end
         else
           case when inviter_lang = 'es' then 'Dos semanas de GymBlock Pro, de regalo.'
                else 'Two weeks of GymBlock Pro, on us.' end
    end,
    jsonb_build_object('bond', bond));

  -- Try the friend's grant now, so Pro is there before the price page; a miss is retried hourly.
  begin
    granted := public.gb_bond_grant(bond, uid);
  exception when others then
    granted := false;
  end;
  return jsonb_build_object('status', 'bonded', 'name', public.gb_bond_display_name(inviter, my_lang), 'bond_id', bond, 'pro_now', granted);
end $$;
revoke all on function public.gb_bond_redeem(text) from public, anon;
grant execute on function public.gb_bond_redeem(text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Ending a bond
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_end(p_bond uuid) returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  update public.gb_bonds set ended_at = now(), ended_by = uid
    where id = p_bond and ended_at is null and (inviter_id = uid or friend_id = uid);
end $$;
revoke all on function public.gb_bond_end(uuid) from public, anon;
grant execute on function public.gb_bond_end(uuid) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- A nudge: one a day in each direction. Returns {status: sent | wait | not_found}.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_nudge(p_bond uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  other uuid;
  lang text;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select case when inviter_id = uid then friend_id when friend_id = uid then inviter_id end into other
    from public.gb_bonds where id = p_bond and ended_at is null;
  if other is null then return jsonb_build_object('status', 'not_found'); end if;
  if exists (select 1 from public.gb_bond_nudges where from_user = uid and to_user = other and created_at > now() - interval '24 hours') then
    return jsonb_build_object('status', 'wait');
  end if;
  insert into public.gb_bond_nudges (bond_id, from_user, to_user) values (p_bond, uid, other);
  lang := public.gb_bond_language(other);
  insert into public.gb_bond_notifications (user_id, bond_id, kind, title, body, payload) values (
    other, p_bond, 'nudge',
    case when lang = 'es' then public.gb_bond_display_name(uid, 'es') || ' te ha dado un toque'
         else public.gb_bond_display_name(uid, 'en') || ' nudged you' end,
    case when lang = 'es' then 'Pregunta cuándo es tu próximo entrenamiento.' else 'They’re asking when your next workout is.' end,
    jsonb_build_object('bond', p_bond));
  return jsonb_build_object('status', 'sent');
end $$;
revoke all on function public.gb_bond_nudge(uuid) from public, anon;
grant execute on function public.gb_bond_nudge(uuid) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Your friends, for Profile and Home: each bond with the other side's first name, their finished
-- workouts over the last ten weeks (the app draws the week and counts the streak with its own
-- calendar), their latest workout, when you last nudged them, and your gift's state on that bond.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_friends() returns table (
  bond_id uuid, friend_id uuid, friend_name text, invited_me boolean, since timestamptz,
  workouts timestamptz[], last_workout_name text, last_workout_at timestamptz,
  nudged_at timestamptz, gift_due_at timestamptz, gift_granted_at timestamptz
)
language sql security definer stable set search_path = public as $$
  with mine as (
    select b.id, b.created_at,
           case when b.inviter_id = auth.uid() then b.friend_id else b.inviter_id end as other,
           b.inviter_id = auth.uid() as i_invited
    from public.gb_bonds b
    where b.ended_at is null and (b.inviter_id = auth.uid() or b.friend_id = auth.uid())
  )
  select m.id, m.other,
         public.gb_bond_display_name(m.other, public.gb_bond_language(auth.uid())),
         not m.i_invited,
         m.created_at,
         coalesce((select array_agg(w.ended_at order by w.ended_at) from public.gb_workouts w
                   where w.user_id = m.other and w.ended_at is not null and w.deleted_at is null and w.set_count > 0
                     and w.ended_at > now() - interval '70 days'), '{}'::timestamptz[]),
         (select w.name from public.gb_workouts w where w.user_id = m.other and w.ended_at is not null and w.deleted_at is null and w.set_count > 0
            order by w.ended_at desc limit 1),
         (select w.ended_at from public.gb_workouts w where w.user_id = m.other and w.ended_at is not null and w.deleted_at is null and w.set_count > 0
            order by w.ended_at desc limit 1),
         (select n.created_at from public.gb_bond_nudges n where n.from_user = auth.uid() and n.to_user = m.other order by n.created_at desc limit 1),
         (select g.due_at from public.gb_bond_grants g where g.bond_id = m.id and g.user_id = auth.uid()),
         (select g.granted_at from public.gb_bond_grants g where g.bond_id = m.id and g.user_id = auth.uid())
  from mine m
  order by m.created_at;
$$;
revoke all on function public.gb_bond_friends() from public, anon;
grant execute on function public.gb_bond_friends() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- The gift, through RevenueCat's promotional entitlements (REST v1, the secret key from the Vault).
-- Only the server holds the key; the app never grants anything.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_grant(p_bond uuid, p_user uuid) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare
  secret text;
  response record;
  due timestamptz;
  granted timestamptz;
  entitled_until timestamptz;
begin
  select g.due_at, g.granted_at into due, granted from public.gb_bond_grants g where g.bond_id = p_bond and g.user_id = p_user;
  if due is null then return false; end if;
  if granted is not null then return true; end if;
  if due > now() then return false; end if;
  -- Still on a plan (the inviter's case): the gift waits for the plan to end, then runs for two weeks.
  select expires_at into entitled_until from public.gb_subscriptions where user_id = p_user and entitled and expires_at > now();
  if entitled_until is not null then
    update public.gb_bond_grants set due_at = entitled_until where bond_id = p_bond and user_id = p_user;
    return false;
  end if;
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'revenuecat_secret_key' limit 1;
  if secret is null then
    update public.gb_bond_grants set attempts = attempts + 1, last_error = 'no revenuecat_secret_key in the Vault'
      where bond_id = p_bond and user_id = p_user;
    return false;
  end if;
  -- The app signs in to RevenueCat as the lowercased account id (GymSubscription.identify).
  select status, content::text as body into response from extensions.http((
    'POST',
    'https://api.revenuecat.com/v1/subscribers/' || lower(p_user::text) || '/entitlements/pro/promotional',
    array[extensions.http_header('Authorization', 'Bearer ' || secret), extensions.http_header('Content-Type', 'application/json')],
    'application/json',
    '{"duration": "two_week"}'
  )::extensions.http_request);
  if response.status between 200 and 299 then
    update public.gb_bond_grants set granted_at = now(), attempts = attempts + 1, last_error = null where bond_id = p_bond and user_id = p_user;
    return true;
  end if;
  update public.gb_bond_grants set attempts = attempts + 1, last_error = left('HTTP ' || response.status || ' ' || coalesce(response.body, ''), 300)
    where bond_id = p_bond and user_id = p_user;
  return false;
end $$;
revoke all on function public.gb_bond_grant(uuid, uuid) from public, anon, authenticated;

-- Every gift that is due and not yet granted, retried until it lands (at most once an hour, from cron).
create or replace function public.gb_bond_process_grants() returns integer
language plpgsql security definer set search_path = public as $$
declare g record; n integer := 0;
begin
  for g in select bond_id, user_id from public.gb_bond_grants where granted_at is null and due_at <= now() and attempts < 200 loop
    begin
      if public.gb_bond_grant(g.bond_id, g.user_id) then n := n + 1; end if;
    exception when others then
      update public.gb_bond_grants set attempts = attempts + 1, last_error = left(sqlerrm, 300) where bond_id = g.bond_id and user_id = g.user_id;
    end;
  end loop;
  return n;
end $$;
revoke all on function public.gb_bond_process_grants() from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- A friend finished a workout: the other side hears. From the app's own upsert of the workout row
-- (CloudSync), so a workout finished offline reaches them when the iPhone next syncs, and never twice.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_workout_finished() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  b record;
  lang text;
  who text;
  minutes integer;
begin
  if new.ended_at is null or new.deleted_at is not null or coalesce(new.set_count, 0) = 0 then return new; end if;
  if tg_op = 'UPDATE' and old.ended_at is not null then return new; end if;
  -- A backlog synced days later isn't news.
  if new.ended_at < now() - interval '6 hours' then return new; end if;
  minutes := greatest(1, round(coalesce(new.duration_seconds, 0) / 60.0))::int;
  for b in select id, case when inviter_id = new.user_id then friend_id else inviter_id end as other
           from public.gb_bonds where ended_at is null and (inviter_id = new.user_id or friend_id = new.user_id) loop
    if exists (select 1 from public.gb_bond_notifications where user_id = b.other and kind = 'workout' and payload->>'workout' = new.id::text) then
      continue;
    end if;
    lang := public.gb_bond_language(b.other);
    who := public.gb_bond_display_name(new.user_id, lang);
    insert into public.gb_bond_notifications (user_id, bond_id, kind, title, body, payload) values (
      b.other, b.id, 'workout',
      case when lang = 'es' then who || ' acaba de terminar ' || coalesce(nullif(new.name, ''), 'un entrenamiento')
           else who || ' just finished ' || coalesce(nullif(new.name, ''), 'a workout') end,
      case when lang = 'es' then minutes || ' min · ' || new.set_count || ' series. Te toca.'
           else minutes || ' min · ' || new.set_count || ' sets. Your move.' end,
      jsonb_build_object('bond', b.id, 'workout', new.id));
  end loop;
  return new;
end $$;
drop trigger if exists gb_bond_workout_finished on public.gb_workouts;
create trigger gb_bond_workout_finished after insert or update on public.gb_workouts
  for each row execute function public.gb_bond_workout_finished();

-- ---------------------------------------------------------------------------------------------
-- A streak about to go: Sunday at 4 pm in the friend's own time zone, nothing logged this week after
-- a week that had something, the other side hears once. Run hourly.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_streak_check() returns integer
language plpgsql security definer set search_path = public as $$
declare
  r record;
  tz text;
  local_now timestamp;
  week_start timestamp;
  lang text;
  who text;
  n integer := 0;
begin
  for r in
    select b.id, b.inviter_id as watcher, b.friend_id as friend from public.gb_bonds b where b.ended_at is null
    union all
    select b.id, b.friend_id, b.inviter_id from public.gb_bonds b where b.ended_at is null
  loop
    tz := public.gb_bond_time_zone(r.friend);
    begin
      local_now := now() at time zone tz;
    exception when others then
      local_now := now() at time zone 'UTC';
      tz := 'UTC';
    end;
    if extract(isodow from local_now) <> 7 or extract(hour from local_now) <> 16 then continue; end if;
    week_start := date_trunc('week', local_now);
    -- Nothing this week, something the week before.
    if exists (select 1 from public.gb_workouts w where w.user_id = r.friend and w.ended_at is not null and w.deleted_at is null and w.set_count > 0
               and (w.ended_at at time zone tz) >= week_start) then continue; end if;
    if not exists (select 1 from public.gb_workouts w where w.user_id = r.friend and w.ended_at is not null and w.deleted_at is null and w.set_count > 0
                   and (w.ended_at at time zone tz) >= week_start - interval '7 days' and (w.ended_at at time zone tz) < week_start) then continue; end if;
    if exists (select 1 from public.gb_bond_notifications x where x.user_id = r.watcher and x.bond_id = r.id and x.kind = 'streak'
               and x.created_at >= (week_start at time zone tz)) then continue; end if;
    lang := public.gb_bond_language(r.watcher);
    who := public.gb_bond_display_name(r.friend, lang);
    insert into public.gb_bond_notifications (user_id, bond_id, kind, title, body, payload) values (
      r.watcher, r.id, 'streak',
      case when lang = 'es' then who || ' no ha entrenado esta semana' else who || ' hasn’t trained this week' end,
      case when lang = 'es' then 'Un entrenamiento hoy mantiene su racha. Dale un toque.' else 'One workout today keeps their streak. Send a nudge.' end,
      jsonb_build_object('bond', r.id, 'friend', r.friend));
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.gb_bond_streak_check() from public, anon, authenticated;

-- The hourly run: streaks, then gifts that have come due.
create or replace function public.gb_bond_hourly() returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.gb_bond_streak_check();
  perform public.gb_bond_process_grants();
end $$;
revoke all on function public.gb_bond_hourly() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'gymbond-hourly') then perform cron.unschedule('gymbond-hourly'); end if;
  perform cron.schedule('gymbond-hourly', '5 * * * *', 'select public.gb_bond_hourly()');
end $$;

-- ---------------------------------------------------------------------------------------------
-- Sending: each queued push asks the gymbond-push Edge Function to send it (pg_net, so the insert
-- never waits). The function's URL and its shared secret come from the Vault; with neither set the
-- rows wait, and the function drains them whenever it's next called.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_bond_push_trigger() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare v_url text; v_key text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'gymbond_push_url' limit 1;
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'gymbond_push_key' limit 1;
  if v_url is null or v_key is null then return new; end if;
  begin
    perform net.http_post(
      url := v_url,
      body := jsonb_build_object('id', new.id),
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || v_key),
      timeout_milliseconds := 8000);
  exception when others then
    null;
  end;
  return new;
end $$;
drop trigger if exists gb_bond_notifications_push on public.gb_bond_notifications;
create trigger gb_bond_notifications_push after insert on public.gb_bond_notifications
  for each row execute function public.gb_bond_push_trigger();

-- ---------------------------------------------------------------------------------------------
-- Delete account: the bonds go too (the other side's row simply ends), and the push token.
-- ---------------------------------------------------------------------------------------------
create or replace function public.gb_delete_account() returns void
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  delete from public.gb_bond_notifications where user_id = uid;
  delete from public.gb_bond_nudges where from_user = uid or to_user = uid;
  delete from public.gb_bond_grants where user_id = uid;
  delete from public.gb_bonds where inviter_id = uid or friend_id = uid;
  delete from public.gb_bond_codes where user_id = uid;
  delete from public.gb_sets where user_id = uid;
  delete from public.gb_workouts where user_id = uid;
  delete from public.gb_splits where user_id = uid;
  delete from public.gb_subscriptions where user_id = uid;
  delete from public.gb_profiles where id = uid;
  update public.gb_devices set user_id = null, apns_token = null, apns_environment = null where user_id = uid;
  update public.gb_events set user_id = null where user_id = uid;
  delete from auth.users where id = uid;
end $$;
revoke all on function public.gb_delete_account() from public, anon;
grant execute on function public.gb_delete_account() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Reporting (service role / dashboard only).
-- ---------------------------------------------------------------------------------------------
create or replace view public.gb_bond_summary with (security_invoker = false) as
  select
    (select count(*) from public.gb_bond_codes) as codes,
    (select count(*) from public.gb_bonds) as bonds,
    (select count(*) from public.gb_bonds where ended_at is null) as active_bonds,
    (select count(*) from public.gb_bond_grants where granted_at is not null) as gifts_granted,
    (select count(*) from public.gb_bond_grants where granted_at is null) as gifts_pending,
    (select count(*) from public.gb_bond_notifications where sent_at is not null) as pushes_sent,
    (select count(*) from public.gb_bond_notifications where sent_at is null) as pushes_waiting,
    (select count(*) from public.gb_bond_nudges) as nudges;
revoke all on public.gb_bond_summary from anon, authenticated;
