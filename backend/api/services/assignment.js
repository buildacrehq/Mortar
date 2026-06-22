const supabase = require('../supabase');

// ─── Lead Auto-Assignment Service ─────────────────────────────────────────────
// Reads assignment strategy from team_settings and assigns lead to best TC
// Called after Meta lead webhook or Sheets sync creates a new lead

async function assignNewLead(leadId, city, serviceType) {
  try {
    // 1. Get assignment strategy from settings
    const { data: settings } = await supabase
      .from('team_settings')
      .select('assignment_strategy')
      .limit(1)
      .single();

    const strategy = settings?.assignment_strategy || 'linear';

    // 2. Get active telecallers for this city + service type
    const { data: telecallers } = await supabase
      .from('profiles')
      .select('id, name, city, service_types')
      .eq('role', 'telecaller')
      .eq('is_active', true);

    if (!telecallers || telecallers.length === 0) {
      console.log(`[Assignment] No active telecallers found — lead ${leadId} stays unassigned`);
      return null;
    }

    // 3. Filter by city match (prefer same city, fall back to any)
    let candidates = telecallers.filter(tc => tc.city === city);
    if (candidates.length === 0) candidates = telecallers; // fallback to all

    // 4. Filter by service type if configured
    const serviceCandidates = candidates.filter(tc =>
      !tc.service_types || tc.service_types.length === 0 ||
      tc.service_types.includes(serviceType)
    );
    if (serviceCandidates.length > 0) candidates = serviceCandidates;

    // 5. Pick TC based on strategy
    const selectedTcId = await pickTc(candidates, strategy, city, serviceType);

    if (!selectedTcId) {
      console.log(`[Assignment] No suitable TC found — lead ${leadId} stays unassigned`);
      return null;
    }

    // 6. Assign the lead
    await supabase
      .from('leads')
      .update({ assigned_to: selectedTcId })
      .eq('id', leadId);

    const tc = candidates.find(t => t.id === selectedTcId);
    console.log(`[Assignment] Lead ${leadId} assigned to ${tc?.name} (${selectedTcId}) via ${strategy} strategy`);

    // 7. Send push notification to TC (if FCM configured)
    await notifyTc(selectedTcId, leadId);

    return selectedTcId;
  } catch (err) {
    console.error('[Assignment] Error:', err.message);
    return null;
  }
}

// ─── Strategy picker ──────────────────────────────────────────────────────────

async function pickTc(candidates, strategy, city, serviceType) {
  switch (strategy) {
    case 'linear':
      return await linearAssign(candidates);

    case 'reverse':
      return await reverseAssign(candidates);

    case 'performance':
      return await performanceAssign(candidates);

    case 'random':
      return candidates[Math.floor(Math.random() * candidates.length)].id;

    case 'manual':
      return null; // Manager assigns manually — no auto-assign

    case 'weighted':
      return await linearAssign(candidates); // Falls back to linear if no weights set

    default:
      return await linearAssign(candidates);
  }
}

// Linear: assign to TC with FEWEST leads today, tiebreak by longest wait
async function linearAssign(candidates) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const counts = await Promise.all(
    candidates.map(async (tc) => {
      const { count } = await supabase
        .from('leads')
        .select('id', { count: 'exact', head: true })
        .eq('assigned_to', tc.id)
        .gte('created_at', today.toISOString());

      // Get last assigned time for tiebreaking
      const { data: lastLead } = await supabase
        .from('leads')
        .select('created_at')
        .eq('assigned_to', tc.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .single();

      return {
        id: tc.id,
        count: count || 0,
        lastAssigned: lastLead?.created_at ? new Date(lastLead.created_at) : new Date(0),
      };
    })
  );

  // Sort: fewest leads first, then oldest last-assigned first (waited longest)
  counts.sort((a, b) => {
    if (a.count !== b.count) return a.count - b.count;
    return a.lastAssigned - b.lastAssigned;
  });

  return counts[0]?.id || null;
}

// Reverse: assign to TC with MOST leads (senior TC handles more)
async function reverseAssign(candidates) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const counts = await Promise.all(
    candidates.map(async (tc) => {
      const { count } = await supabase
        .from('leads')
        .select('id', { count: 'exact', head: true })
        .eq('assigned_to', tc.id)
        .gte('created_at', today.toISOString());
      return { id: tc.id, count: count || 0 };
    })
  );

  counts.sort((a, b) => b.count - a.count);
  return counts[0]?.id || null;
}

// Performance: TC with highest score this week gets the lead
async function performanceAssign(candidates) {
  const weekStart = new Date();
  weekStart.setDate(weekStart.getDate() - weekStart.getDay() + 1);
  weekStart.setHours(0, 0, 0, 0);

  const scores = await Promise.all(
    candidates.map(async (tc) => {
      const { count: callsThisWeek } = await supabase
        .from('call_logs')
        .select('id', { count: 'exact', head: true })
        .eq('called_by', tc.id)
        .gte('called_at', weekStart.toISOString());

      return { id: tc.id, score: callsThisWeek || 0 };
    })
  );

  scores.sort((a, b) => b.score - a.score);
  return scores[0]?.id || null;
}

// ─── FCM Notification ─────────────────────────────────────────────────────────
// Sends push notification to TC when a new lead is assigned

async function notifyTc(tcId, leadId) {
  if (!process.env.FCM_SERVER_KEY) return; // FCM not configured yet

  try {
    // Get TC's FCM token from profiles
    const { data: profile } = await supabase
      .from('profiles')
      .select('fcm_token, name')
      .eq('id', tcId)
      .single();

    if (!profile?.fcm_token) return; // TC hasn't logged in or token not saved

    // Get lead details for notification
    const { data: lead } = await supabase
      .from('leads')
      .select('name, source, city')
      .eq('id', leadId)
      .single();

    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${process.env.FCM_SERVER_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: profile.fcm_token,
        notification: {
          title: 'New Lead Assigned',
          body: `${lead?.name || 'New lead'} — ${lead?.source || 'Unknown source'} — ${lead?.city || ''}`,
          sound: 'default',
        },
        data: {
          leadId,
          type: 'new_lead',
        },
      }),
    });

    const result = await response.json();
    if (result.success) {
      console.log(`[FCM] Notification sent to ${profile.name}`);
    }
  } catch (err) {
    console.error('[FCM] Failed to send notification:', err.message);
  }
}

module.exports = { assignNewLead, notifyTc };
