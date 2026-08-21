-- ============================================================
-- Mortar CRM — Assignment Rules (route leads by source/campaign)
-- Run this in Supabase SQL Editor
-- ============================================================

-- ─── Leads: track which campaign a lead came from ─────────────────────────
-- Nullable — only populated when the source system reports it (e.g. Meta
-- Lead Ads campaign_id, once that integration is live). Leads without a
-- campaign only match source-only rules.
alter table public.leads add column if not exists campaign text;

-- ─── Assignment Rules ───────────────────────────────────────────────────────
-- A rule matches leads by `source` (required) and optionally `campaign`
-- (more specific — a source+campaign rule wins over a source-only rule for
-- the same source). `assignee_ids` is a small pool of telecallers to round-
-- robin between: whoever currently has the fewest total assigned leads
-- among the pool gets the next one.
create table public.assignment_rules (
  id            uuid default uuid_generate_v4() primary key,
  source        text not null check (source in ('facebook','instagram','website','phone','whatsapp','referral')),
  campaign      text,
  assignee_ids  uuid[] not null,
  is_active     boolean default true,
  created_at    timestamptz default now()
);

-- A given (source, campaign) pair should only have one active rule — avoids
-- ambiguity about which rule wins. NULLS are NOT distinct here so a second
-- source-only rule (campaign IS NULL) for the same source is also blocked.
create unique index assignment_rules_source_campaign_key
  on public.assignment_rules (source, coalesce(campaign, ''));

alter table public.assignment_rules enable row level security;

create policy "assignment_rules_manager_all" on public.assignment_rules for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('manager', 'admin')
    )
  )
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('manager', 'admin')
    )
  );
