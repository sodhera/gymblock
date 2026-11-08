-- A message to one account from the server (8 Nov 2026, at the user's request): queued like a
-- GymBond push and sent by the same trigger and Edge Function. Run from the SQL editor, service
-- role only (never from the app):
--   select public.gb_notify('<user id>', 'Title', 'Body');
-- The app keeps a push token for every signed-in install that allowed notifications, so the
-- recipient needs an account, notifications on, and a launch of a build with this to have one.

alter table public.gb_bond_notifications drop constraint if exists gb_bond_notifications_kind_check;
alter table public.gb_bond_notifications add constraint gb_bond_notifications_kind_check
  check (kind in ('bonded', 'workout', 'streak', 'nudge', 'manual'));

create or replace function public.gb_notify(p_user uuid, p_title text, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  if not exists (select 1 from auth.users u where u.id = p_user) then raise exception 'no such user'; end if;
  insert into public.gb_bond_notifications (user_id, kind, title, body, payload)
    values (p_user, 'manual', left(p_title, 120), left(p_body, 240), '{}'::jsonb) returning id into new_id;
  return new_id;
end $$;
revoke all on function public.gb_notify(uuid, text, text) from public, anon, authenticated;
