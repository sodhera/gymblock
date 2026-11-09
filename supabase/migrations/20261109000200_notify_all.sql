-- A message to every account from the server (9 Nov 2026, at the user's request): one 'manual'
-- push per reachable account, queued like gb_notify's and sent by the same trigger and Edge
-- Function. Reachable: a signed-in install with a push token. Run from the SQL editor, service
-- role only (never from the app):
--   select public.gb_notify_all('Title', 'Body');
-- It returns how many accounts were queued. The same title and body are never queued twice for
-- an account (a second run after a partial send only reaches the accounts the first one missed),
-- so a repeat needs new words. Test on one account with gb_notify first.

create or replace function public.gb_notify_all(p_title text, p_body text) returns integer
language plpgsql security definer set search_path = public as $$
declare queued integer;
begin
  if coalesce(btrim(p_title), '') = '' or coalesce(btrim(p_body), '') = '' then
    raise exception 'title and body are required';
  end if;
  insert into public.gb_bond_notifications (user_id, kind, title, body, payload)
    select d.user_id, 'manual', left(p_title, 120), left(p_body, 240), '{}'::jsonb
    from public.gb_devices d
    join auth.users u on u.id = d.user_id
    where d.apns_token is not null
    group by d.user_id
    having not exists (
      select 1 from public.gb_bond_notifications n
      where n.user_id = d.user_id and n.kind = 'manual'
        and n.title = left(p_title, 120) and n.body = left(p_body, 240)
    );
  get diagnostics queued = row_count;
  return queued;
end $$;
revoke all on function public.gb_notify_all(text, text) from public, anon, authenticated;
