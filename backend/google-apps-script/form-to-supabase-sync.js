// ─── Mortar CRM — Google Form to Supabase Sync ────────────────────────────────
// Paste this into: Google Sheet (linked to the Form) → Extensions → Apps Script
// Then follow the trigger setup instructions at the bottom of this file.
//
// Form columns expected (as named in the linked Sheet's header row):
//   Name | Phone | Email | Project Initiation | Location |
//   If your location is not listed above, please enter it here

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

// ─── Trigger handler — runs on every Form submission ──────────────────────
function onFormSubmitToSupabase(e) {
  try {
    if (!e || !e.namedValues) {
      Logger.log('No event data — this function must run from an installable "On form submit" trigger, not manually.');
      return;
    }

    const values = e.namedValues; // { "Question Title": ["answer"], ... }
    const get = (key) => (values[key] && values[key][0] ? values[key][0].toString().trim() : '');

    const name = get('Name');
    let phone = get('Phone').replace(/\D/g, '');
    const email = get('Email') || null;
    const projectInitiation = get('Project Initiation');
    const location = get('Location');
    const otherLocation = get('If your location is not listed above, please enter it here');

    if (!name || !phone) {
      Logger.log('Skipping — missing name or phone. Raw row: ' + JSON.stringify(values));
      return;
    }
    if (phone.length > 10) phone = phone.slice(-10);

    // city has a strict CHECK constraint (bangalore/mysore only) — normalize
    // known spellings, default to bangalore for anything else, and keep the
    // raw text in `area` so a real address is never silently dropped.
    const locationText = (otherLocation || location || '').toLowerCase();
    let city = 'bangalore';
    if (locationText.indexOf('mysore') !== -1 || locationText.indexOf('mysuru') !== -1) {
      city = 'mysore';
    } else if (locationText && locationText.indexOf('bangalore') === -1 && locationText.indexOf('bengaluru') === -1) {
      Logger.log('Unrecognized location "' + (otherLocation || location) + '" for ' + name + ' — defaulted city to bangalore, check the area field.');
    }

    // service_type also has a strict CHECK constraint (construction/renovation/
    // interiors). "Project Initiation" doesn't map cleanly to it — default to
    // construction and preserve the actual answer in notes for manual review.
    const serviceType = 'construction';

    const payload = {
      name: name,
      phone: phone,
      email: email,
      source: 'website',
      service_type: serviceType,
      city: city,
      area: location || otherLocation || null,
      notes: projectInitiation ? ('Project Initiation: ' + projectInitiation) : null,
      stage: 'enquiryReceived',
    };

    const config = getConfig_();
    if (!config.supabaseUrl || !config.serviceRoleKey) {
      Logger.log('ERROR: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set in Script Properties. Aborting.');
      return;
    }

    const response = UrlFetchApp.fetch(config.supabaseUrl + '/rest/v1/leads', {
      method: 'post',
      contentType: 'application/json',
      headers: {
        apikey: config.serviceRoleKey,
        Authorization: 'Bearer ' + config.serviceRoleKey,
        Prefer: 'return=minimal',
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true,
    });

    const code = response.getResponseCode();
    if (code >= 200 && code < 300) {
      Logger.log('Lead synced: ' + name + ' (' + phone + ')');
    } else {
      Logger.log('Supabase insert failed [' + code + ']: ' + response.getContentText());
    }
  } catch (err) {
    Logger.log('onFormSubmitToSupabase error: ' + err.message);
  }
}

// ─── Trigger setup (do this once) ──────────────────────────────────────────
// 1. Open the Google Sheet that the Form feeds → Extensions → Apps Script
// 2. Paste this entire file's contents in
// 3. Project Settings (gear icon) → Script Properties → add SUPABASE_URL and
//    SUPABASE_SERVICE_ROLE_KEY (values above)
// 4. Left sidebar → Triggers (clock icon) → + Add Trigger
//      Function to run:        onFormSubmitToSupabase
//      Event source:           From spreadsheet
//      Event type:             On form submit
// 5. Save — Google will ask you to authorize the script's permissions once
// 6. Submit a test entry through the actual form to confirm it lands in
//    Supabase, then check Executions (left sidebar) for the Logger.log output
//    if anything looks wrong
