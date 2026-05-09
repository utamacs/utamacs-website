-- demo_cleanup.sql — Remove all rows inserted by demo_data.sql
-- Safe to run multiple times. Leaves all pre-existing society data intact.
-- Run: psql <conn_string> -f supabase/demo_cleanup.sql

BEGIN;

-- ── §25 Notifications ───────────────────────────────────────────────────────
DELETE FROM notifications
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'notifications');

-- ── §24 Registration Requests ───────────────────────────────────────────────
DELETE FROM registration_requests
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'registration_requests');

-- ── §23 Policies ────────────────────────────────────────────────────────────
DELETE FROM policy_acknowledgements
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'policy_acknowledgements');

DELETE FROM policies
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'policies');

-- ── §22 Letters ─────────────────────────────────────────────────────────────
DELETE FROM generated_letters
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'generated_letters');

-- ── §21 Documents ───────────────────────────────────────────────────────────
DELETE FROM documents
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'society_documents');

-- ── §20 HOTO + Snags (TEXT PKs) ─────────────────────────────────────────────
DELETE FROM snag_items     WHERE id LIKE 'DEMO-SNAG-%';
DELETE FROM hoto_required_docs
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'hoto_required_docs');
DELETE FROM hoto_items     WHERE id LIKE 'DEMO-HOTO-%';

-- ── §19 Staff + Attendance ──────────────────────────────────────────────────
DELETE FROM staff_attendance
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'staff_attendance');

DELETE FROM staff_members
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'staff');

-- ── §18 Memberships ─────────────────────────────────────────────────────────
DELETE FROM memberships
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'memberships');

-- ── §17 Tenant KYC ──────────────────────────────────────────────────────────
DELETE FROM tenant_kyc
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'tenant_kyc');

-- ── §16 Security Patrol ─────────────────────────────────────────────────────
DELETE FROM patrol_logs
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'security_patrol_logs');

-- ── §15 Water Tankers ───────────────────────────────────────────────────────
DELETE FROM water_tankers
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'water_tanker_deliveries');

-- ── §14 Feedback ────────────────────────────────────────────────────────────
DELETE FROM feedbacks
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'feedbacks');

-- ── §13 Gallery ─────────────────────────────────────────────────────────────
DELETE FROM gallery_photos
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'gallery_photos');

DELETE FROM gallery_albums
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'gallery_albums');

-- ── §12 Maids ───────────────────────────────────────────────────────────────
DELETE FROM maid_attendance
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'maid_attendance');

DELETE FROM maid_unit_approvals
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'maid_unit_approvals');

DELETE FROM maids
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'maids');

-- ── §11 AGM ─────────────────────────────────────────────────────────────────
DELETE FROM agm_resolutions
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'agm_resolutions');

DELETE FROM agm_documents
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'agm_documents');

DELETE FROM agm_sessions
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'agm_sessions');

-- ── §10 Parking ─────────────────────────────────────────────────────────────
DELETE FROM parking_allocations
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'parking_allocations');

DELETE FROM parking_slots
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'parking_slots');

-- ── §09 Community + Marketplace ─────────────────────────────────────────────
DELETE FROM marketplace_listings
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'marketplace_listings');

DELETE FROM post_comments
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'community_comments');

DELETE FROM community_posts
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'community_posts');

-- ── §08 Vendors + Work Orders ───────────────────────────────────────────────
DELETE FROM work_orders
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'work_orders');

DELETE FROM vendors
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'vendors');

-- ── §07 Facilities + Bookings ───────────────────────────────────────────────
DELETE FROM facility_bookings
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'facility_bookings');

DELETE FROM facilities
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'facilities');

-- ── §06 Polls ───────────────────────────────────────────────────────────────
DELETE FROM poll_votes
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'poll_votes');

DELETE FROM poll_options
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'poll_options');

DELETE FROM polls
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'polls');

-- ── §05 Events + Registrations ──────────────────────────────────────────────
DELETE FROM event_registrations
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'event_registrations');

DELETE FROM events
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'events');

-- ── §04 Finance ─────────────────────────────────────────────────────────────
DELETE FROM expenses
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'expenses');

DELETE FROM expense_categories
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'expense_categories');

DELETE FROM payments
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'payments');

DELETE FROM maintenance_dues
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'maintenance_dues');

DELETE FROM billing_periods
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'billing_periods');

-- ── §03 Complaints ──────────────────────────────────────────────────────────
DELETE FROM complaint_status_history
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'complaint_status_history');

DELETE FROM complaint_comments
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'complaint_comments');

DELETE FROM complaints
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'complaints');

-- ── §02 Notices ─────────────────────────────────────────────────────────────
DELETE FROM notices
WHERE id IN (SELECT record_id::uuid FROM _demo_data_registry WHERE tbl = 'notices');

-- ── §01 Units (G-Block and H-Block) ─────────────────────────────────────────
-- Units drive FK constraints on many tables above — delete last
DELETE FROM units
WHERE society_id = '00000000-0000-0000-0000-000000000001'
  AND block IN ('G', 'H');

-- ── Teardown registry ────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _demo_data_registry;

COMMIT;
