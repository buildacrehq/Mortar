const express = require('express');
const router = express.Router();
const supabase = require('../supabase');

// ─── Auth middleware — caller must be admin or manager ─────────────────────────
async function requireManager(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Missing auth token' });

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return res.status(401).json({ error: 'Invalid token' });

  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single();

  if (!profile || !['admin', 'manager'].includes(profile.role)) {
    return res.status(403).json({ error: 'Insufficient role' });
  }

  req.callerId = user.id;
  next();
}

// ─── POST /team/create-member ─────────────────────────────────────────────────
// Creates a new Supabase auth user + profile row
router.post('/create-member', requireManager, async (req, res) => {
  const { name, email, phone, password, role, city } = req.body;

  if (!name || !email || !password || !role) {
    return res.status(400).json({ error: 'name, email, password, role are required' });
  }

  const validRoles = ['telecaller', 'manager', 'admin'];
  if (!validRoles.includes(role)) {
    return res.status(400).json({ error: `role must be one of: ${validRoles.join(', ')}` });
  }

  try {
    // 1. Create auth user (email auto-confirmed, no invite email)
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (authError) {
      const msg = authError.message || 'Failed to create user';
      // Surface duplicate email clearly
      if (msg.toLowerCase().includes('already')) {
        return res.status(409).json({ error: 'A user with this email already exists' });
      }
      return res.status(400).json({ error: msg });
    }

    const userId = authData.user.id;

    // 2. Insert profile row (trigger may do this but upsert is safe)
    const { error: profileError } = await supabase.from('profiles').upsert({
      id: userId,
      name,
      email,
      phone: phone || null,
      role,
      city: city || null,
      is_active: true,
      calling_type: 'personal',
    });

    if (profileError) {
      // Auth user created but profile failed — log but don't fail silently
      console.error('[Team] Profile insert failed for', userId, profileError.message);
      // Attempt cleanup
      await supabase.auth.admin.deleteUser(userId);
      return res.status(500).json({ error: 'Profile creation failed. User rolled back.' });
    }

    console.log(`[Team] Created ${role} "${name}" (${email}) by caller ${req.callerId}`);
    res.json({ success: true, userId, name, email, role });

  } catch (err) {
    console.error('[Team] Unexpected error:', err.message);
    res.status(500).json({ error: 'Unexpected error creating member' });
  }
});

// ─── DELETE /team/remove-member/:userId ──────────────────────────────────────
// Deactivates a member (soft delete — marks is_active false, keeps data)
router.delete('/remove-member/:userId', requireManager, async (req, res) => {
  const { userId } = req.params;

  if (userId === req.callerId) {
    return res.status(400).json({ error: 'Cannot deactivate your own account' });
  }

  try {
    await supabase
      .from('profiles')
      .update({ is_active: false })
      .eq('id', userId);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
