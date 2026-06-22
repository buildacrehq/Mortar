# Mortar — Construction CRM

Custom CRM built for **Buildacre**, a turnkey residential construction company operating in Bangalore and Mysore. Replaces WhatsApp groups and spreadsheets with a structured lead pipeline for 5 telecallers and a management team.

---

## Business Context

- **Company:** Buildacre — full turnkey construction, renovation, and interiors
- **Cities:** Bangalore + Mysore
- **Team:** 5 telecallers + manager + admin
- **Volume:** ~250 calls/day, leads from Facebook/Instagram ads + inbound calls
- **Problem solved:** Leads were tracked in Google Sheets, follow-ups missed, no call recording, no performance visibility

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter 3.44 (Android + iOS) |
| Database | Supabase (PostgreSQL) |
| Auth | Supabase Auth |
| Real-time | Supabase Realtime |
| Backend | Node.js + Express (in `/backend`) |
| Hosting | Vercel (backend) |
| Telephony | Exotel — click-to-call, IVR, recording (Phase 2) |
| Lead capture | Meta Lead Ads webhook + Google Sheets bridge (Phase 2) |
| Notifications | Firebase Cloud Messaging (Phase 2) |

---

## Project Structure

```
buildacre_crm/
├── lib/
│   ├── app.dart                          # App root with auth splash
│   ├── main.dart                         # Supabase + Firebase init
│   ├── core/
│   │   ├── constants/app_constants.dart  # App name, backend URL
│   │   ├── router/app_router.dart        # All routes (go_router)
│   │   ├── services/fcm_service.dart     # Push notification token management
│   │   └── theme/app_theme.dart          # Navy + Gold theme (Material 3)
│   ├── features/
│   │   ├── auth/                         # Login, auth provider, profiles
│   │   ├── leads/                        # All lead management screens + providers
│   │   ├── calls/                        # Call recordings, log outcome sheet
│   │   ├── dashboard/                    # Manager analytics screens
│   │   ├── notifications/                # In-app notification center
│   │   ├── settings/                     # Team settings, profile, password
│   │   └── telecaller/                   # My Performance screen
│   └── shared/widgets/main_shell.dart    # Bottom nav + FAB
├── backend/
│   ├── api/
│   │   ├── index.js                      # Express server entry point
│   │   ├── supabase.js                   # Supabase service role client
│   │   ├── routes/
│   │   │   ├── exotel.js                 # Click-to-call + webhooks
│   │   │   ├── meta.js                   # Meta Lead Ads webhook
│   │   │   └── sheets.js                 # Google Sheets sync
│   │   └── services/
│   │       └── assignment.js             # Lead auto-assignment algorithm
│   ├── google-apps-script/
│   │   └── sheets-sync.js                # Paste into Google Sheets → Apps Script
│   ├── .env.example                      # All required environment variables
│   ├── package.json
│   └── vercel.json                       # Deploy config (Root Directory: backend)
└── supabase/
    └── migrations/001_initial_schema.sql # Full DB schema
```

---

## Supabase Database Schema

### Tables

**`profiles`** — Team members (extends Supabase auth.users)
```
id, name, email, role (telecaller/manager/admin), city,
phone, is_active, service_types[], fcm_token, created_at
```

**`leads`** — All customer leads
```
id, name, phone, email, source, service_type, city, stage,
area, plot_size, budget, notes, assigned_to (→ profiles),
last_outcome, followup_at, future_tag, lost_reason,
khata_type, planning_timeline, last_contacted_at,
created_at, updated_at
```

**`call_logs`** — Every call made
```
id, lead_id (→ leads), called_by (→ profiles),
called_at, duration_seconds, outcome, notes,
recording_url, exotel_call_sid, created_at
```

**`lead_notes`** — Internal team notes on leads
```
id, lead_id (→ leads), author_id (→ profiles),
author_name, text, created_at
```

**`team_settings`** — Assignment strategy and global config
```
id, assignment_strategy, updated_at
```

