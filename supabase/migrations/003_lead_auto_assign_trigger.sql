-- Moves assignment-rule matching from the app layer (admin site) and Apps
-- Script into the database itself, as a trigger on leads. Every insert path
-- (Google Form sync, admin Add Lead, bulk import, any future integration)
-- goes through this same trigger, so there's exactly one place that
-- implements the rule — no risk of Apps Script drifting out of sync with
-- the admin site's logic again.
--
-- Behavior: only fills assigned_to when the inserting caller left it NULL —
-- an explicit assignment always wins. Matches a source+campaign rule first,
-- falls back to a source-only rule (campaign IS NULL). When a rule's pool
-- has more than one person, picks whoever currently has the fewest total
-- assigned leads (round robin).
create or replace function public.assign_new_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  rule_assignees uuid[];
  pool_size integer;
  best_id uuid;
  best_count integer;
  candidate_id uuid;
  candidate_count integer;
begin
  if new.assigned_to is not null then
    return new;
  end if;

  rule_assignees := null;

  if new.campaign is not null then
    select assignee_ids into rule_assignees
    from public.assignment_rules
    where source = new.source and campaign = new.campaign and is_active = true
    limit 1;
  end if;

  if rule_assignees is null then
    select assignee_ids into rule_assignees
    from public.assignment_rules
    where source = new.source and campaign is null and is_active = true
    limit 1;
  end if;

  if rule_assignees is null then
    return new;
  end if;

  pool_size := array_length(rule_assignees, 1);
  if pool_size is null or pool_size = 0 then
    return new;
  end if;

  if pool_size = 1 then
    new.assigned_to := rule_assignees[1];
    return new;
  end if;

  best_id := null;
  best_count := null;
  foreach candidate_id in array rule_assignees loop
    select count(*) into candidate_count from public.leads where assigned_to = candidate_id;
    if best_count is null or candidate_count < best_count then
      best_count := candidate_count;
      best_id := candidate_id;
    end if;
  end loop;

  new.assigned_to := best_id;
  return new;
end;
$$;

drop trigger if exists assign_new_lead_trigger on public.leads;
create trigger assign_new_lead_trigger
  before insert on public.leads
  for each row
  execute function public.assign_new_lead();
