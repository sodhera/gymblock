-- Onboarding funnel views over gb_events (11 Oct 2026), for the SQL editor and Table editor
-- (service role only, like the views in the first migration). Debug builds that reach the
-- server mark their events properties.debug = true; these views leave them out.

-- Replaces the first migration's funnel (step, installs_reached) with one in page order.
drop view if exists public.gb_onboarding_funnel;

-- How many installs reached each onboarding page, in page order.
create or replace view public.gb_onboarding_funnel with (security_invoker = false) as
with pages as (
  select install_id, screen, min(occurred_at) as first_seen
  from public.gb_events
  where name = 'screen' and screen like 'onboarding.%' and coalesce((properties->>'debug')::boolean, false) = false
  group by install_id, screen
), steps as (
  select screen, min((e.properties->>'step')::int) as step_index
  from public.gb_events e
  where name = 'screen' and screen like 'onboarding.%'
  group by screen
)
select s.step_index, p.screen, count(distinct p.install_id) as installs
from pages p join steps s using (screen)
group by s.step_index, p.screen
order by s.step_index;

-- Median and 90th-percentile time on each page (forward and back moves both count).
create or replace view public.gb_onboarding_dwell with (security_invoker = false) as
select properties->>'from' as page,
       count(*) as moves,
       percentile_cont(0.5) within group (order by (properties->>'dwell_ms')::int) / 1000.0 as median_seconds,
       percentile_cont(0.9) within group (order by (properties->>'dwell_ms')::int) / 1000.0 as p90_seconds,
       count(*) filter (where properties->>'direction' = 'back') as back_moves
from public.gb_events
where name = 'onboarding_step' and coalesce((properties->>'debug')::boolean, false) = false
group by 1;

-- What people answer, per question.
create or replace view public.gb_onboarding_answers with (security_invoker = false) as
select properties->>'question' as question,
       coalesce(properties->>'value', properties->>'minutes_per_rest', properties->>'cm_band', properties->>'kg_band',
                properties->>'phone_minutes', properties->>'answered') as answer,
       count(distinct install_id) as installs
from public.gb_events
where name = 'onboarding_answer' and coalesce((properties->>'debug')::boolean, false) = false
group by 1, 2
order by 1, 3 desc;

-- Started vs completed, and how the decisions on the way went.
create or replace view public.gb_onboarding_summary with (security_invoker = false) as
select
  count(distinct install_id) filter (where name = 'onboarding_started') as started,
  count(distinct install_id) filter (where name = 'onboarding_completed') as completed,
  count(distinct install_id) filter (where name = 'onboarding_blocking' and properties->>'choice' = 'on') as blocking_on,
  count(distinct install_id) filter (where name = 'onboarding_blocking' and properties->>'choice' = 'later') as blocking_later,
  count(distinct install_id) filter (where name = 'onboarding_alerts' and (properties->>'granted')::boolean) as alerts_granted,
  count(distinct install_id) filter (where name = 'onboarding_committed') as committed,
  count(distinct install_id) filter (where name = 'onboarding_completed' and (properties->>'subscribed')::boolean) as completed_subscribed,
  percentile_cont(0.5) within group (order by (properties->>'total_ms')::bigint)
    filter (where name = 'onboarding_completed') / 60000.0 as median_minutes_to_complete
from public.gb_events
where name like 'onboarding_%' and coalesce((properties->>'debug')::boolean, false) = false;

revoke all on public.gb_onboarding_funnel, public.gb_onboarding_dwell, public.gb_onboarding_answers,
  public.gb_onboarding_summary from anon, authenticated;
