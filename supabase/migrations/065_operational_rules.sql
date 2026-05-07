-- Migration 065: Operational rules for configurable business parameters
-- All values previously hardcoded in API routes now live in the rules engine.
-- Locked rules = mandated by byelaw/law; unlocked = society can adjust.

INSERT INTO rules (society_id, rule_category, rule_code, label, description, byelaw_reference,
                   value_type, current_value, default_value, is_locked)
SELECT s.id,
       r.rule_category, r.rule_code, r.label, r.description, r.byelaw_reference,
       r.value_type, r.current_value::jsonb, r.default_value::jsonb, r.is_locked
FROM societies s,
(VALUES
  -- ── Signed URL expiry (DPDPA compliance – LOCKED) ─────────────────────────
  ('PARAMETER','SIGNED_URL_EXPIRY_SECS',
   'Signed URL expiry (seconds)',
   'Maximum lifetime of Supabase Storage signed URLs. DPDPA 2023 §8.7 mandates ≤3600 seconds (1 hour) for identity documents.',
   null, 'INTEGER', '3600', '3600', true),

  ('PARAMETER','SENSITIVE_DOC_URL_EXPIRY_SECS',
   'Sensitive document signed URL expiry (seconds)',
   'Shorter expiry for highly sensitive documents (Aadhaar, sale deeds). Admin may reduce further.',
   null, 'INTEGER', '900', '900', false),

  -- ── Marketplace / Community listings ──────────────────────────────────────
  ('PARAMETER','MARKETPLACE_LISTING_EXPIRY_DAYS',
   'Marketplace listing auto-expiry (days)',
   'Number of days after which a marketplace listing is automatically marked expired.',
   null, 'INTEGER', '30', '30', false),

  ('PARAMETER','COMMUNITY_POST_EXPIRY_DAYS',
   'Community board post expiry (days)',
   'Number of days before a community board post is automatically archived.',
   null, 'INTEGER', '90', '90', false),

  -- ── Analytics / Reports retention ─────────────────────────────────────────
  ('PARAMETER','ANALYTICS_LOOKBACK_DAYS',
   'Analytics dashboard lookback window (days)',
   'How many days of data to include in the analytics overview.',
   null, 'INTEGER', '30', '30', false),

  -- ── Asset management ──────────────────────────────────────────────────────
  ('PARAMETER','ASSET_SERVICE_WARNING_DAYS',
   'Asset service due warning period (days)',
   'Flag an asset as "service due soon" this many days before its service date.',
   null, 'INTEGER', '30', '30', false),

  -- ── Maintenance / Finance ──────────────────────────────────────────────────
  ('PARAMETER','MAINTENANCE_INTEREST_RATE_PA',
   'Annual interest rate on maintenance arrears (% p.a.)',
   'Interest levied on overdue maintenance charges per Byelaw §19e and §6.37.',
   '§6.37 §19e', 'DECIMAL', '18', '18', true),

  ('PARAMETER','GST_RATE_MAINTENANCE',
   'GST rate on maintenance charges (%)',
   'GST rate applicable to maintenance charges collected from members.',
   null, 'DECIMAL', '18', '18', false),

  -- ── Defaulter thresholds ───────────────────────────────────────────────────
  -- NOTE: VOTE_SUSPENSION_DAYS (90) and DEFAULTER_FLAG_DAYS (60) already exist
  ('PARAMETER','DEFAULTER_NOTICE_SEND_DAYS',
   'Days before formal dues notice is issued',
   'When arrears exceed this many days, system flags for formal notice issuance.',
   '§6.37', 'INTEGER', '90', '90', true),

  -- ── Tenant KYC ────────────────────────────────────────────────────────────
  ('PARAMETER','TENANT_KYC_EXPIRY_MONTHS',
   'Tenant KYC record expiry (months)',
   'Tenant KYC records expire after this many months from tenancy start; re-verification required.',
   null, 'INTEGER', '12', '12', false),

  -- ── Election / AGM ────────────────────────────────────────────────────────
  ('PARAMETER','ELECTION_NOTICE_DAYS',
   'Days before election that notice must be sent',
   'Per Byelaw §7.15a: elections must be held 45 days before term expiry.',
   '§7.15a', 'INTEGER', '45', '45', true),

  ('PARAMETER','BOARD_TERM_YEARS',
   'Board of Directors term (years)',
   'Per Byelaw §7.13: each director serves a 4-year term.',
   '§7.13', 'INTEGER', '4', '4', true),

  ('PARAMETER','SPECIAL_GB_PETITION_PCT',
   'Special GB meeting petition threshold (% of members)',
   'Per Byelaw §7.6: special GB meeting triggered by petition from 50% of registered members.',
   '§7.6', 'INTEGER', '50', '50', true),

  -- ── Portal / Invites ──────────────────────────────────────────────────────
  ('PARAMETER','SESSION_ACTIVE_WINDOW_MINUTES',
   'Session "active" window for admin monitoring (minutes)',
   'An auth session is considered "active" if last sign-in was within this many minutes.',
   null, 'INTEGER', '60', '60', false),

  -- ── Petty cash limit ──────────────────────────────────────────────────────
  ('PARAMETER','PETTY_CASH_LIMIT',
   'Maximum petty cash held by Secretary/Treasurer (₹)',
   'Per Byelaw §9.1: petty cash not to exceed ₹50,000.',
   '§9.1', 'INTEGER', '50000', '50000', true),

  -- ── Facility booking ──────────────────────────────────────────────────────
  ('PARAMETER','FACILITY_BOOKING_MIN_ADVANCE_HOURS',
   'Minimum advance booking time for facilities (hours)',
   'Members must book facilities at least this many hours in advance.',
   null, 'INTEGER', '2', '2', false),

  ('PARAMETER','FACILITY_BOOKING_MAX_DURATION_HOURS',
   'Maximum facility booking duration (hours)',
   'Single booking cannot exceed this many hours.',
   null, 'INTEGER', '8', '8', false),

  -- ── Visitor management ────────────────────────────────────────────────────
  ('PARAMETER','VISITOR_PRE_APPROVAL_HOURS',
   'Visitor pre-approval maximum duration (hours)',
   'Per Byelaw §12.2: visitors may park for 12 hours max without special permission.',
   '§12.2', 'INTEGER', '12', '12', true)

) AS r(rule_category, rule_code, label, description, byelaw_reference,
       value_type, current_value, default_value, is_locked)
ON CONFLICT (society_id, rule_code) DO NOTHING;
