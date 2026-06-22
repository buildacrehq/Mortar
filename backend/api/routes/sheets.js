const express = require('express');
const supabase = require('../supabase');
const { assignNewLead } = require('../services/assignment');
const router = express.Router();

// ─── Google Sheets Sync ───────────────────────────────────────────────────────
// Called by Google Apps Script when a new row is added to the Sheets lead form
// Apps Script sends: { name, phone, email, source, city, serviceType, area, budget }
router.post('/sync', async (req, res) => {
  const {
    name,
    phone,
    email,
    source = 'facebook',
    city = 'bangalore',
    serviceType = 'construction',
    area,
    budget,
    secret,
  } = req.body;

  // Basic security — Apps Script sends a shared secret
  if (secret !== process.env.WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  if (!phone || !name) {
    return res.status(400).json({ error: 'name and phone required' });
  }

  const cleanPhone = phone.toString().replace(/\D/g, '');
  res.status(200).json({ received: true });

  try {
    // Check for duplicate by phone
    const { data: existing } = await supabase
      .from('leads')
      .select('id, name')
      .eq('phone', cleanPhone)
      .single();

    if (existing) {
      console.log(`[Sheets] Duplicate: ${cleanPhone} already exists as "${existing.name}"`);
      return;
    }

    // Map source string to enum value
    const sourceMap = {
      'facebook': 'facebook',
      'instagram': 'instagram',
      'website': 'website',
      'whatsapp': 'whatsapp',
      'referral': 'referral',
      'phone': 'phone',
    };

    const { data: newLead, error } = await supabase.from('leads').insert({
      name: name.trim(),
      phone: cleanPhone,
      email: email || null,
      source: sourceMap[source.toLowerCase()] || 'facebook',
      service_type: serviceType.toLowerCase() === 'renovation' ? 'renovation'
                  : serviceType.toLowerCase() === 'interiors' ? 'interiors'
                  : 'construction',
      city: city.toLowerCase() === 'mysore' ? 'mysore' : 'bangalore',
      area: area || null,
      budget: budget || null,
      stage: 'enquiryReceived',
      created_at: new Date().toISOString(),
    }).select('id').single();

    if (error) {
      console.error('[Sheets] Failed to save lead:', error);
      return;
    }

    console.log(`[Sheets] Lead synced: ${newLead.id} — ${name} (${cleanPhone})`);
    await assignNewLead(newLead.id, city.toLowerCase() === 'mysore' ? 'mysore' : 'bangalore', serviceType.toLowerCase());
  } catch (err) {
    console.error('[Sheets] Error:', err.message);
  }
});

// ─── Reconciliation Endpoint ──────────────────────────────────────────────────
// Called periodically to check for leads in Sheets not yet in Supabase
// Reads from the Google Sheet and compares phone numbers
router.post('/reconcile', async (req, res) => {
  const { leads: sheetsLeads, secret } = req.body;

  if (secret !== process.env.WEBHOOK_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  if (!Array.isArray(sheetsLeads) || sheetsLeads.length === 0) {
    return res.json({ synced: 0, message: 'No leads provided' });
  }

  res.status(200).json({ received: true, count: sheetsLeads.length });

  let synced = 0;
  let skipped = 0;

  for (const row of sheetsLeads) {
    const phone = row.phone?.toString().replace(/\D/g, '');
    if (!phone) continue;

    const { data: existing } = await supabase
      .from('leads')
      .select('id')
      .eq('phone', phone)
      .single();

    if (existing) {
      skipped++;
      continue;
    }

    const { error } = await supabase.from('leads').insert({
      name: row.name || `Sheet Lead ${phone}`,
      phone,
      email: row.email || null,
      source: 'facebook',
      service_type: 'construction',
      city: 'bangalore',
      stage: 'enquiryReceived',
      created_at: new Date().toISOString(),
    });

    if (!error) synced++;
  }

  console.log(`[Reconcile] Synced: ${synced}, Skipped (already exist): ${skipped}`);
});

module.exports = router;
