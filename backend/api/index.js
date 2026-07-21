require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true })); // Exotel sends form-encoded data

// ─── Health Check ─────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({
    app: 'Mortar CRM Backend',
    version: '1.0.0',
    status: 'running',
    timestamp: new Date().toISOString(),
    services: {
      exotel: !!process.env.EXOTEL_API_KEY ? 'configured' : 'pending',
      meta: !!process.env.META_APP_SECRET ? 'configured' : 'pending',
      supabase: !!process.env.SUPABASE_URL ? 'configured' : 'missing',
    }
  });
});

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/exotel', require('./routes/exotel'));
app.use('/meta', require('./routes/meta'));
app.use('/sheets', require('./routes/sheets'));
app.use('/team', require('./routes/team'));

// ─── 404 ──────────────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: `Route not found: ${req.method} ${req.path}` });
});

// ─── Error Handler ────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('[Server Error]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// ─── Start ────────────────────────────────────────────────────────────────────
// Local dev only — Vercel handles port automatically
if (process.env.NODE_ENV !== 'production' && process.env.VERCEL !== '1') {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Mortar Backend running on port ${PORT}`);
  });
}

module.exports = app;
