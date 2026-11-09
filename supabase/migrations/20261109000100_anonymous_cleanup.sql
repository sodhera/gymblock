-- Stale silent accounts (9 Nov 2026). Every person who reaches the commit page gets an anonymous
-- account (Account.signInAnonymously); most never buy. Weekly, the ones that haven't signed in for
-- 30 days and have no finished workout are deleted with everything they own (the cascades from
-- auth.users; events and devices lose the id but stay, as gb_delete_account does). A silent account
-- still in use signs in at every launch, so it's never 30 days old; and if one were deleted, the
-- iPhone keeps its copy and quietly makes a new silent account.

create or replace function public.gb_delete_stale_anonymous() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer := 0; r record;
begin
  for r in
    select u.id from auth.users u
    where u.is_anonymous
      and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '30 days'
      and not exists (select 1 from public.gb_workouts w where w.user_id = u.id and w.ended_at is not null and w.set_count > 0)
  loop
    delete from public.gb_bond_notifications where user_id = r.id;
    delete from public.gb_bond_nudges where from_user = r.id or to_user = r.id;
    delete from public.gb_bond_grants where user_id = r.id;
    delete from public.gb_bonds where inviter_id = r.id or friend_id = r.id;
    delete from public.gb_bond_codes where user_id = r.id;
    delete from public.gb_sets where user_id = r.id;
    delete from public.gb_workouts where user_id = r.id;
    delete from public.gb_splits where user_id = r.id;
    delete from public.gb_subscriptions where user_id = r.id;
    delete from public.gb_profiles where id = r.id;
    update public.gb_devices set user_id = null, apns_token = null, apns_environment = null where user_id = r.id;
    update public.gb_events set user_id = null where user_id = r.id;
    delete from auth.users where id = r.id;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.gb_delete_stale_anonymous() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'gymblock-anonymous-cleanup') then perform cron.unschedule('gymblock-anonymous-cleanup'); end if;
  -- Mondays at 03:10 UTC.
  perform cron.schedule('gymblock-anonymous-cleanup', '10 3 * * 1', 'select public.gb_delete_stale_anonymous()');
end $$;
