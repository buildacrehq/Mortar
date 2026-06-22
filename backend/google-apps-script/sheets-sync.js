// ─── Mortar CRM — Google Sheets to Supabase Sync ─────────────────────────────
// Paste this code in: Google Sheets → Extensions → Apps Script
// Then set a trigger: onFormSubmit or onChange

const BACKEND_URL = 'https://your-vercel-url.vercel.app'; // Update after Vercel deploy
const WEBHOOK_SECRET = 'mortar_webhook_secret_2025';

// ─── Trigger: runs when a new lead row is added ───────────────────────────────
function onNewLead(e) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const row = e ? e.range.getRow() : sheet.getLastRow();

  // Column mapping — adjust to match your actual sheet columns
  const data = {
    name:        sheet.getRange(row, 1).getValue(), // Column A
    phone:       sheet.getRange(row, 2).getValue(), // Column B
    email:       sheet.getRange(row, 3).getValue(), // Column C
    source:      sheet.getRange(row, 4).getValue() || 'facebook', // Column D
    city:        sheet.getRange(row, 5).getValue() || 'bangalore', // Column E
    serviceType: sheet.getRange(row, 6).getValue() || 'construction', // Column F
    area:        sheet.getRange(row, 7).getValue(), // Column G
    budget:      sheet.getRange(row, 8).getValue(), // Column H
    secret:      WEBHOOK_SECRET,
  };

  if (!data.phone || !data.name) {
    Logger.log('Skipping row — missing name or phone');
    return;
  }

  try {
    const response = UrlFetchApp.fetch(`${BACKEND_URL}/sheets/sync`, {
      method: 'POST',
      contentType: 'application/json',
      payload: JSON.stringify(data),
      muteHttpExceptions: true,
    });

    Logger.log(`Synced ${data.name} (${data.phone}) — Status: ${response.getResponseCode()}`);
  } catch (err) {
    Logger.log(`Error syncing ${data.phone}: ${err.message}`);
  }
}

// ─── Manual reconciliation — run this to bulk-sync all existing rows ──────────
function reconcileAll() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const lastRow = sheet.getLastRow();
  const leads = [];

  // Start from row 2 (skip header)
  for (let i = 2; i <= lastRow; i++) {
    const phone = sheet.getRange(i, 2).getValue()?.toString();
    const name = sheet.getRange(i, 1).getValue()?.toString();
    if (phone && name) {
      leads.push({ name, phone, email: sheet.getRange(i, 3).getValue() });
    }
  }

  if (leads.length === 0) {
    Logger.log('No leads found in sheet');
    return;
  }

  try {
    const response = UrlFetchApp.fetch(`${BACKEND_URL}/sheets/reconcile`, {
      method: 'POST',
      contentType: 'application/json',
      payload: JSON.stringify({ leads, secret: WEBHOOK_SECRET }),
      muteHttpExceptions: true,
    });

    Logger.log(`Reconciliation complete — Status: ${response.getResponseCode()}`);
    Logger.log(response.getContentText());
  } catch (err) {
    Logger.log(`Reconciliation error: ${err.message}`);
  }
}

// ─── How to set up triggers ───────────────────────────────────────────────────
// 1. Go to Extensions → Apps Script
// 2. Paste this code
// 3. Click "Triggers" (clock icon on left)
// 4. Add trigger: onNewLead → On form submit (or On spreadsheet change)
// 5. Update BACKEND_URL after Vercel deployment
// 6. Run reconcileAll() once manually to sync existing leads
