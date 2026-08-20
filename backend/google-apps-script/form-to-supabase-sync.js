// ─── Mortar CRM — Google Form to Supabase Sync ────────────────────────────────
// Paste this into: Google Sheet (linked to the Form) → Extensions → Apps Script
// Then follow the trigger setup instructions at the bottom of this file.
//
// Source form: BUILDACRE.IN "Get Free Consultation" popup / contact page.
// Form questions (exact titles, as they appear in the Sheet's header row):
//   Name | Phone | Email | Project Initiation | Location |
//   If your location is not listed above, please enter it here
//
// Project Initiation is a fixed dropdown: Immediate / Within 3 Months / Within 6 Months
// Location is a fixed dropdown: Bangalore / Mysore / Other
//   (the free-text field only has a value when Location = "Other")
//
// The sheet may have extra manually-added columns (e.g. a "DNP on <date>"
// tracking column) mixed in with the form's own columns — backfillExistingRows
// finds columns by header text so it doesn't matter where they sit.

// ─── Configuration ─────────────────────────────────────────────────────────
// Store secrets in Script Properties instead of hardcoding them here:
// Apps Script editor → Project Settings (gear icon) → Script Properties → Add:
//   SUPABASE_URL               = https://lvbjwlbzgerrnbdxugil.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY  = <service_role key from Supabase → Settings → API>
//
// Use the service_role key, not anon — the leads table's RLS policies only
// allow writes from an authenticated manager/admin session. A script has no
// session, so anon would be rejected. service_role bypasses RLS (same as the
// Node backend already does), so keep it out of anywhere public.
function getConfig_() {
  const props = PropertiesService.getScriptProperties();
  return {
    supabaseUrl: props.getProperty('SUPABASE_URL'),
    serviceRoleKey: props.getProperty('SUPABASE_SERVICE_ROLE_KEY'),
  };
}

// Project Initiation dropdown -> Mortar's planning_timeline enum.
var TIMELINE_MAP = {
  'immediate': 'immediate',
  'within 3 months': 'within3Months',
  'within 6 months': 'within6Months',
};

// Location dropdown -> Mortar's city enum (bangalore/mysore only — anything
// else, including "Other", has no valid enum value so it defaults to
// bangalore and the real answer is preserved in `area`).
var CITY_MAP = {
  'bangalore': 'bangalore',
  'mysore': 'mysore',
};

// Sheet cells can come back as Date/Number objects (not strings) depending on
// how a cell happens to be formatted, even in a column that's normally text —
// e.g. someone's "other location" answer getting auto-interpreted as a date.
// e.namedValues (the live trigger path) is always plain strings already, but
// backfillExistingRows reads raw getValues() output, so every field needs to
// survive a non-string value safely.
function toStr_(value) {
  if (value === null || value === undefined || value === '') return '';
  return String(value).trim();
}

// ─── Shared sync logic — used by both the live trigger and the backfill ────
// Returns 'synced' | 'duplicate' | 'skipped' | 'error' for the caller to tally.
function syncLeadToSupabase_(fields) {
  var name = toStr_(fields.name);
  var phone = toStr_(fields.phone).replace(/\D/g, '');
  var email = toStr_(fields.email) || null;
  var projectInitiation = toStr_(fields.projectInitiation);
  var location = toStr_(fields.location);
  var otherLocation = toStr_(fields.otherLocation);

  if (!name || !phone) {
    Logger.log('Skipping — missing name or phone. Raw: ' + JSON.stringify(fields));
    return 'skipped';
  }
  if (phone.length > 10) phone = phone.slice(-10);

  // Backfill passes the sheet's original submission timestamp (column A —
  // still Google Forms' auto-generated Timestamp column underneath, even
  // though it's been relabeled "DNP on 20/7") so historical leads keep their
  // real dates instead of all showing as created today. Live form
  // submissions don't set this — "now" is correct for those.
  var createdAt = null;
  if (fields.createdAt instanceof Date && !isNaN(fields.createdAt.getTime())) {
    createdAt = fields.createdAt.toISOString();
  }

  var planningTimeline = TIMELINE_MAP[projectInitiation.toLowerCase()] || null;
  if (projectInitiation && !planningTimeline) {
    Logger.log('Unrecognized Project Initiation value "' + projectInitiation + '" for ' + name + ' — left planning_timeline blank.');
  }

  var city = CITY_MAP[location.toLowerCase()] || 'bangalore';
  if (!CITY_MAP[location.toLowerCase()]) {
    Logger.log('Location "' + location + '" (other: "' + otherLocation + '") for ' + name + ' — defaulted city to bangalore, real location is in the area field.');
  }

  var config = getConfig_();
  if (!config.supabaseUrl || !config.serviceRoleKey) {
    Logger.log('ERROR: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set in Script Properties. Aborting.');
    return 'error';
  }
  var authHeaders = {
    apikey: config.serviceRoleKey,
    Authorization: 'Bearer ' + config.serviceRoleKey,
  };

  // Skip if a lead with this phone number already exists (repeat form
  // submissions happen — saw two rows with the same phone in the sheet).
  var checkResponse = UrlFetchApp.fetch(
    config.supabaseUrl + '/rest/v1/leads?phone=eq.' + encodeURIComponent(phone) + '&select=id',
    { method: 'get', headers: authHeaders, muteHttpExceptions: true },
  );
  if (checkResponse.getResponseCode() === 200) {
    var existing = JSON.parse(checkResponse.getContentText());
    if (existing.length > 0) {
      Logger.log('Skipping duplicate — phone ' + phone + ' already exists (lead ' + existing[0].id + ').');
      return 'duplicate';
    }
  }

  // service_type has a NOT NULL CHECK constraint (construction/renovation/
  // interiors) but this form never asks for it — defaulting to construction,
  // Buildacre's primary service. Revisit if the form ever adds this question.
  var payload = {
    name: name,
    phone: phone,
    email: email,
    source: 'website',
    service_type: 'construction',
    city: city,
    area: location.toLowerCase() === 'other' ? otherLocation || null : null,
    planning_timeline: planningTimeline,
    stage: 'enquiryReceived',
  };
  if (createdAt) payload.created_at = createdAt;

  var response = UrlFetchApp.fetch(config.supabaseUrl + '/rest/v1/leads', {
    method: 'post',
    contentType: 'application/json',
    headers: Object.assign({ Prefer: 'return=minimal' }, authHeaders),
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });

  var code = response.getResponseCode();
  if (code >= 200 && code < 300) {
    Logger.log('Lead synced: ' + name + ' (' + phone + ')');
    return 'synced';
  }
  Logger.log('Supabase insert failed [' + code + '] for ' + name + ': ' + response.getContentText());
  return 'error';
}

