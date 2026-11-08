-- Device rows through functions (8 Nov 2026). The app may write its own device row but never read
-- the table, and an upsert needs to read the row it would update, so every registration since
-- October had failed with "permission denied" and gb_devices stayed empty. Now the app calls these
-- two (security definer) and keeps no table rights at all.

revoke all on public.gb_devices from anon, authenticated;

-- Every launch and every sign-in/out: the install's row, with the account when there is one. Signed
-- out, the row keeps the account it had (as the old policy did); the push token is cleared separately.
create or replace function public.gb_register_device(
  p_install uuid, p_model text, p_os_version text, p_app_version text, p_build text,
  p_locale text, p_time_zone text, p_notifications text, p_reduce_motion boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_install is null then raise exception 'no install id'; end if;
  insert into public.gb_devices (install_id, user_id, model, os_version, app_version, build, locale, time_zone, notifications, reduce_motion, last_seen_at)
  values (p_install, auth.uid(), left(coalesce(p_model, ''), 60), left(coalesce(p_os_version, ''), 30), left(coalesce(p_app_version, ''), 30),
          left(coalesce(p_build, ''), 30), left(coalesce(p_locale, ''), 20), left(coalesce(p_time_zone, ''), 60),
          case when p_notifications in ('authorized', 'denied', 'not_determined') then p_notifications end, p_reduce_motion, now())
  on conflict (install_id) do update set
    user_id = coalesce(auth.uid(), gb_devices.user_id),
    model = excluded.model, os_version = excluded.os_version, app_version = excluded.app_version, build = excluded.build,
    locale = excluded.locale, time_zone = excluded.time_zone, notifications = excluded.notifications,
    reduce_motion = excluded.reduce_motion, last_seen_at = now();
end $$;
revoke all on function public.gb_register_device(uuid, text, text, text, text, text, text, text, boolean) from public;
grant execute on function public.gb_register_device(uuid, text, text, text, text, text, text, text, boolean) to anon, authenticated;

-- The push token for a signed-in install (null clears it, before Log out).
create or replace function public.gb_set_push_token(p_install uuid, p_token text, p_environment text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_install is null then raise exception 'no install id'; end if;
  insert into public.gb_devices (install_id, user_id, apns_token, apns_environment, apns_updated_at)
  values (p_install, auth.uid(), p_token, case when p_token is null then null else p_environment end, now())
  on conflict (install_id) do update set
    user_id = auth.uid(), apns_token = excluded.apns_token, apns_environment = excluded.apns_environment, apns_updated_at = now();
end $$;
revoke all on function public.gb_set_push_token(uuid, text, text) from public, anon;
grant execute on function public.gb_set_push_token(uuid, text, text) to authenticated;
