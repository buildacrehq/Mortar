const express = require('express');
const supabase = require('../supabase');
const router = express.Router();

// ─── Meta Webhook Verification ────────────────────────────────────────────────
// Meta sends a GET request to verify the webhook endpoint
router.get('/lead-webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === process.env.META_VERIFY_TOKEN) {
    console.log('[Meta] Webhook verified ✅');
    return res.status(200).send(challenge);
  }
  return res.status(403).send('Forbidden');
});

// ─── Meta Lead Ads Webhook ────────────────────────────────────────────────────
// Meta POSTs here when someone submits a Lead Ad form
router.post('/lead-webhook', async (req, res) => {
  // Always respond 200 immediately — Meta requires fast response
  res.status(200).send('EVENT_RECEIVED');

  const body = req.body;
  if (body.object !== 'page') return;

  for (const entry of body.entry || []) {
    for (const change of entry.changes || []) {
      if (change.field !== 'leadgen') continue;

      const leadgenId = change.value?.leadgen_id;
      const pageId = change.value?.page_id;

      if (!leadgenId) continue;

      try {
        // Fetch lead details from Meta Graph API
        const response = await fetch(
          `https://graph.facebook.com/v18.0/${leadgenId}?access_token=${process.env.META_PAGE_ACCESS_TOKEN}`
        );
        const leadData = await response.json();

        if (!leadData || leadData.error) {
          console.error('[Meta] Failed to fetch lead:', leadData?.error);
          continue;
        }

        // Parse fields from Meta lead form
        const fields = {};
        for (const field of leadData.field_data || []) {
          fields[field.name] = field.values?.[0] || '';
        }

        const phone = (fields['phone_number'] || fields['phone'] || '').replace(/\D/g, '');
        const name = fields['full_name'] || fields['first_name'] || 'Meta Lead';
        const email = fields['email'] || null;

        if (!phone) {
          console.warn('[Meta] Lead has no phone number — skipping');
          continue;
        }

        // Check for duplicate
        const { data: existing } = await supabase
          .from('leads')
          .select('id')
          .eq('phone', phone)
          .single();

        if (existing) {
          console.log(`[Meta] Duplicate phone ${phone} — lead already exists`);
          continue;
        }

        // Determine city from campaign (can be enhanced later)
        const city = 'bangalore'; // Default — can be mapped from campaign name

        // Save to Supabase
        const { data: newLead, error } = await supabase.from('leads').insert({
          name,
          phone,
          email,
          source: 'facebook',
          service_type: 'construction',
          city,
          stage: 'enquiryReceived',
          created_at: new Date().toISOString(),
        }).select('id').single();

        if (error) {
          console.error('[Meta] Failed to save lead:', error);
          continue;
        }

        console.log(`[Meta] New lead saved: ${newLead.id} — ${name} (${phone})`);

        // TODO: Trigger assignment algorithm (Phase 2.5)
        // await assignLead(newLead.id, city, 'construction');

      } catch (err) {
        console.error('[Meta] Error processing lead:', err.message);
      }
    }
  }
});

module.exports = router;
