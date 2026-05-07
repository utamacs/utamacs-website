-- ═══════════════════════════════════════════════════════════════
-- 049_notification_pref_enhancements.sql
-- Add preference columns for modules added in Sprints 1-2
-- ═══════════════════════════════════════════════════════════════

-- New module columns (all opt-in defaults match originals: true for social, false for low-signal)
ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS community   boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS marketplace boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS maids       boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS gallery     boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS feedback    boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS snags       boolean NOT NULL DEFAULT true;

-- Back-fill existing rows so the new columns reflect sensible defaults
-- (ADD COLUMN IF NOT EXISTS with DEFAULT handles new rows; existing rows already get the default)

-- Add whatsapp channel flag (phone number stored in profiles.whatsapp_number from 046)
ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS whatsapp_enabled boolean NOT NULL DEFAULT false;

-- ── Feature flag seed ─────────────────────────────────────────────────────────
-- notifications module already seeded; nothing to add here