// ─── Trigger handler — runs on every new Form submission ──────────────────
function onFormSubmitToSupabase(e) {
  try {
    if (!e || !e.namedValues) {
      Logger.log('No event data — this function must run from an installable "On form submit" trigger, not manually.');
      return;
    }
    var values = e.namedValues; // { "Question Title": ["answer"], ... }
    var get = function (key) {
      return values[key] && values[key][0] ? values[key][0].toString() : '';
    };
    syncLeadToSupabase_({
      name: get('Name'),
      phone: get('Phone'),
      email: get('Email'),
      projectInitiation: get('Project Initiation'),
      location: get('Location'),
      otherLocation: get('If your location is not listed above, please enter it here'),
    });
  } catch (err) {
    Logger.log('onFormSubmitToSupabase error: ' + err.message);
  }
}

// ─── One-time backfill — run manually to sync rows that already exist ─────
// Select this function in the Apps Script editor's toolbar dropdown and click
// Run once. Safe to re-run any time — the phone-number check in
// syncLeadToSupabase_ skips rows already in Supabase, so it won't duplicate.
function backfillExistingRows() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Form responses 1')
    || SpreadsheetApp.getActiveSheet();
  var data = sheet.getDataRange().getValues();
  var header = data[0];

  var col = {}; // header text -> column index
  for (var c = 0; c < header.length; c++) col[header[c].toString().trim()] = c;

  var required = ['Name', 'Phone'];
  for (var r = 0; r < required.length; r++) {
    if (!(required[r] in col)) {
      Logger.log('ERROR: Could not find a "' + required[r] + '" column in the header row. Found: ' + header.join(', '));
      return;
    }
  }

  var tally = { synced: 0, duplicate: 0, skipped: 0, error: 0 };
  for (var row = 1; row < data.length; row++) {
    var get = function (name) {
      return col[name] !== undefined ? data[row][col[name]] : '';
    };
    var result = syncLeadToSupabase_({
      name: get('Name'),
      phone: get('Phone'),
      email: get('Email'),
      projectInitiation: get('Project Initiation'),
      location: get('Location'),
      otherLocation: get('If your location is not listed above, please enter it here'),
      // Column A is Google Forms' auto Timestamp column regardless of its
      // current header label — always the true submission time.
      createdAt: data[row][0],
    });
    tally[result] = (tally[result] || 0) + 1;
    Utilities.sleep(150); // stay well under Supabase/Apps Script rate limits
  }

  Logger.log('Backfill complete — synced: ' + tally.synced + ', duplicates skipped: ' + tally.duplicate + ', rows skipped (missing data): ' + tally.skipped + ', errors: ' + tally.error);
}

// ─── Setup (do this once) ───────────────────────────────────────────────────
// 1. Open the Google Sheet that the Form feeds → Extensions → Apps Script
// 2. Paste this entire file's contents in
// 3. Project Settings (gear icon) → Script Properties → add SUPABASE_URL and
//    SUPABASE_SERVICE_ROLE_KEY (values above)
// 4. Live trigger — Left sidebar → Triggers (clock icon) → + Add Trigger
//      Function to run:        onFormSubmitToSupabase
//      Event source:           From spreadsheet
//      Event type:             On form submit
//    Save — Google will ask you to authorize the script's permissions once,
//    under your own Google account (fine even though you're an Editor, not
//    the Sheet's owner)
// 5. Backfill the 269 existing rows — in the Apps Script editor toolbar,
//    select "backfillExistingRows" from the function dropdown and click Run.
//    Check Executions (left sidebar) afterward for the summary log line.
// 6. Submit one test entry through the live form to confirm the trigger
//    itself works end to end.
