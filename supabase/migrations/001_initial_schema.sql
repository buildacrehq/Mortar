-- ============================================================
-- Buildacre CRM — Initial Schema
-- Run this in Supabase SQL Editor
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ─── PROFILES (extends Supabase auth.users) ─────────────────
create table public.profiles (
  id          uuid references auth.users(id) on delete cascade primary key,
  name        text not null,
  email       text not null unique,
  role        text not null check (role in ('telecaller', 'manager', 'admin')),
  city        text check (city in ('bangalore', 'mysore')),
  phone       text,
  is_active   boolean default true,
  created_at  timestamptz default now()
);

-- ─── LEADS ──────────────────────────────────────────────────
create table public.leads (
  id              uuid default uuid_generate_v4() primary key,
  name            text not null,
  phone           text not null,
  email           text,
  source          text not null check (source in ('facebook','instagram','website','phone','whatsapp','referral')),
  service_type    text not null check (service_type in ('construction','renovation','interiors')),
  city            text not null check (city in ('bangalore','mysore')),
  stage           text not null default 'enquiryReceived' check (stage in (
                    'enquiryReceived','telecallerCallDone','meetingAtOffice',
                    'siteVisit','quotationSent','negotiation','finalAgreement',
                    'lost','future'
                  )),
  area            text,
  plot_size       text,
  budget          text,
  notes           text,
  assigned_to     uuid references public.profiles(id),
  last_outcome    text check (last_outcome in ('interested','notInterested','callback','notReachable','future')),
  followup_at     timestamptz,
  future_tag      text check (future_tag in ('hot','warm','cool','longTerm')),
  lost_reason     text check (lost_reason in (
                    'priceTooHigh','wentWithCompetitor','nobudget',
                    'projectOnHold','notInterested','noResponse','invalidLead','other'
                  )),
  last_contacted_at timestamptz,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- ─── CALL LOGS ───────────────────────────────────────────────
create table public.call_logs (
  id                uuid default uuid_generate_v4() primary key,
  lead_id           uuid references public.leads(id) on delete cascade not null,
  called_by         uuid references public.profiles(id),
  called_at         timestamptz default now(),
  duration_seconds  integer default 0,
  outcome           text not null check (outcome in ('interested','notInterested','callback','notReachable','future')),
  notes             text,
  recording_url     text,
  exotel_call_sid   text,
  created_at        timestamptz default now()
);

-- ─── LEAD NOTES (internal) ──────────────────────────────────
create table public.lead_notes (
  id          uuid default uuid_generate_v4() primary key,
  lead_id     uuid references public.leads(id) on delete cascade not null,
  author_id   uuid references public.profiles(id),
  author_name text not null,
  text        text not null,
  created_at  timestamptz default now()
);

-- ─── UPDATED_AT TRIGGER ──────────────────────────────────────
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger leads_updated_at
  before update on public.leads
  for each row execute function update_updated_at();

-- ─── ROW LEVEL SECURITY ──────────────────────────────────────
alter table public.profiles  enable row level security;
alter table public.leads     enable row level security;
alter table public.call_logs enable row level security;
alter table public.lead_notes enable row level security;

-- Profiles: users can read all, update only their own
create policy "profiles_read_all"   on public.profiles for select using (true);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- Leads: telecallers see only their leads; managers/admins see all
create policy "leads_manager_all" on public.leads for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('manager', 'admin')
    )
  );

create policy "leads_telecaller_own" on public.leads for all
  using (assigned_to = auth.uid());

-- Call logs: telecallers see logs for their leads; managers see all
create policy "calllogs_manager_all" on public.call_logs for all
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('manager', 'admin')
    )
  );

create policy "calllogs_telecaller_own" on public.call_logs for all
  using (
    exists (
      select 1 from public.leads
      where id = lead_id and assigned_to = auth.uid()
    )
  );

-- Lead notes: all authenticated users can read/write notes on their leads
create policy "lead_notes_all" on public.lead_notes for all
  using (auth.uid() is not null);

-- ─── SEED: Create profiles for the team ──────────────────────
-- Run AFTER creating users in Supabase Auth dashboard
-- Replace UUIDs with actual auth.users IDs after creating them

-- Example (update UUIDs after creating users):
-- insert into public.profiles (id, name, email, role, city) values
--   ('<harsha-uuid>',  'Harsha',       'harsha@buildacre.in',  'manager',    'bangalore'),
--   ('<ravi-uuid>',    'Ravi Kumar',   'ravi@buildacre.in',    'telecaller', 'bangalore'),
--   ('<sneha-uuid>',   'Sneha Rao',    'sneha@buildacre.in',   'telecaller', 'bangalore'),
--   ('<arun-uuid>',    'Arun Shetty',  'arun@buildacre.in',    'telecaller', 'mysore'),
--   ('<divya-uuid>',   'Divya Nair',   'divya@buildacre.in',   'telecaller', 'bangalore'),
--   ('<kiran-uuid>',   'Kiran Hegde',  'kiran@buildacre.in',   'telecaller', 'mysore');
