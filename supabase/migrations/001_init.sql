-- GymBlock schema v1: public profiles, friendships, workout summaries,
-- opt-in workout details, and personal records.
--
-- Privacy model (see DESIGN.md → "Friends"):
--   * Anyone signed in can look up a profile by username (to add a friend).
--   * Only accepted friends can read each other's workout *summaries* (date,
--     duration, sets, volume) and PRs — that's what streak/consistency need.
--   * Workout *details* (exercises, sets, notes) are readable by friends only
--     when the owner marked that workout shared.

create extension if not exists citext;

-- Profiles ------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username citext unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null default '' check (char_length(display_name) <= 40),
  weekly_target smallint not null default 4 check (weekly_target between 1 and 7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles readable by signed-in users"
  on public.profiles for select to authenticated using (true);
create policy "insert own profile"
  on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "update own profile"
  on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Friendships ---------------------------------------------------------------

create table public.friendships (
  requester uuid not null references public.profiles on delete cascade,
  addressee uuid not null references public.profiles on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

-- One friendship per pair regardless of direction.
create unique index friendships_pair on public.friendships
  (least(requester, addressee), greatest(requester, addressee));

alter table public.friendships enable row level security;

create policy "see own friendships"
  on public.friendships for select to authenticated
  using (auth.uid() in (requester, addressee));
create policy "send requests as yourself"
  on public.friendships for insert to authenticated
  with check (requester = auth.uid() and status = 'pending');
create policy "addressee accepts"
  on public.friendships for update to authenticated
  using (addressee = auth.uid()) with check (addressee = auth.uid() and status = 'accepted');
create policy "either side removes"
  on public.friendships for delete to authenticated
  using (auth.uid() in (requester, addressee));

create or replace function public.are_friends(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and ((requester = a and addressee = b) or (requester = b and addressee = a))
  );
$$;

-- Workouts (summary) --------------------------------------------------------

create table public.workouts (
  id uuid primary key,
  user_id uuid not null references public.profiles on delete cascade,
  title text not null check (char_length(title) <= 60),
  started_at timestamptz not null,
  ended_at timestamptz not null,
  set_count int not null default 0,
  volume_kg double precision not null default 0,
  counts boolean not null default true,
  is_shared boolean not null default false,
  updated_at timestamptz not null default now()
);

create index workouts_user_started on public.workouts (user_id, started_at desc);

alter table public.workouts enable row level security;

create policy "own workouts" on public.workouts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "friends read summaries" on public.workouts for select to authenticated
  using (public.are_friends(auth.uid(), user_id));

-- Workout details (opt-in) --------------------------------------------------

create table public.workout_details (
  workout_id uuid primary key references public.workouts on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  exercises jsonb not null default '[]',
  note text not null default ''
);

alter table public.workout_details enable row level security;

create policy "own details" on public.workout_details for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "friends read shared details" on public.workout_details for select to authenticated
  using (
    public.are_friends(auth.uid(), user_id)
    and exists (select 1 from public.workouts w where w.id = workout_id and w.is_shared)
  );

-- Personal records ----------------------------------------------------------

create table public.personal_records (
  user_id uuid not null references public.profiles on delete cascade,
  exercise_id text not null,
  exercise_name text not null,
  weight_kg double precision not null,
  reps int not null,
  e1rm_kg double precision not null,
  achieved_at timestamptz not null,
  primary key (user_id, exercise_id)
);

alter table public.personal_records enable row level security;

create policy "own records" on public.personal_records for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "friends read records" on public.personal_records for select to authenticated
  using (public.are_friends(auth.uid(), user_id));

-- Nudges ("your week's empty — go lift") -----------------------------------

create table public.nudges (
  id bigint generated always as identity primary key,
  sender uuid not null references public.profiles on delete cascade,
  recipient uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.nudges enable row level security;

create policy "friends nudge friends" on public.nudges for insert to authenticated
  with check (sender = auth.uid() and public.are_friends(sender, recipient));
create policy "see own nudges" on public.nudges for select to authenticated
  using (auth.uid() in (sender, recipient));