### Lead Pipeline Stages
```
enquiryReceived → telecallerCallDone → meetingAtOffice →
siteVisit → quotationSent → negotiation → finalAgreement
                                                        ↘ lost
                                                        ↘ future
```

### Khata Types (Karnataka property document)
`aKhata | bKhata | bda | bmrda | panchayat | other`

### Planning Timeline
`immediate | within3Months | within6Months | withinYear`

---

## Data Architecture (Large Scale)

The app handles thousands of leads efficiently through a split data model:

| Provider | What it fetches | Used by |
|---|---|---|
| `leadsProvider` | Paginated (25/page) with full data | Leads list, queue, detail |
| `analyticsProvider` | All leads lightweight (no nested) + 90-day call logs | Dashboard, Performance, Reports, City Analytics |
| `lostLeadsProvider` | `stage = lost` direct query | Lost Leads screen |
| `futurePipelineLeadsProvider` | `future_tag IS NOT NULL` | Future Pipeline screen |
| `calendarLeadsProvider` | `followup_at IS NOT NULL` | Calendar screen |
| `kanbanLeadsProvider` | All active pipeline stages | Kanban board |
| `recordingsLeadsProvider` | Leads with call logs (`INNER JOIN`) | Recordings screen |
| `unassignedLeadsProvider` | `assigned_to IS NULL` | Assignment screen |
| `allOverdueLeadsProvider` | All overdue follow-ups | Dashboard overdue list |

**DB Indexes** (run once):
```sql
create index on public.leads(assigned_to);
create index on public.leads(stage);
create index on public.leads(city);
create index on public.leads(created_at desc);
create index on public.leads(followup_at);
create index on public.call_logs(lead_id);
create index on public.lead_notes(lead_id);
```

---

## Role-Based Access

| Feature | Telecaller | Manager | Admin |
|---|---|---|---|
| See own leads only | ✅ | — | — |
| See all leads | — | ✅ | ✅ |
| Dashboard / Analytics | — | ✅ | ✅ |
| Performance screen | — | ✅ | ✅ |
| Assignment screen | — | ✅ | ✅ |
| City Analytics | — | ✅ | ✅ |
| Reports | — | ✅ | ✅ |
| My Performance | ✅ | — | — |
| Team settings | — | ✅ | ✅ |
| Change password | ❌ (admin resets) | ✅ | ✅ |
| See full phone numbers | — | ✅ | ✅ |
| See masked phone | ✅ | — | — |

Phone numbers are masked for telecallers (`98765 •••••`) to prevent lead theft.

---

## Lead Assignment Strategies

Set in Settings → Lead Assignment. Reads from `team_settings.assignment_strategy`.

| Strategy | Behaviour |
|---|---|
| **Linear** | Fewest leads today, tiebreak: longest wait |
| **Reverse** | Most leads (senior TC gets priority) |
| **Performance** | Highest call count this week gets next lead |
| **Weighted** | Custom % split per TC |
| **Random** | Completely random |
| **Manual** | Manager assigns every lead manually |

Assignment respects:
1. TC must be active (`is_active = true`)
2. City match preferred (Bangalore lead → Bangalore TC)
3. Service type match preferred (based on `service_types[]`)

---

## Backend API Endpoints

Deploy to Vercel with `Root Directory: backend`

```
GET  /                          Health check + service status

POST /exotel/click-to-call      TC taps Call → Exotel dials TC then customer
POST /exotel/call-webhook       Call ends → save recording URL + duration
POST /exotel/inbound-webhook    Inbound call ends → auto-create lead

GET  /meta/lead-webhook         Meta webhook verification (one-time)
POST /meta/lead-webhook         New Meta lead → Supabase + auto-assign

POST /sheets/sync               Google Sheets new row → Supabase + auto-assign
POST /sheets/reconcile          Bulk sync: check Sheets vs Supabase, fill gaps
```

---

## Exotel Call Flow

