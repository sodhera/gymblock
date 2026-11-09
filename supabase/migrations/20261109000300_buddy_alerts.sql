-- How often a friend's finished workout reaches you (9 Nov 2026, at the user's request): every
-- one, rarely (a random third of them), or never. Kept on the profile, set from the app's
-- GymBuddy page and Settings (CloudSync's profile upsert), and read by the trigger that queues
-- the 'workout' push, so the choice is honoured before anything is sent.

alter table public.gb_profiles add column if not exists buddy_alerts text not null default 'every'
  check (buddy_alerts in ('every', 'rarely', 'none'));

create or replace function public.gb_bond_workout_finished() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  b record;
  lang text;
  who text;
  minutes integer;
  wants text;
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
    -- The other side's choice: none hears nothing; rarely hears about one workout in three.
    wants := coalesce((select buddy_alerts from public.gb_profiles where id = b.other), 'every');
    if wants = 'none' then continue; end if;
    if wants = 'rarely' and random() >= 1.0 / 3 then continue; end if;
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
