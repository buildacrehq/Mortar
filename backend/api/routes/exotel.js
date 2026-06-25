const express = require('express');
const axios = require('axios');
const supabase = require('../supabase');
const router = express.Router();

// buildacre1 account is on Singapore region — uses api.exotel.com (not api.in.exotel.com)
const EXOTEL_BASE = `https://${process.env.EXOTEL_API_KEY}:${process.env.EXOTEL_API_TOKEN}@${process.env.EXOTEL_SUBDOMAIN}/v1/Accounts/${process.env.EXOTEL_SID}`;

// ─── Click-to-Call ────────────────────────────────────────────────────────────
// Called by Flutter when TC taps "Call" on a lead
// Flutter sends: { leadId, tcPhone, customerPhone, callerId }
router.post('/click-to-call', async (req, res) => {
  const { leadId, tcPhone, customerPhone, callerId } = req.body;

  if (!leadId || !tcPhone || !customerPhone) {
    return res.status(400).json({ error: 'leadId, tcPhone, customerPhone required' });
  }

  try {
    const params = new URLSearchParams({
      From: tcPhone,           // TC's personal mobile (Exotel calls this first)
      To: customerPhone,       // Customer's number (Exotel bridges to this)
      CallerId: callerId || process.env.EXOTEL_PHONE_BLR,
      Record: 'true',          // Auto-record every call
      StatusCallback: `${process.env.BACKEND_URL}/exotel/call-webhook`,
      StatusCallbackEvents: 'terminal',
      CustomField: leadId,     // Pass leadId so webhook can match the call to the lead
      TimeLimit: 3600,         // Max 1 hour call
    });

    const url = `${EXOTEL_BASE}/Calls/connect.json`;
    console.log('[Exotel] Calling URL:', url);
    console.log('[Exotel] Params:', { From: tcPhone, To: customerPhone, CallerId: callerId || process.env.EXOTEL_PHONE_BLR });

    const response = await axios.post(url, params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });

    const callSid = response.data?.Call?.Sid;
    console.log(`[Exotel] ✅ Call initiated: ${callSid} for lead ${leadId}`);

    return res.json({ success: true, callSid });
  } catch (err) {
    const exotelError = err.response?.data;
    console.error('[Exotel] ❌ Error:', JSON.stringify(exotelError || err.message));
    return res.status(400).json({
      error: 'Exotel call failed',
      detail: exotelError || err.message
    });
  }
});

// ─── Call Webhook ─────────────────────────────────────────────────────────────
// Exotel POSTs here when a call ends (terminal event)
// Saves call log + recording URL to Supabase
router.post('/call-webhook', async (req, res) => {
  // Exotel sends form-encoded data
  const {
    CallSid,
    Status,
    ConversationDuration,
    RecordingUrl,
    CustomField: leadId,  // We passed leadId as CustomField when initiating
    Direction,
    From,
    To,
  } = req.body;

  console.log(`[Exotel Webhook] Call ${CallSid} ended — status: ${Status}, duration: ${ConversationDuration}s, leadId: ${leadId}`);

  // Always respond 200 immediately so Exotel doesn't retry
  res.status(200).send('OK');

  if (!leadId) {
    console.warn('[Exotel Webhook] No leadId in CustomField — cannot save call log');
    return;
  }

  try {
    // Find which TC made this call — look up by phone number
    const tcPhone = Direction === 'outbound-api' ? From : To;
    const { data: tcProfile } = await supabase
      .from('profiles')
      .select('id')
      .eq('phone', tcPhone.replace('+91', '').replace('+', ''))
      .single();

    const durationSeconds = parseInt(ConversationDuration || '0', 10);

    // Determine outcome from status
    const outcome = Status === 'completed' && durationSeconds > 10
      ? 'callback'       // Had a real conversation — TC will log proper outcome in app
      : 'notReachable';  // Call failed or too short

    // Save call log to Supabase
    const { error } = await supabase.from('call_logs').insert({
      lead_id: leadId,
      called_by: tcProfile?.id || null,
      duration_seconds: durationSeconds,
      outcome,
      recording_url: RecordingUrl || null,
      exotel_call_sid: CallSid,
      called_at: new Date().toISOString(),
    });

    if (error) {
      console.error('[Exotel Webhook] Failed to save call log:', error);
      return;
    }

    // Update lead's last_contacted_at
    await supabase
      .from('leads')
      .update({ last_contacted_at: new Date().toISOString() })
      .eq('id', leadId);

    console.log(`[Exotel Webhook] Call log saved for lead ${leadId} — ${durationSeconds}s`);
  } catch (err) {
    console.error('[Exotel Webhook] Error processing webhook:', err.message);
  }
});

// ─── Inbound Call Webhook ─────────────────────────────────────────────────────
// Exotel POSTs here when an inbound call ends
// Auto-creates lead if phone number not found in Supabase
router.post('/inbound-webhook', async (req, res) => {
  const {
    CallSid,
    Status,
    ConversationDuration,
    RecordingUrl,
    From: callerPhone,   // Customer's number
    To: exoPhone,        // Which ExoPhone they called (BLR or MYS)
  } = req.body;

  res.status(200).send('OK');

  if (!callerPhone) return;

  const cleanPhone = callerPhone.replace('+91', '').replace('+', '');

  try {
    // Check if lead exists
    const { data: existingLead } = await supabase
      .from('leads')
      .select('id')
      .eq('phone', cleanPhone)
      .single();

    if (existingLead) {
      // Lead exists — just add call log
      await supabase.from('call_logs').insert({
        lead_id: existingLead.id,
        duration_seconds: parseInt(ConversationDuration || '0', 10),
        outcome: 'callback',
        recording_url: RecordingUrl || null,
        exotel_call_sid: CallSid,
        called_at: new Date().toISOString(),
      });
      console.log(`[Exotel Inbound] Call log added to existing lead ${existingLead.id}`);
    } else {
      // New caller — auto-create lead
      // Determine city from which ExoPhone they called
      const city = exoPhone === process.env.EXOTEL_PHONE_MYS ? 'mysore' : 'bangalore';

      const { data: newLead, error } = await supabase.from('leads').insert({
        name: `Inbound Call — ${cleanPhone}`,  // TC will update name in app
        phone: cleanPhone,
        source: 'phone',
        service_type: 'construction',  // Default — TC will update
        city,
        stage: 'telecallerCallDone',
        created_at: new Date().toISOString(),
      }).select('id').single();

      if (!error && newLead) {
        await supabase.from('call_logs').insert({
          lead_id: newLead.id,
          duration_seconds: parseInt(ConversationDuration || '0', 10),
          outcome: 'callback',
          recording_url: RecordingUrl || null,
          exotel_call_sid: CallSid,
          called_at: new Date().toISOString(),
        });
        console.log(`[Exotel Inbound] New lead auto-created: ${newLead.id} for ${cleanPhone}`);
      }
    }
  } catch (err) {
    console.error('[Exotel Inbound] Error:', err.message);
  }
});

module.exports = router;