**Outbound (TC calls customer):**
```
TC taps Call in Mortar
   → Backend POST to Exotel API (TC phone + customer phone + ExoPhone)
   → Exotel calls TC's personal mobile first
   → TC picks up → Exotel bridges to customer
   → Customer sees ExoPhone number (never sees TC's number)
   → Call ends → Exotel POSTs webhook to /exotel/call-webhook
   → Recording URL saved to call_logs.recording_url in Supabase
```

**Inbound (customer calls company):**
```
Customer dials ExoPhone (080-XXXX or 0821-XXXX)
   → All TCs ring simultaneously (no IVR — all trained for all services)
   → First TC to pick up gets connected
   → Call ends → webhook → auto-creates lead if new number
```

---

## Google Sheets Integration

Current flow (Meta Ads → Sheets → Supabase):
```
Meta Lead Ad form submit
   → Google Sheets (Meta's native integration — always backup)
   → Apps Script trigger (backend/google-apps-script/sheets-sync.js)
   → POST /sheets/sync
   → Supabase leads table
   → Auto-assigned to TC
```

Reconciliation (hourly, catches any missed leads):
- Apps Script reads all rows from Sheets
- POSTs to `/sheets/reconcile`
- Backend checks each phone number against Supabase
- Inserts any missing leads

---

## Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill in:

| Variable | Where to get it |
|---|---|
| `SUPABASE_URL` | Supabase → Settings → API |
| `SUPABASE_SERVICE_KEY` | Supabase → Settings → API → service_role |
| `BACKEND_URL` | After Vercel deploy |
| `EXOTEL_SID` | Exotel Dashboard → Settings → API |
| `EXOTEL_API_KEY` | Exotel Dashboard → Settings → API |
| `EXOTEL_API_TOKEN` | Exotel Dashboard → Settings → API |
| `EXOTEL_PHONE_BLR` | Exotel → ExoPhone (Bangalore) |
| `EXOTEL_PHONE_MYS` | Exotel → ExoPhone (Mysore) |
| `META_APP_SECRET` | Meta Developers → App → Settings → Basic |
| `META_VERIFY_TOKEN` | Set any random string, enter same in Meta webhook config |
| `META_PAGE_ACCESS_TOKEN` | Meta → Your Page → Access Tokens |
| `WEBHOOK_SECRET` | Set any random string, use same in Apps Script |
| `FCM_SERVER_KEY` | Firebase Console → Project Settings → Cloud Messaging |

---

## Flutter App Constants

One file to update for deployment: `lib/core/constants/app_constants.dart`

```dart
static const backendUrl = 'https://your-vercel-url.vercel.app';
```

Update this after Vercel deploy. Everything else (Supabase URL, keys) is in `main.dart`.

---

## Login Credentials

All user accounts are managed in Supabase Auth dashboard.

- Roles: `admin`, `manager`, `telecaller`
- Passwords are set when creating accounts in Supabase Auth
- To reset a TC password: Settings → Team Availability → tap TC → Send Password Reset Email
- Managers/Admins can change their own password from Settings → Change Password

---

## Phase Status

**Phase 1 — Flutter App: ✅ Complete**
All 22+ screens, Supabase connected, real-time sync, pagination, analytics

**Phase 2 — Backend Integrations: 🔜 In Progress**
- Backend code written, pending Vercel deployment
- Exotel: pending account signup + KYC
- Meta webhook: pending marketing team access
- FCM: pending Firebase project setup

---

## Security Notes

- TC phone numbers stored in `profiles.phone` — visible only to managers/admins via RLS
- Customer phone numbers masked for telecallers: `98765 •••••`
- TCs cannot change their own password — admin sends reset email via the app
- Backend uses Supabase service role key (bypasses RLS) — never expose this in Flutter
- Exotel API keys server-side only — never in Flutter app

---

## APK Distribution

No Play Store needed. Send `app-release.apk` via WhatsApp.

**Build command:**
```bash
flutter build apk --release --no-pub
# APK: build/app/outputs/flutter-apk/app-release.apk
```

**Android requirements:** API 21+ (Android 5.0+)
