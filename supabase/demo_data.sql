-- ═══════════════════════════════════════════════════════════════════════════════
-- UTA MACS — Comprehensive Demo Data   (supabase/demo_data.sql)
-- Covers all 28 portal modules; every row tracked in _demo_data_registry.
-- Prerequisites: at least one admin user must exist in auth.users.
-- Cleanup:  psql <conn> -f supabase/demo_cleanup.sql
-- ═══════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── Registry ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS _demo_data_registry (
  id          bigserial   PRIMARY KEY,
  tbl         text        NOT NULL,
  record_id   text        NOT NULL,
  inserted_at timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS _demo_reg_uk ON _demo_data_registry(tbl, record_id);

-- ── ID pools (session-scoped; shared across DO blocks) ────────────────────────
CREATE TEMP TABLE IF NOT EXISTS _demo_unit_pool    (rn serial PRIMARY KEY, uid  uuid UNIQUE);
CREATE TEMP TABLE IF NOT EXISTS _demo_vendor_pool  (rn serial PRIMARY KEY, vid  uuid UNIQUE);
CREATE TEMP TABLE IF NOT EXISTS _demo_period_pool  (rn int   PRIMARY KEY, pid  uuid UNIQUE, amt numeric, due_date date);
CREATE TEMP TABLE IF NOT EXISTS _demo_facility_pool(rn serial PRIMARY KEY, fid  uuid UNIQUE);
CREATE TEMP TABLE IF NOT EXISTS _demo_slot_pool    (rn serial PRIMARY KEY, slid uuid UNIQUE);
CREATE TEMP TABLE IF NOT EXISTS _demo_maid_pool    (rn serial PRIMARY KEY, mid  uuid UNIQUE);
CREATE TEMP TABLE IF NOT EXISTS _demo_album_pool   (rn serial PRIMARY KEY, aid  uuid UNIQUE);
CREATE TEMP TABLE IF NOT EXISTS _demo_agm_pool     (rn serial PRIMARY KEY, agid uuid UNIQUE);
CREATE TEMP TABLE IF NOT EXISTS _demo_poll_pool    (rn serial PRIMARY KEY, plid uuid UNIQUE);

-- ══════════════════════════════════════════════════════════════════════════════
-- §01  UNITS — G & H blocks (6 floors × 10 units × 2 blocks = 120 units)
-- ══════════════════════════════════════════════════════════════════════════════
DO $units$
DECLARE sid CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
BEGIN
  WITH ins AS (
    INSERT INTO units(society_id, unit_number, block, floor, area_sqft, unit_type, is_vacant)
    SELECT sid, b||'-'||f||lpad(u::text,2,'0'), b, f,
      CASE u WHEN 1 THEN 1080 WHEN 2 THEN 1080 WHEN 9 THEN 1540 WHEN 10 THEN 1540 ELSE 1350 END,
      CASE u WHEN 1 THEN '2BHK' WHEN 2 THEN '2BHK' WHEN 9 THEN '3BHK' WHEN 10 THEN '3BHK' ELSE '2.5BHK' END,
      (b='G' AND f=4 AND u=7)
    FROM (VALUES('G'),('H')) bl(b), generate_series(1,6) f, generate_series(1,10) u
    ON CONFLICT(society_id, unit_number) DO NOTHING
    RETURNING id
  ), pool AS (
    INSERT INTO _demo_unit_pool(uid) SELECT id FROM ins ON CONFLICT DO NOTHING RETURNING uid
  )
  INSERT INTO _demo_data_registry(tbl, record_id) SELECT 'units', uid::text FROM pool ON CONFLICT DO NOTHING;
  -- Ensure pool is complete on re-runs (units already existed)
  INSERT INTO _demo_unit_pool(uid)
    SELECT id FROM units WHERE block IN('G','H') AND society_id=sid
    ON CONFLICT DO NOTHING;
END $units$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §02  NOTICES — 30 notices across all 6 categories
-- ══════════════════════════════════════════════════════════════════════════════
DO $notices$
DECLARE
  sid CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  IF adm IS NULL THEN RAISE EXCEPTION 'No auth.users found — create a portal user first.'; END IF;

  WITH nd(cat, title, aud, pinned, dago) AS (VALUES
    ('Urgent',     'Water supply shutdown 15 May — pipeline repairs',              'all',    true,  3),
    ('Urgent',     'Heavy rain advisory — avoid basement parking during storms',   'all',    true,  8),
    ('Urgent',     'Gas leak safety drill — 20 Apr 2025 at 10 AM',               'all',    true,  20),
    ('Urgent',     'Pest control treatment on 22 May — common areas',             'all',    true,  -2),
    ('Urgent',     'Fake e-mail scam alert — never share OTP with anyone',        'all',    true,  9),
    ('Maintenance','G-Block lift maintenance — 16 May 2025, 9 AM–1 PM',          'all',    false, 2),
    ('Maintenance','Terrace waterproofing — H Block 19–23 May',                   'all',    false, 0),
    ('Maintenance','CCTV system upgrade — 4 new cameras installed',               'all',    false, 7),
    ('Maintenance','Swimming pool reopened after winter maintenance',              'all',    false, 14),
    ('Maintenance','Generator AMC quarterly service — 18 May 2025',              'all',    false, 1),
    ('Financial',  'Q1 FY2025-26 maintenance dues — due 15 Jun 2025',            'all',    true,  5),
    ('Financial',  'Corpus fund interest statement FY 2024-25 available',         'owners', false, 15),
    ('Financial',  'Penalty waiver window: 15–31 May 2025 — one time only',      'all',    true,  -7),
    ('Financial',  'FY 2023-24 audit report now published in Documents',          'owners', false, 90),
    ('Financial',  'GST reconciliation FY 2024-25 — GSTIN 36AAATU3456P1Z2',      'owners', false, 44),
    ('Events',     'Ugadi Celebrations — 30 Mar 2025 — cultural programme + lunch','all',  true,  40),
    ('Events',     'Sports Day 2025 — registrations open — 25 Jan 2025',          'all',    false, 60),
    ('Events',     'Yoga & Wellness Day — 21 Jun 2025 — free session 6–8 AM',    'all',    false, -30),
    ('Events',     'Summer Camp for Kids (6–14 yrs) — Batch 2 starts 9 Jun',     'all',    false, -28),
    ('Events',     'Sankranti Kite Flying Festival — 14 Jan 2025 — rooftop',     'all',    false, 110),
    ('Governance', '14th AGM minutes now published in Documents section',          'all',    false, 10),
    ('Governance', 'Election of new committee — nominations open until 30 Jun',   'owners', true,  28),
    ('Governance', 'Draft amended byelaw — public comment period ends 30 May',   'owners', false, -5),
    ('Governance', 'MC meeting minutes — April 2025 now published',              'all',    false, 6),
    ('Governance', 'Resolution: EV charging stations approved by committee',       'all',    true,  32),
    ('General',    'New security guard roster effective 1 April 2025',            'all',    false, 35),
    ('General',    'Pet policy reminder — registration mandatory at office',       'all',    false, 22),
    ('General',    'Visitor parking — new sticker system effective 1 May',        'all',    false, 16),
    ('General',    'Garbage collection timings updated — 6–8 AM & 5–7 PM',       'all',    false, 12),
    ('General',    'Rooftop solar feasibility study complete — 250 kWp viable',   'all',    false, 17)
  ),
  ins AS (
    INSERT INTO notices(society_id, title, category, target_audience, is_pinned,
                        is_published, published_at, requires_acknowledgement,
                        created_by, created_at, updated_at)
    SELECT sid, title, cat, aud, pinned, true,
           now()-(dago||' days')::interval,
           (cat = 'Governance'),
           adm, now(), now()
    FROM nd
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl, record_id) SELECT 'notices', id::text FROM ins ON CONFLICT DO NOTHING;
END $notices$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §03  COMPLAINTS — 120 complaints + 120 comments + 120 status history rows
-- ══════════════════════════════════════════════════════════════════════════════
DO $complaints$
DECLARE
  sid   CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm   uuid;
  uids  uuid[];
  psz   int;
  cid   uuid;
  n     int;
  cats  text[] := ARRAY['Plumbing','Electrical','Lift','Housekeeping','Security','CCTV','Garden','Sewage'];
  pris  text[] := ARRAY['Low','Medium','High','Critical'];
  stats text[] := ARRAY['Open','Assigned','In_Progress','Waiting_for_User','Resolved','Closed','Reopened'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT array_agg(uid ORDER BY rn) INTO uids FROM _demo_unit_pool;
  psz := array_length(uids, 1);

  FOR n IN 1..120 LOOP
    INSERT INTO complaints(society_id, ticket_number, title, category, priority, status,
                           raised_by, unit_id, sla_hours, created_at, updated_at)
    VALUES(
      sid,
      'DEMO-TKT-'||lpad(n::text,4,'0'),
      cats[((n-1)%8)+1]||' issue reported — '||(CASE n%2 WHEN 0 THEN 'G' ELSE 'H' END)||
        '-'||((n%6)+1)||lpad(((n%10)+1)::text,2,'0')||' (ref #'||n||')',
      cats[((n-1)%8)+1],
      pris[((n-1)%4)+1],
      stats[((n-1)%7)+1],
      adm,
      uids[((n-1)%psz)+1],
      CASE pris[((n-1)%4)+1] WHEN 'Critical' THEN 4 WHEN 'High' THEN 24 WHEN 'Medium' THEN 72 ELSE 168 END,
      now()-((121-n)||' days')::interval,
      now()-((121-n)||' days')::interval
    )
    ON CONFLICT(ticket_number) DO NOTHING
    RETURNING id INTO cid;

    IF cid IS NOT NULL THEN
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('complaints',cid::text) ON CONFLICT DO NOTHING;
      INSERT INTO complaint_comments(complaint_id, user_id, comment, is_internal, created_at)
        VALUES(cid, adm, 'Complaint logged and under review. Reference: DEMO-TKT-'||lpad(n::text,4,'0'),
               false, now()-((121-n)||' days')::interval+'1 hour'::interval);
      INSERT INTO complaint_status_history(complaint_id, old_status, new_status, changed_by, changed_at)
        VALUES(cid, NULL, 'Open', adm, now()-((121-n)||' days')::interval);
    END IF;
  END LOOP;
END $complaints$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §04  FINANCE — 5 billing periods + 600 dues + 100 payments + 8 categories + 50 expenses
-- ══════════════════════════════════════════════════════════════════════════════
DO $finance$
DECLARE
  sid   CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm   uuid;
  pid   uuid;
  n     int;
  pnames  text[]    := ARRAY['Q1 FY2024-25','Q2 FY2024-25','Q3 FY2024-25','Q4 FY2024-25','Q1 FY2025-26'];
  pstarts date[]    := ARRAY['2024-04-01','2024-07-01','2024-10-01','2025-01-01','2025-04-01'];
  pends   date[]    := ARRAY['2024-06-30','2024-09-30','2024-12-31','2025-03-31','2025-06-30'];
  pdues   date[]    := ARRAY['2024-05-15','2024-08-15','2024-11-15','2025-02-15','2025-05-15'];
  pamts   numeric[] := ARRAY[3500,3500,3500,3500,4000];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  -- Billing periods (5)
  FOR n IN 1..5 LOOP
    INSERT INTO billing_periods(society_id, name, start_date, end_date, due_date,
                                base_amount, is_active, created_at)
    VALUES(sid, pnames[n], pstarts[n], pends[n], pdues[n], pamts[n], n=5, now())
    ON CONFLICT DO NOTHING
    RETURNING id INTO pid;

    IF pid IS NOT NULL THEN
      INSERT INTO _demo_period_pool(rn, pid, amt, due_date) VALUES(n, pid, pamts[n], pdues[n])
        ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('billing_periods',pid::text)
        ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  -- Fill pool for re-runs
  INSERT INTO _demo_period_pool(rn, pid, amt, due_date)
    SELECT row_number() OVER(ORDER BY start_date)::int, id,
           base_amount, due_date
    FROM billing_periods WHERE society_id=sid AND name LIKE 'Q% FY20%'
    ON CONFLICT DO NOTHING;

  -- Maintenance dues: 5 periods × 120 units = 600 rows
  WITH ins AS (
    INSERT INTO maintenance_dues(society_id, unit_id, user_id, billing_period_id,
                                 base_amount, penalty_amount, gst_amount,
                                 status, due_date, created_at, updated_at)
    SELECT
      sid, u.uid,
      (SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
      p.pid,
      p.amt,
      CASE WHEN p.rn <= 2 AND u.rn > 80 THEN p.amt * 0.10 ELSE 0 END,
      p.amt * 0.18,
      CASE
        WHEN p.rn = 1                          THEN 'paid'
        WHEN p.rn = 2 AND u.rn <= 80          THEN 'paid'
        WHEN p.rn = 2                          THEN 'overdue'
        WHEN p.rn = 3 AND u.rn <= 60          THEN 'paid'
        WHEN p.rn = 3 AND u.rn <= 90          THEN 'overdue'
        WHEN p.rn = 3                          THEN 'partially_paid'
        WHEN p.rn = 4 AND u.rn <= 40          THEN 'paid'
        WHEN p.rn = 4 AND u.rn <= 80          THEN 'pending'
        WHEN p.rn = 4                          THEN 'overdue'
        WHEN p.rn = 5 AND u.rn <= 20          THEN 'paid'
        WHEN p.rn = 5 AND u.rn <= 90          THEN 'pending'
        ELSE 'overdue'
      END,
      p.due_date,
      now(), now()
    FROM _demo_unit_pool u, _demo_period_pool p
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'maintenance_dues',id::text FROM ins ON CONFLICT DO NOTHING;

  -- Expense categories (8)
  WITH cats(nm, gst, tds) AS (VALUES
    ('Housekeeping Services',true,true), ('Electrical Repairs',true,false),
    ('Plumbing Works',true,false),       ('Security Services',true,true),
    ('Landscaping',true,false),          ('Lift Maintenance',true,true),
    ('Administrative',false,false),      ('Miscellaneous',false,false)
  ), ins AS (
    INSERT INTO expense_categories(society_id, name, gst_applicable, tds_applicable)
    SELECT sid, nm, gst, tds FROM cats
    ON CONFLICT(society_id, name) DO NOTHING RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'expense_categories',id::text FROM ins ON CONFLICT DO NOTHING;

  -- Payments (100)
  WITH ins AS (
    INSERT INTO payments(society_id, user_id, amount, payment_mode, receipt_number, paid_at, created_at)
    SELECT
      sid,
      (SELECT id FROM auth.users ORDER BY created_at LIMIT 1),
      (ARRAY[3500,3500,4130,4130,4000,4720])[((gs-1)%6)+1],
      (ARRAY['cash','upi','upi','neft','cheque','rtgs'])[((gs-1)%6)+1],
      'DEMO-RCPT-'||lpad(gs::text,5,'0'),
      now()-((gs*3)||' days')::interval,
      now()-((gs*3)||' days')::interval
    FROM generate_series(1,100) gs
    ON CONFLICT(receipt_number) DO NOTHING RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'payments',id::text FROM ins ON CONFLICT DO NOTHING;

  -- Expenses (50)
  WITH ins AS (
    INSERT INTO expenses(society_id, description, amount, gst_amount, tds_deducted,
                         bill_date, payment_date, created_by, created_at)
    SELECT
      sid,
      (ARRAY[
        'Housekeeping agency monthly invoice',
        'Security guard salaries — monthly',
        'Electrical repair G-block lobby',
        'Plumbing — overhead tank connections',
        'Lift AMC monthly payment',
        'Garden maintenance contract',
        'DG set fuel refill',
        'CCTV repair & maintenance',
        'Pest control treatment — common areas',
        'Common area painting — H block'
      ])[((gs-1)%10)+1],
      (ARRAY[45000,85000,12500,8500,35000,22000,18000,9500,15000,42000])[((gs-1)%10)+1],
      (ARRAY[8100,0,2250,1530,6300,3960,0,1710,2700,7560])[((gs-1)%10)+1],
      (ARRAY[4500,8500,0,0,3500,0,0,0,0,4200])[((gs-1)%10)+1],
      (current_date-((gs*7)||' days')::interval)::date,
      (current_date-((gs*7-3)||' days')::interval)::date,
      adm, now()
    FROM generate_series(1,50) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'expenses',id::text FROM ins ON CONFLICT DO NOTHING;
END $finance$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §05  EVENTS — 15 events + 15 registrations (admin registers for all)
-- ══════════════════════════════════════════════════════════════════════════════
DO $events$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
  eid  uuid;
  n    int;
  titles   text[]      := ARRAY[
    'Ugadi Celebrations 2025','Diwali Cultural Evening 2024','Sports Day 2025',
    'Republic Day Flag Hoisting 2025','Sankranti Kite Flying Festival',
    'Children''s Day Painting Contest','Yoga & Wellness Day 2025',
    'Senior Citizens Health Camp','Summer Camp for Kids 2025',
    '14th Annual General Meeting','Navratri Garba Night 2024',
    'Mothers'' Day Brunch 2025','Winter Carnival 2024',
    'Independence Day 2025','Society Founders'' Day Celebration'];
  starts   timestamptz[] := ARRAY[
    '2025-03-30 17:00+05:30','2024-10-30 19:00+05:30','2025-01-25 08:00+05:30',
    '2025-01-26 08:00+05:30','2025-01-14 10:00+05:30','2024-11-14 10:00+05:30',
    '2025-06-21 06:00+05:30','2024-12-05 09:00+05:30','2025-05-05 09:00+05:30',
    '2025-03-15 10:00+05:30','2024-10-10 19:00+05:30','2025-05-11 11:00+05:30',
    '2024-12-20 17:00+05:30','2025-08-15 08:00+05:30','2025-06-01 17:00+05:30'];
  caps     int[]       := ARRAY[500,500,200,300,200,100,200,100,50,200,400,80,300,300,200];
  is_paid  boolean[]   := ARRAY[false,false,false,false,false,false,false,false,true,false,false,true,false,false,false];
  prices   numeric[]   := ARRAY[0,0,0,0,0,0,0,0,200,0,0,500,0,0,0];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..15 LOOP
    INSERT INTO events(society_id, title, starts_at, ends_at, capacity,
                       is_paid, ticket_price, is_published, created_by, created_at, updated_at)
    VALUES(sid, titles[n], starts[n], starts[n]+'4 hours'::interval, caps[n],
           is_paid[n], prices[n], true, adm, now(), now())
    RETURNING id INTO eid;

    IF eid IS NOT NULL THEN
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('events',eid::text) ON CONFLICT DO NOTHING;
      -- One registration per event by admin
      INSERT INTO event_registrations(event_id, user_id, attendees_count, status, registered_at)
      VALUES(eid, adm, 1, 'registered', now())
      ON CONFLICT(event_id, user_id) DO NOTHING;
    END IF;
  END LOOP;
END $events$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §06  POLLS — 15 polls + 60 options (4 per poll) + 15 votes
-- ══════════════════════════════════════════════════════════════════════════════
DO $polls$
DECLARE
  sid    CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm    uuid;
  plid   uuid;
  n      int;
  titles text[] := ARRAY[
    'Monthly maintenance revision 2025-26',
    'EV charging station installation in basement',
    'New security agency selection',
    'Swimming pool renovation proposal',
    'Sunday organic market on campus',
    'New gymnasium equipment purchase',
    'Guest parking policy revision',
    'Exterior repainting — colour selection',
    'Diwali 2025 decoration budget approval',
    'Rooftop solar panel installation (250 kWp)',
    'Pet registration policy for society',
    'CCTV camera expansion — 12 additional',
    'Garden maintenance frequency (weekly vs fortnightly)',
    'Community hall booking fee revision',
    'Society monthly newsletter launch'];
  ptypes text[] := ARRAY[
    'single_choice','yes_no','single_choice','yes_no','yes_no',
    'yes_no','single_choice','single_choice','yes_no','yes_no',
    'yes_no','yes_no','single_choice','single_choice','yes_no'];
  opt1   text[] := ARRAY[
    'Increase to ₹4,500/quarter','Yes — proceed with installation','Sri Balaji Security Services',
    'Yes — approve ₹8 lakh budget','Yes — open every Sunday','Yes — purchase new equipment',
    'Allow max 2 visitor vehicles/flat','Terracotta & Cream','Yes — approve ₹50,000 budget',
    'Yes — approve project','Yes — mandatory registration required','Yes — approve expansion',
    'Weekly maintenance','Increase to ₹3,000 per session','Yes — launch monthly newsletter'];
  opt2   text[] := ARRAY[
    'Increase to ₹5,000/quarter','No — defer to next AGM','Hyderabad Security Pvt Ltd',
    'No — current pool is adequate','No — security concerns','No — current equipment is fine',
    'Restrict to pre-registered vehicles','Grey & White','No — reduce budget to ₹30,000',
    'No — too expensive','No — self-regulation is sufficient','No — current coverage adequate',
    'Fortnightly maintenance','Keep at ₹1,500 per session','No — not required'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..15 LOOP
    INSERT INTO polls(society_id, title, poll_type, scope, is_anonymous, one_vote_per_unit,
                      is_published, result_visibility, created_by, created_at,
                      starts_at, ends_at)
    VALUES(sid, titles[n], ptypes[n], 'all_members', false, true, true,
           'after_close', adm, now()-((15-n)||' days')::interval,
           now()-((16-n)||' days')::interval,
           now()+((n*3)||' days')::interval)
    RETURNING id INTO plid;

    IF plid IS NOT NULL THEN
      INSERT INTO _demo_poll_pool(plid) VALUES(plid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('polls',plid::text) ON CONFLICT DO NOTHING;

      -- 4 options per poll
      INSERT INTO poll_options(poll_id, option_text, order_index) VALUES
        (plid, opt1[n], 0),
        (plid, opt2[n], 1),
        (plid, 'Abstain / Need more information', 2),
        (plid, 'Defer to AGM for decision', 3);

      -- Admin votes on first option
      INSERT INTO poll_votes(poll_id, option_id, user_id, voted_at)
      SELECT plid, id, adm, now()
      FROM poll_options WHERE poll_id=plid ORDER BY order_index LIMIT 1
      ON CONFLICT(poll_id, user_id) DO NOTHING;
    END IF;
  END LOOP;
END $polls$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §07  FACILITIES — 5 facilities + 100 bookings (20 per facility)
-- ══════════════════════════════════════════════════════════════════════════════
DO $facilities$
DECLARE
  sid    CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm    uuid;
  fid    uuid;
  first_unit uuid;
  n      int;
  d      int;
  fnames text[]   := ARRAY['Community Hall','Swimming Pool','Gymnasium','Badminton Court','Children''s Play Area'];
  fcaps  int[]    := ARRAY[200, 30, 20, 8, 50];
  ffees  numeric[]  := ARRAY[2000, 0, 0, 0, 0];
  fstats text[]   := ARRAY['confirmed','confirmed','completed','cancelled','in_use','no_show','confirmed','completed'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT uid INTO first_unit FROM _demo_unit_pool WHERE rn=1;

  FOR n IN 1..5 LOOP
    INSERT INTO facilities(society_id, name, description, capacity, booking_fee,
                           deposit_amount, is_active, advance_booking_days,
                           cancellation_hours_free, created_at)
    VALUES(sid, fnames[n], fnames[n]||' — available for resident bookings',
           fcaps[n], ffees[n], 0, true, 30, 24, now())
    RETURNING id INTO fid;

    IF fid IS NOT NULL THEN
      INSERT INTO _demo_facility_pool(fid) VALUES(fid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('facilities',fid::text) ON CONFLICT DO NOTHING;

      -- 20 bookings for this facility (one per day, different dates)
      FOR d IN 1..20 LOOP
        INSERT INTO facility_bookings(society_id, facility_id, user_id, unit_id,
                                      booking_date, start_time, end_time, attendees_count,
                                      purpose, status, fee_charged, deposit_paid,
                                      deposit_refunded, created_at, updated_at)
        SELECT sid, fid, adm, first_unit,
               current_date - d,
               ((current_date - d)::timestamp + '09:00'::interval)::timestamptz,
               ((current_date - d)::timestamp + '11:00'::interval)::timestamptz,
               (ARRAY[2,3,5,8,10,15,20])[((d-1)%7)+1],
               (ARRAY['Family gathering','Birthday celebration','Society event','Workout session',
                      'Yoga class','Kids party','Community meeting','Sports practice'])[((d-1)%8)+1],
               fstats[((d-1)%8)+1],
               ffees[n], 0, false, now(), now()
        WHERE NOT EXISTS (
          SELECT 1 FROM facility_bookings fb
          WHERE fb.facility_id=fid
            AND fb.start_time = ((current_date - d)::timestamp + '09:00'::interval)::timestamptz
        );
      END LOOP;
    END IF;
  END LOOP;

  INSERT INTO _demo_data_registry(tbl,record_id)
  SELECT 'facility_bookings', id::text
  FROM facility_bookings
  WHERE unit_id=first_unit AND society_id=sid
    AND created_at >= (now() - interval '1 minute')
  ON CONFLICT DO NOTHING;
END $facilities$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §08  VENDORS — 12 vendors + 40 work orders
-- ══════════════════════════════════════════════════════════════════════════════
DO $vendors$
DECLARE
  sid    CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm    uuid;
  vid    uuid;
  wid    uuid;
  n      int;
  vnames text[] := ARRAY[
    'Sri Balaji Plumbing Works','Lakshmi Electricals & Power Solutions',
    'Hyderabad Fire & Safety Services','Kone Elevator Maintenance Services',
    'Green Thumb Landscape & Horticulture','Pest Away Fumigation Services',
    'Crystal Clear Housekeeping Services','Sai Security & Surveillance Systems',
    'Deccan Civil & Construction Works','Urban Infra Maintenance Services',
    'Techno CCTV & Access Control','Cool Air HVAC Services'];
  vcats text[] := ARRAY[
    'Plumbing','Electrical','Security','Lift','Landscaping','Pest_Control',
    'Housekeeping','Security','Civil','Other','CCTV','Other'];
  wo_titles text[] := ARRAY[
    'Monthly plumbing inspection & repair','Electrical panel servicing',
    'Fire alarm system annual testing','Elevator servicing — G Block',
    'Quarterly garden maintenance','Pest treatment — common areas',
    'Housekeeping monthly contract','Security patrol review',
    'Compound wall crack repair','Water tank cleaning',
    'CCTV footage retrieval request','AC servicing — club house'];
  wo_stats text[] := ARRAY['completed','in_progress','issued','draft','completed','closed','completed','in_progress'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..12 LOOP
    INSERT INTO vendors(society_id, name, category, contact_person,
                        phone, is_active, created_at)
    VALUES(sid, vnames[n], vcats[n],
           (ARRAY['Ramu Rao','Suresh K','Balu Naidu','Ramesh G','Krishna Rao','Venkat P',
                  'Sunita Devi','Rajan Nair','Prasad B','Mohan R','Vikram S','Srinivas T'])[n],
           '98'||lpad((n*7654321%100000000)::text,8,'0'),
           n != 10, now()-((60+n)||' days')::interval)
    RETURNING id INTO vid;

    IF vid IS NOT NULL THEN
      INSERT INTO _demo_vendor_pool(vid) VALUES(vid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('vendors',vid::text) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;

  -- 40 work orders (cycling through vendors)
  WITH vpool AS (SELECT _demo_vendor_pool.vid AS v_id, _demo_vendor_pool.rn FROM _demo_vendor_pool),
  ins AS (
    INSERT INTO work_orders(society_id, vendor_id, title, description, status,
                            quoted_amount, created_by, created_at, updated_at)
    SELECT
      sid,
      (SELECT v_id FROM vpool WHERE rn = ((gs-1)%12)+1),
      wo_titles[((gs-1)%12)+1]||' — order #'||gs,
      'Scheduled work order #'||gs||' as per AMC / requirement.',
      wo_stats[((gs-1)%8)+1],
      (ARRAY[15000,45000,12000,35000,22000,9000,85000,35000])[((gs-1)%8)+1],
      adm,
      now()-((40-gs)||' days')::interval,
      now()-((40-gs)||' days')::interval
    FROM generate_series(1,40) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'work_orders',id::text FROM ins ON CONFLICT DO NOTHING;
END $vendors$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §09  COMMUNITY — 50 posts + 50 comments + 30 marketplace listings
-- ══════════════════════════════════════════════════════════════════════════════
DO $community$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
  first_unit uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT uid INTO first_unit FROM _demo_unit_pool WHERE rn=1;

  -- 50 community posts
  WITH ins AS (
    INSERT INTO community_posts(society_id, author_id, unit_id, category, title, body,
                                is_published, view_count, created_at, updated_at)
    SELECT sid, adm, first_unit,
      (ARRAY['General','Help','Lost_Found','Recommendation','Alert'])[((gs-1)%5)+1],
      CASE (gs-1)%5
        WHEN 0 THEN 'General notice from G-'||((gs%6)+1)||lpad(((gs%10)+1)::text,2,'0')
        WHEN 1 THEN 'Looking for help with flat shifting — anyone available?'
        WHEN 2 THEN 'Lost: '||(ARRAY['House keys near G lobby','Black umbrella near lift',
                    'Child''s water bottle at play area','Blue helmet near parking',
                    'Spectacles near gym'])[((gs-1)%5)+1]
        WHEN 3 THEN 'Recommendation: '||(ARRAY['Excellent plumber — Ramu 98765','Great tutor for maths',
                    'Trusted cab driver for airport','Best tiffin service near society'])[((gs-1)%4)+1]
        ELSE        'Alert: '||(ARRAY['Unknown vehicle parked in slot','Suspicious activity near gate',
                    'Power cut expected tonight','Water leakage on terrace'])[((gs-1)%4)+1]
      END,
      'Community post #'||gs||' — shared for awareness of all residents.',
      true, (gs*7 % 150), now()-((50-gs)||' days')::interval, now()-((50-gs)||' days')::interval
    FROM generate_series(1,50) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'community_posts',id::text FROM ins ON CONFLICT DO NOTHING;

  -- 50 comments (one per post)
  WITH posts AS (SELECT id, row_number() OVER(ORDER BY created_at) rn FROM community_posts WHERE society_id=sid AND author_id=adm),
  ins AS (
    INSERT INTO post_comments(post_id, author_id, body, created_at)
    SELECT p.id, adm,
      'Thank you for sharing this. Will be noted by the committee. — Admin',
      now()-((50-p.rn)||' days')::interval+'2 hours'::interval
    FROM posts p RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'post_comments',id::text FROM ins ON CONFLICT DO NOTHING;

  -- 30 marketplace listings
  WITH ins AS (
    INSERT INTO marketplace_listings(society_id, seller_id, unit_id, category, title,
                                     description, price, status, contact_preference, created_at, updated_at)
    SELECT sid, adm, first_unit,
      (ARRAY['Electronics','Furniture','Books','Vehicles','Services','Baby_Items','Other'])[((gs-1)%7)+1],
      (ARRAY[
        'Samsung 32" TV — excellent condition','Wooden dining table 6-seater',
        'CBSE textbooks Grade 8 (full set)','Honda Activa 2020 — well maintained',
        'Maths tuition — Grade 6–10','Baby walker — barely used',
        'Treadmill — 2 years old, works well','LG washing machine 7kg',
        'Sofa set 3+1+1 — good condition','Engineering competitive books',
        'Electric scooter for sale','Yoga classes — morning batch',
        'Baby crib with mattress','AC 1.5 ton inverter 3 star',
        'Bookshelf — solid wood'])[((gs-1)%15)+1],
      'For sale. Good condition. Negotiable for society members. Contact via portal.',
      (ARRAY[8000,15000,1200,65000,500,3500,18000,12000,22000,800,75000,0,5000,28000,6000])[((gs-1)%15)+1],
      (ARRAY['active','active','active','sold','active','active','active'])[((gs-1)%7)+1],
      'in_app',
      now()-((30-gs)||' days')::interval, now()-((30-gs)||' days')::interval
    FROM generate_series(1,30) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'marketplace_listings',id::text FROM ins ON CONFLICT DO NOTHING;
END $community$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §10  PARKING — 60 slots + 50 active allocations + 5 waitlist entries
-- ══════════════════════════════════════════════════════════════════════════════
DO $parking$
DECLARE
  sid    CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm    uuid;
  slid   uuid;
  alloc_id uuid;
  uids   uuid[];
  psz    int;
  n      int;
  s_types text[] := ARRAY['covered','covered','open','basement'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT array_agg(uid ORDER BY rn) INTO uids FROM _demo_unit_pool;
  psz := array_length(uids,1);

  -- 60 parking slots (C-01..30 covered, O-01..20 open, B-01..10 basement)
  FOR n IN 1..30 LOOP
    INSERT INTO parking_slots(society_id, slot_number, slot_type, vehicle_type,
                               level, is_active, created_at)
    VALUES(sid, 'C-'||lpad(n::text,2,'0'), 'covered', 'car', 1, true, now())
    ON CONFLICT(society_id, slot_number) DO NOTHING RETURNING id INTO slid;
    IF slid IS NOT NULL THEN
      INSERT INTO _demo_slot_pool(slid) VALUES(slid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('parking_slots',slid::text) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  FOR n IN 1..20 LOOP
    INSERT INTO parking_slots(society_id, slot_number, slot_type, vehicle_type,
                               level, is_active, created_at)
    VALUES(sid, 'O-'||lpad(n::text,2,'0'), 'open', 'car', 0, true, now())
    ON CONFLICT(society_id, slot_number) DO NOTHING RETURNING id INTO slid;
    IF slid IS NOT NULL THEN
      INSERT INTO _demo_slot_pool(slid) VALUES(slid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('parking_slots',slid::text) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  FOR n IN 1..10 LOOP
    INSERT INTO parking_slots(society_id, slot_number, slot_type, vehicle_type,
                               level, is_active, created_at)
    VALUES(sid, 'B-'||lpad(n::text,2,'0'), 'basement', 'car', -1, true, now())
    ON CONFLICT(society_id, slot_number) DO NOTHING RETURNING id INTO slid;
    IF slid IS NOT NULL THEN
      INSERT INTO _demo_slot_pool(slid) VALUES(slid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('parking_slots',slid::text) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  -- Fill pool on rerun
  INSERT INTO _demo_slot_pool(slid) SELECT id FROM parking_slots WHERE society_id=sid ON CONFLICT DO NOTHING;

  -- 50 active allocations (first 50 slots get one allocation each)
  FOR n IN 1..50 LOOP
    SELECT _demo_slot_pool.slid INTO slid FROM _demo_slot_pool WHERE rn=n;
    INSERT INTO parking_allocations(society_id, slot_id, unit_id, user_id,
                                    vehicle_number, vehicle_make, status,
                                    allocated_by, allocated_at, created_at, updated_at)
    VALUES(sid, slid, uids[((n-1)%psz)+1], adm,
           'TS'||lpad(((n*1234)%10000)::text,4,'0')||(ARRAY['AB','CD','EF','GH','KL'])[((n-1)%5)+1],
           (ARRAY['Maruti Swift','Hyundai i20','Honda City','Tata Nexon','Kia Sonet',
                  'Toyota Innova','Maruti Ertiga','MG Hector','Honda Activa','TVS Jupiter'])[((n-1)%10)+1],
           'active', adm, now()-((200-n)||' days')::interval,
           now()-((200-n)||' days')::interval, now()-((200-n)||' days')::interval)
    ON CONFLICT DO NOTHING
    RETURNING id INTO alloc_id;
    IF alloc_id IS NOT NULL THEN
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('parking_allocations',alloc_id::text) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END $parking$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §11  AGM — 5 sessions + 15 documents + 15 resolutions
-- ══════════════════════════════════════════════════════════════════════════════
DO $agm$
DECLARE
  sid   CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm   uuid;
  agid  uuid;
  docid uuid;
  resid uuid;
  n     int;
  d     int;
  ayears  int[]  := ARRAY[2021,2022,2023,2024,2024];
  atypes  text[] := ARRAY['annual','annual','annual','annual','extraordinary'];
  mdates  date[] := ARRAY['2022-05-20','2023-04-30','2024-05-12','2025-03-15','2024-10-05'];
  attendees int[] := ARRAY[62,70,74,81,35];
  doc_types text[] := ARRAY['minutes','financial_statement','audit_report'];
  res_titles text[] := ARRAY[
    'Approval of previous AGM minutes and accounts',
    'Adoption of annual accounts and auditor report',
    'Re-appointment of society auditor for FY 2024-25',
    'Approval of maintenance revision from ₹3500 to ₹4000',
    'Approval of EV charging station installation',
    'Election of managing committee members 2025-28',
    'Ratification of corpus fund investments',
    'Approval of CCTV expansion project',
    'Adoption of revised pet policy',
    'Rooftop solar panel project sanctioned',
    'Approval of terrace waterproofing contract',
    'Ratification of emergency STP repair expenses',
    'Amendment to byelaw clause 4.16 — proxy voting',
    'Approval of society repainting project',
    'Appointment of legal counsel for RERA matters'];
  res_stats text[] := ARRAY['passed','passed','passed','passed','passed','passed','passed',
                             'passed','defeated','passed','passed','passed','passed','deferred','passed'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..5 LOOP
    INSERT INTO agm_sessions(society_id, agm_year, agm_type, meeting_date,
                              venue, status, quorum_met, attendees_count,
                              created_by, created_at, updated_at)
    VALUES(sid, ayears[n], atypes[n], mdates[n],
           'Community Hall, UTA MACS Society', 'held', true, attendees[n],
           adm, now(), now())
    ON CONFLICT(society_id, agm_year, agm_type) DO NOTHING
    RETURNING id INTO agid;

    IF agid IS NOT NULL THEN
      INSERT INTO _demo_agm_pool(agid) VALUES(agid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('agm_sessions',agid::text) ON CONFLICT DO NOTHING;

      -- 3 documents per session
      FOR d IN 1..3 LOOP
        INSERT INTO agm_documents(society_id, agm_session_id, document_type, title,
                                  status, version, is_public, submitted_by,
                                  submitted_at, created_by, created_at, updated_at)
        VALUES(sid, agid, doc_types[d],
               doc_types[d]||' — '||ayears[n]||' ('||atypes[n]||')',
               'approved', 1, true, adm, mdates[n]::timestamptz, adm, now(), now())
        RETURNING id INTO docid;
        IF docid IS NOT NULL THEN
          INSERT INTO _demo_data_registry(tbl,record_id) VALUES('agm_documents',docid::text) ON CONFLICT DO NOTHING;
        END IF;
      END LOOP;

      -- 3 resolutions per session
      FOR d IN 1..3 LOOP
        INSERT INTO agm_resolutions(society_id, agm_session_id, resolution_no, title,
                                    resolution_type, status, votes_for, votes_against,
                                    votes_abstain, passed_at, created_at)
        VALUES(sid, agid, 'RES/'||ayears[n]||'/'||d,
               res_titles[((n-1)*3+d-1)%15+1],
               'ordinary',
               res_stats[((n-1)*3+d-1)%15+1],
               (ARRAY[60,68,55,72,25])[n], (ARRAY[2,2,15,4,10])[n], (ARRAY[0,0,4,5,0])[n],
               mdates[n]::timestamptz, now())
        RETURNING id INTO resid;
        IF resid IS NOT NULL THEN
          INSERT INTO _demo_data_registry(tbl,record_id) VALUES('agm_resolutions',resid::text) ON CONFLICT DO NOTHING;
        END IF;
      END LOOP;
    END IF;
  END LOOP;
END $agm$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §12  MAIDS — 20 maids + 40 unit approvals + 100 attendance records
-- ══════════════════════════════════════════════════════════════════════════════
DO $maids$
DECLARE
  sid   CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm   uuid;
  mid   uuid;
  unit1 uuid;
  unit2 uuid;
  n     int;
  d     int;
  mnames text[] := ARRAY[
    'Radha Bai','Sunita Kumari','Kalavathi','Padmaja','Ratna Bai',
    'Yellamma','Saraswathi','Meera Devi','Lakshmidevi','Parvathi',
    'Kamala Bai','Susheela','Nagamani','Rajeshwari','Jyothi',
    'Anuradha','Bhagyalakshmi','Tulasi Devi','Vasudha','Indira'];
  wtypes text[] := ARRAY['cleaning','cooking','cleaning','elder_care','cleaning',
                          'laundry','cleaning','babysitting','cleaning','multiple',
                          'cleaning','cooking','cleaning','gardening','cleaning',
                          'laundry','cleaning','babysitting','cleaning','multiple'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..20 LOOP
    INSERT INTO maids(society_id, full_name, work_type, is_active,
                      police_verified, registered_at, created_at)
    VALUES(sid, mnames[n], wtypes[n], n<=17, n<=12,
           now()-((200-n*8)||' days')::interval,
           now()-((200-n*8)||' days')::interval)
    RETURNING id INTO mid;

    IF mid IS NOT NULL THEN
      INSERT INTO _demo_maid_pool(mid) VALUES(mid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('maids',mid::text) ON CONFLICT DO NOTHING;

      -- 2 unit approvals per maid
      SELECT uid INTO unit1 FROM _demo_unit_pool WHERE rn = ((n-1)*2+1);
      SELECT uid INTO unit2 FROM _demo_unit_pool WHERE rn = ((n-1)*2+2);

      INSERT INTO maid_unit_approvals(society_id, maid_id, unit_id, is_active,
                                       approved_by, approved_at, created_at)
      VALUES(sid, mid, unit1, true, adm, now()-((200-n*8)||' days')::interval+'1 hour'::interval, now())
      ON CONFLICT(maid_id, unit_id) DO NOTHING;

      INSERT INTO maid_unit_approvals(society_id, maid_id, unit_id, is_active,
                                       approved_by, approved_at, created_at)
      VALUES(sid, mid, unit2, true, adm, now()-((200-n*8)||' days')::interval+'2 hours'::interval, now())
      ON CONFLICT(maid_id, unit_id) DO NOTHING;

      -- 5 attendance days per maid → 100 total
      FOR d IN 1..5 LOOP
        INSERT INTO maid_attendance(society_id, maid_id, unit_id, date,
                                    entry_time, exit_time, created_at)
        VALUES(sid, mid, unit1, current_date-d,
               '08:00'::timetz, '11:00'::timetz, now())
        ON CONFLICT(maid_id, unit_id, date) DO NOTHING;
      END LOOP;
    END IF;
  END LOOP;

  INSERT INTO _demo_data_registry(tbl,record_id)
    SELECT 'maid_unit_approvals', id::text FROM maid_unit_approvals WHERE society_id=sid
      AND created_at >= (now()-interval'1 minute') ON CONFLICT DO NOTHING;
  INSERT INTO _demo_data_registry(tbl,record_id)
    SELECT 'maid_attendance', id::text FROM maid_attendance WHERE society_id=sid
      AND created_at >= (now()-interval'1 minute') ON CONFLICT DO NOTHING;
END $maids$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §13  GALLERY — 8 albums + 60 photos (~7–8 per album)
-- ══════════════════════════════════════════════════════════════════════════════
DO $gallery$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
  aid  uuid;
  n    int;
  p    int;
  anames text[] := ARRAY[
    'Ugadi Celebrations 2025','Sports Day 2025','Diwali Night 2024',
    'Republic Day 2025','Garden & Infrastructure','Club House & Amenities',
    'Community Events 2024','Society Life'];
  adates date[] := ARRAY[
    '2025-03-30','2025-01-25','2024-10-30','2025-01-26',
    '2024-12-15','2024-11-20','2024-09-15','2024-08-01'];
  photos_per_album int[] := ARRAY[10,8,8,7,8,7,7,5];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..8 LOOP
    INSERT INTO gallery_albums(society_id, title, description, is_public,
                                event_date, created_by, created_at)
    VALUES(sid, anames[n], anames[n]||' — photo album', true,
           adates[n], adm, now())
    RETURNING id INTO aid;

    IF aid IS NOT NULL THEN
      INSERT INTO _demo_album_pool(aid) VALUES(aid) ON CONFLICT DO NOTHING;
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('gallery_albums',aid::text) ON CONFLICT DO NOTHING;

      FOR p IN 1..photos_per_album[n] LOOP
        INSERT INTO gallery_photos(society_id, album_id, storage_key,
                                   caption, uploaded_by, created_at)
        VALUES(sid, aid,
               'media/gallery/'||aid::text||'/demo-photo-'||lpad(p::text,3,'0')||'.jpg',
               anames[n]||' — photo '||p,
               adm, now());
      END LOOP;

      UPDATE gallery_albums SET photo_count=photos_per_album[n] WHERE id=aid;
    END IF;
  END LOOP;

  INSERT INTO _demo_data_registry(tbl,record_id)
    SELECT 'gallery_photos', id::text FROM gallery_photos gp
    WHERE gp.uploaded_by=adm AND gp.society_id=sid
      AND gp.created_at>=(now()-interval'1 minute')
    ON CONFLICT DO NOTHING;
END $gallery$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §14  FEEDBACK — 100 feedback records across all categories and statuses
-- ══════════════════════════════════════════════════════════════════════════════
DO $feedback$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
  first_unit uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT uid INTO first_unit FROM _demo_unit_pool WHERE rn=1;

  WITH ins AS (
    INSERT INTO feedbacks(society_id, category, subject, body, status, priority,
                          is_anonymous, rating, submitted_by, unit_id, created_at, updated_at)
    SELECT
      sid,
      (ARRAY['general','maintenance','safety','amenities','management','events','other'])[((gs-1)%7)+1],
      (ARRAY[
        'Overall society management is excellent',
        'Water pressure very low in mornings',
        'Lights not working near G-block staircase',
        'Swimming pool maintenance could be better',
        'Committee communication is timely and clear',
        'Ugadi event was beautifully organised',
        'Garbage pickup timings need adjustment',
        'Security staff are professional and courteous',
        'Lift in H block makes grinding noise',
        'Garden looks well maintained',
        'Monthly meeting minutes shared promptly',
        'Parking allocation process is fair',
        'Children''s play area needs new swings',
        'Festival celebrations are inclusive',
        'Internet connectivity in common areas needed'
      ])[((gs-1)%15)+1],
      'Detailed feedback #'||gs||'. This has been noted by the management team for review and necessary action will be taken at the earliest.',
      (ARRAY['open','acknowledged','in_progress','resolved','closed'])[((gs-1)%5)+1],
      (ARRAY['low','normal','normal','high','urgent'])[((gs-1)%5)+1],
      (gs % 5 = 0),   -- every 5th is anonymous
      (ARRAY[5,4,3,4,5,4,3,5,2,4,5,4,3,5,4])[((gs-1)%15)+1],
      adm, first_unit,
      now()-((100-gs)||' days')::interval,
      now()-((100-gs)||' days')::interval
    FROM generate_series(1,100) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'feedbacks',id::text FROM ins ON CONFLICT DO NOTHING;
END $feedback$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §15  WATER TANKERS — 104 records (~2 years of weekly deliveries)
-- ══════════════════════════════════════════════════════════════════════════════
DO $tankers$
DECLARE sid CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
        adm uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  WITH ins AS (
    INSERT INTO water_tankers(society_id, delivery_date, supplier_name,
                               tanker_capacity_kl, tanker_count, cost_per_kl,
                               total_cost, payment_mode, created_by, created_at)
    SELECT
      sid,
      current_date - (gs*7),
      (ARRAY['Aqua Clear Water Services','Krishna Water Supplies','Sri Venkateswara Tankers'])[((gs-1)%3)+1],
      (ARRAY[10,12,15,10,12])[((gs-1)%5)+1],
      (ARRAY[1,2,1,2,3])[((gs-1)%5)+1],
      (ARRAY[450,480,420,450,480])[((gs-1)%5)+1],
      (ARRAY[10,12,15,10,12])[((gs-1)%5)+1] * (ARRAY[1,2,1,2,3])[((gs-1)%5)+1] * (ARRAY[450,480,420,450,480])[((gs-1)%5)+1],
      (ARRAY['cash','upi','bank_transfer'])[((gs-1)%3)+1],
      adm, now()
    FROM generate_series(1,104) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'water_tankers',id::text FROM ins ON CONFLICT DO NOTHING;
END $tankers$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §16  PATROL LOGS — 100 records (100 days, cycling shifts and guards)
-- ══════════════════════════════════════════════════════════════════════════════
DO $patrol$
DECLARE sid CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
        adm uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  WITH ins AS (
    INSERT INTO patrol_logs(society_id, patrol_date, shift, guard_name,
                             start_time, end_time, is_incident,
                             incidents, remarks, created_by, created_at)
    SELECT
      sid,
      current_date - gs,
      (ARRAY['morning','afternoon','evening','night','full_day'])[((gs-1)%5)+1],
      (ARRAY['Ramaiah Goud','Krishna Kumar','Suresh Yadav','Mahesh Babu','Venkatesh Naik'])[((gs-1)%5)+1],
      (ARRAY['06:00','14:00','18:00','22:00','06:00'])[((gs-1)%5)+1]::time,
      (ARRAY['14:00','22:00','22:00','06:00','06:00'])[((gs-1)%5)+1]::time,
      (gs % 10 = 0),   -- every 10th day has an incident
      CASE WHEN gs%10=0 THEN 'Suspicious vehicle near Gate 2 at 02:15 AM. Police informed. Plates noted: TS08-AB-1234.' ELSE NULL END,
      'Routine patrol completed. All checkpoints covered. No issues.',
      adm, now()
    FROM generate_series(1,100) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'patrol_logs',id::text FROM ins ON CONFLICT DO NOTHING;
END $patrol$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §17  TENANT KYC — 30 records (H-block tenants)
-- ══════════════════════════════════════════════════════════════════════════════
DO $tenantkyc$
DECLARE
  sid   CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm   uuid;
  uids  uuid[];
  psz   int;
  n     int;
  tnames text[] := ARRAY[
    'Ravi Kumar Sharma','Priya Krishnamurthy','Sanjay Reddy','Meena Nair','Arjun Rao',
    'Deepika Goud','Sunil Patel','Kavitha Iyengar','Rajesh Naidu','Sunita Kumari',
    'Venkat Rao','Anita Raju','Manish Gupta','Lakshmi Prasad','Kiran Kumar',
    'Nalini Devi','Harish Chandra','Sweta Mishra','Naveen Reddy','Padma Rao',
    'Arun Sinha','Usha Devi','Girish Nair','Rekha Goud','Suresh Sharma',
    'Bhavana Reddy','Mohan Rao','Savitha Naidu','Pradeep Kumar','Nirmala Devi'];
  kstats text[] := ARRAY['completed','completed','completed','completed','completed',
                          'completed','completed','completed','completed','completed',
                          'police_verified','police_verified','police_verified','police_verified','police_verified',
                          'police_verified','police_verified','police_verified',
                          'submitted','submitted','submitted','submitted','submitted','submitted','submitted',
                          'pending','pending','pending','pending','expired'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT array_agg(uid ORDER BY rn) INTO uids FROM _demo_unit_pool;
  psz := array_length(uids,1);

  FOR n IN 1..30 LOOP
    WITH ins AS (
      INSERT INTO tenant_kyc(society_id, unit_id, full_name, tenancy_start_date,
                              tenancy_end_date, monthly_rent, nationality,
                              police_verified, owner_consent, status,
                              created_by, created_at, updated_at)
      VALUES(sid,
             uids[60+n],   -- use H-block units (rn 61-90)
             tnames[n],
             (current_date - ((30-n)*30))::date,
             (current_date + '11 months'::interval)::date,
             (ARRAY[12000,15000,18000,20000,25000])[((n-1)%5)+1],
             'Indian',
             kstats[n] IN ('completed','police_verified'),
             kstats[n] != 'pending',
             kstats[n],
             adm, now(), now()
      )
      RETURNING id
    )
    INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'tenant_kyc',id::text FROM ins ON CONFLICT DO NOTHING;
  END LOOP;
END $tenantkyc$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §18  MEMBERSHIPS — 60 memberships for G-block units
-- ══════════════════════════════════════════════════════════════════════════════
DO $memberships$
DECLARE
  sid   CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm   uuid;
  uids  uuid[];
  n     int;
  mnames text[] := ARRAY[
    'Venkata Ramaiah Goud','Padmalatha Reddy','Krishna Chaitanya Rao','Suresh Kumar Nair',
    'Anitha Sriram','Narasimha Reddy','Lakshmi Prasad Murthy','Chandra Sekhar Rao',
    'Srinivasa Murthy','Bhavana Devi','Ravi Teja Rao','Swetha Goud',
    'Praveen Kumar Sharma','Usha Rani Nair','Mahesh Babu Reddy','Kavitha Krishnamurthy',
    'Ramakrishna Yadav','Sudha Rani','Vijay Kumar','Meenakshi Sundaram',
    'Arun Kumar Reddy','Deepa Rao','Ganesh Prasad','Sujatha Reddy',
    'Harish Chandra Nair','Nirmala Devi','Rajesh Kumar','Sravani Reddy',
    'Ashok Kumar Goud','Priya Raju','Srikanth Reddy','Jyothi Laxmi',
    'Balakrishna Rao','Savitha Devi','Nagendra Prasad','Rekha Kumari',
    'Sampath Kumar','Kalpana Reddy','Vinod Kumar Sharma','Anusha Naidu',
    'Venkateswara Rao','Madhavi Latha','Suryanarayana Murthy','Padmavathi Devi',
    'Tirupati Rao','Radha Krishna','Nageswara Rao','Saraswathi Devi',
    'Lakshminarayana Goud','Bhagyalakshmi Reddy','Seshagiri Rao','Vasantha Kumari',
    'Raghavendra Reddy','Jayalakshmi Devi','Chandraiah Yadav','Savitri Bai',
    'Srinivasulu Reddy','Kalavathi Devi','Kishore Kumar Rao','Nandini Reddy'];
  mstats text[] := ARRAY[
    'approved','approved','approved','approved','approved',
    'approved','approved','approved','approved','approved',
    'approved','approved','approved','approved','approved',
    'approved','approved','approved','approved','approved',
    'fees_confirmed','fees_confirmed','fees_confirmed','fees_confirmed','fees_confirmed',
    'fees_confirmed','fees_confirmed','fees_confirmed','fees_confirmed','fees_confirmed',
    'fees_pending','fees_pending','fees_pending','fees_pending','fees_pending',
    'fees_pending','fees_pending','fees_pending','fees_pending','fees_pending',
    'applied','applied','applied','applied','applied',
    'applied','applied','applied','applied','applied',
    'suspended','suspended','suspended','suspended','suspended',
    'suspended','suspended','rejected','rejected','rejected'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  SELECT array_agg(uid ORDER BY rn) INTO uids FROM _demo_unit_pool;

  FOR n IN 1..60 LOOP
    WITH ins AS (
      INSERT INTO memberships(society_id, unit_id, member_name, member_type,
                               admission_fee_amount, admission_fee_paid,
                               admission_fee_paid_at,
                               share_capital_amount, share_capital_paid,
                               byelaw_copy_fee_paid, status,
                               voting_eligible, declaration_signed,
                               declaration_signed_at, submitted_at,
                               membership_number, share_certificate_number,
                               share_certificate_issued_at,
                               reviewed_by, reviewed_at, created_at)
      VALUES(
        sid, uids[n], mnames[n],
        CASE n%5 WHEN 0 THEN 'purchaser' ELSE 'original_owner' END,
        1000, mstats[n] NOT IN ('applied','fees_pending'),
        CASE WHEN mstats[n] NOT IN ('applied','fees_pending') THEN now()-((300-n*4)||' days')::interval ELSE NULL END,
        1000, mstats[n] IN ('fees_confirmed','approved','suspended'),
        mstats[n] IN ('fees_confirmed','approved'),
        mstats[n],
        mstats[n] = 'approved',
        mstats[n] NOT IN ('applied','rejected'),
        CASE WHEN mstats[n] NOT IN ('applied','rejected') THEN now()-((290-n*4)||' days')::interval ELSE NULL END,
        CASE WHEN mstats[n] != 'applied' THEN now()-((295-n*4)||' days')::interval ELSE NULL END,
        'DEMO-MEM-'||lpad(n::text,4,'0'),
        CASE WHEN mstats[n]='approved' AND n<=20 THEN 'DEMO-SC-'||lpad(n::text,4,'0') ELSE NULL END,
        CASE WHEN mstats[n]='approved' AND n<=20 THEN now()-((280-n*4)||' days')::interval ELSE NULL END,
        CASE WHEN mstats[n] NOT IN ('applied','fees_pending') THEN adm ELSE NULL END,
        CASE WHEN mstats[n] NOT IN ('applied','fees_pending') THEN now()-((285-n*4)||' days')::interval ELSE NULL END,
        now()-((300-n*4)||' days')::interval
      )
      ON CONFLICT DO NOTHING
      RETURNING id
    )
    INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'memberships',id::text FROM ins ON CONFLICT DO NOTHING;
  END LOOP;
END $memberships$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §19  STAFF KYC — 20 staff members + 100 attendance records
-- ══════════════════════════════════════════════════════════════════════════════
DO $staff$
DECLARE
  sid   CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm   uuid;
  stid  uuid;
  n     int;
  d     int;
  snames text[] := ARRAY[
    'Ramaiah Goud','Krishna Kumar','Suresh Yadav','Sanjay Naik','Mohan Reddy',
    'Chandraiah Goud','Yadagiri Reddy','Venkatesham Rao','Raju Bhai','Mallesham',
    'Balu Naidu','Gopal Rao','Seshu Kumar','Srinivas Nayak','Naresh Goud',
    'Ramesh Kumar','Kishore Reddy','Naveen Rao','Santosh Kumar','Pavan Naidu'];
  sroles text[] := ARRAY[
    'security_guard','security_guard','security_guard','security_guard','security_guard','security_guard',
    'housekeeper','housekeeper','housekeeper','housekeeper',
    'gardener','gardener','gardener',
    'lift_operator','lift_operator','lift_operator',
    'admin_staff','admin_staff',
    'maintenance','maintenance'];
  kstats text[] := ARRAY[
    'pass_issued','pass_issued','pass_issued','pass_issued','police_verified','documents_submitted',
    'pass_issued','pass_issued','police_verified','documents_submitted',
    'pass_issued','pass_issued','pending',
    'pass_issued','police_verified','pending',
    'pass_issued','documents_submitted',
    'pass_issued','police_verified'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..20 LOOP
    INSERT INTO staff_members(society_id, name, role, phone,
                               joining_date, is_active,
                               police_verified, two_photos_received,
                               security_pass_issued, kyc_status, created_at)
    VALUES(
      sid, snames[n], sroles[n],
      '90'||lpad((n*98765%100000000)::text,8,'0'),
      (current_date-((365+n*15)||' days')::interval)::date,
      n<=18,
      kstats[n] IN ('pass_issued','police_verified'),
      kstats[n] NOT IN ('pending'),
      kstats[n]='pass_issued',
      kstats[n],
      now()
    )
    RETURNING id INTO stid;

    IF stid IS NOT NULL THEN
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('staff_members',stid::text) ON CONFLICT DO NOTHING;

      -- 5 attendance days per staff → 100 total
      FOR d IN 1..5 LOOP
        INSERT INTO staff_attendance(society_id, staff_id, date,
                                     check_in, check_out, logged_by, created_at)
        VALUES(sid, stid, current_date-d,
               (current_date-d)::timestamptz+'07:30'::interval,
               (current_date-d)::timestamptz+'16:30'::interval,
               adm, now())
        ON CONFLICT(staff_id, date) DO NOTHING;
      END LOOP;
    END IF;
  END LOOP;

  INSERT INTO _demo_data_registry(tbl,record_id)
    SELECT 'staff_attendance', id::text FROM staff_attendance sa
    WHERE sa.society_id=sid AND sa.created_at>=(now()-interval'1 minute')
    ON CONFLICT DO NOTHING;
END $staff$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §20  HOTO — 30 handover items + 50 snag items
-- ══════════════════════════════════════════════════════════════════════════════
DO $hoto$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
  n    int;
  hcats text[] := ARRAY[
    'Electrical','Electrical','Electrical','Electrical',
    'Plumbing','Plumbing','Plumbing','Plumbing',
    'Lifts','Lifts','Civil','Civil','Civil','Civil','Civil',
    'Club House','Club House','Club House','Club House',
    'Swimming Pool','Swimming Pool','Swimming Pool',
    'Landscaping','Landscaping','Landscaping',
    'Security Systems','Security Systems','Security Systems',
    'External Works','External Works'];
  htitles text[] := ARRAY[
    'Main LT panel installation & commissioning',
    'Common area lighting — all blocks',
    'DG set commissioning (250 kVA)',
    'UPS system for common area equipment',
    'Overhead tank connections & plumbing',
    'Fire hydrant & sprinkler system',
    'Sewage treatment plant (STP) handover',
    'Rainwater harvesting system',
    'G Block elevators (2 nos.) commissioning',
    'H Block elevators (2 nos.) commissioning',
    'Boundary wall & gate completion',
    'Main entrance gate installation',
    'Basement parking markings & signage',
    'Terrace waterproofing all blocks',
    'External facade painting',
    'Gymnasium equipment handover',
    'Community hall furniture & fittings',
    'Mini theatre setup',
    'Club house restroom completion',
    'Swimming pool filtration system',
    'Pool safety equipment & fencing',
    'Pool area lighting & ambience',
    'Central garden landscaping',
    'Children''s play area equipment',
    'Tree plantation (100 nos.)',
    'CCTV system (48 cameras) with DVR',
    'Access control at entry points',
    'Guard post equipment & furniture',
    'Approach road & internal roads',
    'Street lighting — complete campus'];
  hstats text[] := ARRAY[
    'APPROVED','APPROVED','APPROVED','APPROVED',
    'APPROVED','APPROVED','IN_PROGRESS','NOT_STARTED',
    'APPROVED','IN_PROGRESS',
    'APPROVED','APPROVED','APPROVED','UNDER_REVIEW','IN_PROGRESS',
    'APPROVED','APPROVED','IN_PROGRESS','NOT_STARTED',
    'APPROVED','APPROVED','IN_PROGRESS',
    'APPROVED','APPROVED','IN_PROGRESS',
    'APPROVED','UNDER_REVIEW','IN_PROGRESS',
    'APPROVED','IN_PROGRESS'];
  hpris text[] := ARRAY[
    'HIGH','MEDIUM','HIGH','MEDIUM',
    'HIGH','CRITICAL','HIGH','MEDIUM',
    'CRITICAL','CRITICAL',
    'HIGH','MEDIUM','MEDIUM','MEDIUM','MEDIUM',
    'LOW','LOW','LOW','MEDIUM',
    'HIGH','HIGH','MEDIUM',
    'LOW','MEDIUM','LOW',
    'HIGH','HIGH','MEDIUM',
    'MEDIUM','MEDIUM'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..30 LOOP
    INSERT INTO hoto_items(id, society_id, hoto_category, title,
                           description, priority, status,
                           responsible_role, created_by, created_at, last_updated_at)
    VALUES(
      'DEMO-HOTO-'||lpad(n::text,3,'0'),
      sid, hcats[n], htitles[n],
      'Builder commitment for '||htitles[n]||'. Tracked as part of HOTO process.',
      hpris[n], hstats[n],
      CASE n%4 WHEN 0 THEN 'president' WHEN 1 THEN 'secretary' WHEN 2 THEN 'executive' ELSE 'vendor' END,
      adm, now()-((365-n*10)||' days')::interval, now()
    )
    ON CONFLICT(id) DO NOTHING;

    IF FOUND THEN
      INSERT INTO _demo_data_registry(tbl,record_id)
        VALUES('hoto_items','DEMO-HOTO-'||lpad(n::text,3,'0')) ON CONFLICT DO NOTHING;
      -- 1 required doc per HOTO item
      INSERT INTO hoto_required_docs(hoto_item_id, doc_name, required, uploaded, created_at)
        VALUES('DEMO-HOTO-'||lpad(n::text,3,'0'), 'Completion certificate / test report', true, hstats[n]='APPROVED', now());
    END IF;
  END LOOP;

  -- 50 snag items (30 common area + 20 apartment)
  FOR n IN 1..50 LOOP
    INSERT INTO snag_items(id, society_id, snag_scope, category, location,
                           description, severity, status,
                           reported_date, reported_by, created_at)
    VALUES(
      'DEMO-SNAG-'||lpad(n::text,3,'0'),
      sid,
      CASE WHEN n<=30 THEN 'COMMON_AREA' ELSE 'APARTMENT' END,
      (ARRAY['Structural','Electrical','Plumbing','Finishing','External Works','Mechanical'])[((n-1)%6)+1],
      CASE WHEN n<=30 THEN
        (ARRAY['G Block Lobby','H Block Lobby','Basement Parking','Swimming Pool Area',
               'Gymnasium','Terrace','Garden','Main Entrance','Staircase G','Staircase H'])[((n-1)%10)+1]
      ELSE
        (ARRAY['G','H'])[((n-31)%2)+1]||'-'||((n%6)+1)||lpad(((n%10)+1)::text,2,'0')
      END,
      (ARRAY[
        'Crack in wall near main entrance',
        'Switchboard loose in common area',
        'Water seepage from overhead tank',
        'Tiles not level in lobby floor',
        'Boundary wall plaster peeling',
        'Exhaust fan not working in staircase'
      ])[((n-1)%6)+1]||' — reported by resident, requires immediate attention.',
      (ARRAY['LOW','MEDIUM','MEDIUM','HIGH','CRITICAL'])[((n-1)%5)+1],
      (ARRAY['OPEN','IN_PROGRESS','IN_PROGRESS','RESOLVED','VERIFIED_CLOSED','REOPENED'])[((n-1)%6)+1],
      (current_date-((200-n*3))::int)::date,
      adm, now()
    )
    ON CONFLICT(id) DO NOTHING;

    IF FOUND THEN
      INSERT INTO _demo_data_registry(tbl,record_id)
        VALUES('snag_items','DEMO-SNAG-'||lpad(n::text,3,'0')) ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END $hoto$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §21  DOCUMENTS — 50 documents across all categories
-- ══════════════════════════════════════════════════════════════════════════════
DO $documents$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  WITH doc_data(title, cat, req_role, is_pub) AS (VALUES
    ('Society Registration Certificate',           'Bylaws',    'admin',      false),
    ('Model Byelaws 2013 (Full Text)',             'Bylaws',    'member',     true),
    ('Amended Byelaws 2023',                       'Bylaws',    'member',     true),
    ('House Rules & Regulations',                  'Bylaws',    'member',     true),
    ('Deed of Declaration',                        'Bylaws',    'admin',      false),
    ('AGM 12th Annual Meeting Minutes (2022)',      'Minutes',   'member',     true),
    ('AGM 13th Annual Meeting Minutes (2023)',      'Minutes',   'member',     true),
    ('AGM 14th Annual Meeting Minutes (2024)',      'Minutes',   'member',     true),
    ('EGM October 2024 Minutes',                   'Minutes',   'member',     true),
    ('MC Meeting Minutes — April 2025',            'Minutes',   'member',     true),
    ('MC Meeting Minutes — March 2025',            'Minutes',   'member',     true),
    ('MC Meeting Minutes — February 2025',         'Minutes',   'member',     true),
    ('Annual Accounts FY 2023-24 (Audited)',       'Financial', 'member',     true),
    ('Annual Accounts FY 2022-23 (Audited)',       'Financial', 'member',     true),
    ('Annual Accounts FY 2021-22 (Audited)',       'Financial', 'member',     true),
    ('Q4 FY2024-25 Income & Expenditure',          'Financial', 'executive',  false),
    ('Corpus Fund Investment Statement FY24-25',   'Financial', 'member',     true),
    ('TDS Returns Q3 FY2024-25',                   'Financial', 'admin',      false),
    ('GSTIN Certificate',                          'Legal',     'member',     true),
    ('PAN Card of Society',                        'Legal',     'admin',      false),
    ('Land Registration Document',                 'Legal',     'admin',      false),
    ('Electricity Connection Agreement',           'Legal',     'admin',      false),
    ('Water Connection Agreement',                 'Legal',     'admin',      false),
    ('Builder Agreement & Undertaking',            'Legal',     'admin',      false),
    ('RERA Registration Certificate',              'Legal',     'member',     true),
    ('Maintenance Due Circular — May 2025',        'Circulars', 'member',     true),
    ('Penalty Waiver Circular — May 2025',         'Circulars', 'member',     true),
    ('AGM Notice 16th AGM 2024-25',                'Circulars', 'member',     true),
    ('New Security Policy Circular',               'Circulars', 'member',     true),
    ('EV Charging Station Approval Circular',      'Circulars', 'member',     true),
    ('Membership Application Form',                'Forms',     'member',     true),
    ('NOC Application Form',                       'Forms',     'member',     true),
    ('Parking Transfer Form',                      'Forms',     'member',     true),
    ('Tenant Registration Form',                   'Forms',     'member',     true),
    ('Maid Registration Form',                     'Forms',     'member',     true),
    ('Builder Defect Notice — Lifts (2025)',       'Other',     'executive',  false),
    ('Builder Defect Notice — STP (2024)',         'Other',     'executive',  false),
    ('Audit Report FY 2023-24',                    'Other',     'member',     true),
    ('Audit Report FY 2022-23',                    'Other',     'member',     true),
    ('Insurance Policy — Building',                'Other',     'admin',      false),
    ('Emergency Contact Directory',                'Other',     'member',     true),
    ('Vendor Contact List',                        'Other',     'executive',  false),
    ('HOTO Status Report — March 2025',            'Other',     'member',     true),
    ('Snag List — External Audit 2024',            'Other',     'executive',  false),
    ('Society Logo & Branding Guidelines',         'Other',     'member',     true),
    ('Housekeeping AMC Contract FY25-26',          'Other',     'admin',      false),
    ('Security Agency Contract FY25-26',           'Other',     'admin',      false),
    ('Lift Maintenance AMC FY25-26',               'Other',     'admin',      false),
    ('CCTV AMC Agreement',                         'Other',     'admin',      false),
    ('Fire Safety Compliance Certificate 2025',    'Other',     'member',     true)
  ),
  ins AS (
    INSERT INTO documents(society_id, title, category, description,
                           storage_key, file_name, mime_type, file_size_bytes,
                           version, is_public, requires_role, created_by, created_at, updated_at)
    SELECT
      sid, title, cat,
      title||' — official document of UTA MACS Society',
      'demo/documents/'||lower(replace(replace(title,' ','-'),'/','_'))||'.pdf',
      lower(replace(replace(title,' ','-'),'/','_'))||'.pdf',
      'application/pdf',
      (800000 + (random()*4000000)::int),
      1, is_pub, req_role, adm, now(), now()
    FROM doc_data
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'documents',id::text FROM ins ON CONFLICT DO NOTHING;
END $documents$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §22  GENERATED LETTERS — 20 official letters
-- ══════════════════════════════════════════════════════════════════════════════
DO $letters$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  WITH ld(n, title, subject, recipient) AS (VALUES
    (1,  'NOC — Sale of Flat G-101',                  'No Objection Certificate for Sale',         'The Registrar, SRO Shankarpalle'),
    (2,  'NOC — Sale of Flat G-205',                  'No Objection Certificate for Sale',         'The Registrar, SRO Rajendranagar'),
    (3,  'NOC — Sale of Flat H-302',                  'No Objection Certificate for Sale',         'The Registrar, SRO Shankarpalle'),
    (4,  'NOC — Sale of Flat H-410',                  'No Objection Certificate for Sale',         'The Registrar, SRO Serilingampally'),
    (5,  'NOC — Mortgage of Flat G-503',              'No Objection Certificate for Mortgage',     'The Branch Manager, SBI Kondakal'),
    (6,  'Maintenance Dues Reminder — Q3 FY2024-25',  'Pending Maintenance Dues — Final Notice',   'All Residents — G & H Blocks'),
    (7,  'Maintenance Dues Reminder — Q4 FY2024-25',  'Quarterly Maintenance Dues — Due 15 Feb',   'All Residents — G & H Blocks'),
    (8,  'Penalty Waiver Notice — May 2025',          'One-Time Penalty Waiver Opportunity',        'All Residents with Outstanding Dues'),
    (9,  'Overdue Dues Legal Notice — G-308',         'Final Notice Before Legal Action',           'Resident, Flat G-308'),
    (10, 'Share Capital Collection Notice',           'Share Capital Payment Required',             'New Members — G & H Blocks'),
    (11, 'Police Verification Request — Security Staff','Police Verification of Society Staff',    'Station House Officer, Shankarpalle PS'),
    (12, 'Police Verification Request — Maids',       'Domestic Help Verification Request',         'Station House Officer, Kondakal PS'),
    (13, 'Police Verification Request — Tenants',     'Tenant Verification Request — Q1 2025',     'Station House Officer, Shankarpalle PS'),
    (14, 'Builder Notice — Pending Lifts',            'Formal Notice: Elevator Handover Pending',  'MD, Ascenza Constructions Pvt Ltd'),
    (15, 'Builder Notice — STP Defects',              'Formal Notice: STP System Non-Functional',  'MD, Ascenza Constructions Pvt Ltd'),
    (16, 'Builder Notice — Common Area Snags',        'Formal Notice: 50 Unresolved Snag Items',   'MD, Ascenza Constructions Pvt Ltd'),
    (17, 'Builder Notice — Road Completion',          'Formal Notice: Approach Road Incomplete',   'MD, Ascenza Constructions Pvt Ltd'),
    (18, 'AGM Notice — 16th Annual General Meeting',  '16th AGM of UTA MACS — 15 Mar 2025',        'All Members of UTA MACS Society'),
    (19, 'AGM Notice — Extraordinary General Meeting','EGM Notice — 5 Oct 2024',                   'All Members of UTA MACS Society'),
    (20, 'Circular — EV Charging Station Approval',  'EV Charging Station Project Approved',       'All Residents, UTA MACS Society')
  ),
  ins AS (
    INSERT INTO generated_letters(society_id, title, subject, recipient, git_repo,
                                   git_path_pdf, field_values, signatures_used,
                                   created_by, created_at)
    SELECT
      sid, title, subject, recipient,
      'utamacs/utamacs-docs',
      'letters/2025/UTAMACS-2025-'||lpad(n::text,3,'0')||'.pdf',
      json_build_object(
        'date',      to_char(now()-((20-n)*10||' days')::interval,'DD Month YYYY'),
        'reference', 'UTAMACS/LTR/2025/'||lpad(n::text,3,'0'),
        'recipient', recipient,
        'subject',   subject
      )::jsonb,
      ARRAY['K. Venkata Rao (President)', 'P. Srinivasa Murthy (Secretary)'],
      adm,
      now()-((20-n)*10||' days')::interval
    FROM ld
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'generated_letters',id::text FROM ins ON CONFLICT DO NOTHING;
END $letters$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §23  POLICIES — 5 policies + 5 acknowledgements
-- ══════════════════════════════════════════════════════════════════════════════
DO $policies$
DECLARE
  sid  CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
  adm  uuid;
  plid uuid;
  n    int;
  ptitles text[] := ARRAY[
    'Privacy Policy — DPDPA 2023',
    'Community Living Byelaws & House Rules',
    'Amenity Usage Guidelines',
    'CCTV Surveillance Policy',
    'Pet Ownership & Registration Policy'];
  pbodies text[] := ARRAY[
    'UTA MACS Society collects and processes personal data of residents strictly in accordance with the Digital Personal Data Protection Act 2023. Data is collected for society management purposes only and will not be shared with third parties without consent. Residents may request access, correction, or deletion of their data by contacting the secretary.',
    'Residents are expected to follow the society byelaws at all times. Key rules: (1) Maintenance dues must be paid by the 15th of each quarter. (2) No structural modifications without written approval. (3) Noise to be avoided after 10 PM. (4) Common areas to be kept clean. (5) Visitors must register at the gate.',
    'Community Hall: Available 6 AM–10 PM. Book 48 hours in advance. Maximum 4 hours per booking. Swimming Pool: Open 6–9 AM and 4–8 PM. Children below 12 must be accompanied by adults. Gymnasium: Open 5 AM–10 PM. Personal trainers require prior approval.',
    'CCTV cameras are installed in all common areas for security purposes. Footage is retained for 30 days. Access to footage is restricted to the managing committee and law enforcement. Residents may request footage related to incidents within 7 days of occurrence by submitting a written request.',
    'All pets must be registered with the society office within 30 days of acquisition. Required documents: vaccination certificate, breed certificate. Pets must be leashed in common areas. Owners are responsible for cleaning after their pets. Noise complaints will result in warnings; repeated violations may lead to removal from society premises.'];
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;

  FOR n IN 1..5 LOOP
    INSERT INTO policies(society_id, title, policy_type, body, version,
                         effective_date, acknowledgement_required,
                         gate_portal_access, status, created_by, created_at)
    VALUES(sid, ptitles[n], 'text', pbodies[n], 1,
           (current_date-((5-n)*30))::date, true,
           n=1,   -- only Privacy Policy gates portal access
           'active', adm, now())
    RETURNING id INTO plid;

    IF plid IS NOT NULL THEN
      INSERT INTO _demo_data_registry(tbl,record_id) VALUES('policies',plid::text) ON CONFLICT DO NOTHING;
      -- Admin acknowledges each policy
      INSERT INTO policy_acknowledgements(policy_id, user_id, acked_at, created_at)
      VALUES(plid, adm, now(), now())
      ON CONFLICT(policy_id, user_id) DO NOTHING;
    END IF;
  END LOOP;
END $policies$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §24  REGISTRATION REQUESTS — 30 new resident portal applications
-- ══════════════════════════════════════════════════════════════════════════════
DO $regreqs$
DECLARE sid CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
        adm uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  WITH rr(n, full_name, email, occ_type, stat) AS (VALUES
    (1,'Vikram Nair','vikram.nair@email.com','owner','approved'),
    (2,'Preethi Sharma','preethi.sharma@email.com','tenant','approved'),
    (3,'Suresh Iyer','suresh.iyer@email.com','owner','approved'),
    (4,'Lavanya Reddy','lavanya.reddy@email.com','tenant','approved'),
    (5,'Karthik Rao','karthik.rao@email.com','owner','approved'),
    (6,'Divya Krishnan','divya.k@email.com','co_owner','approved'),
    (7,'Aditya Kumar','aditya.kumar@email.com','owner','approved'),
    (8,'Sowmya Nair','sowmya.nair@email.com','tenant','approved'),
    (9,'Vivek Menon','vivek.menon@email.com','owner','rejected'),
    (10,'Amrutha Rao','amrutha.rao@email.com','tenant','rejected'),
    (11,'Sreeram Nair','sreeram.n@email.com','owner','rejected'),
    (12,'Pooja Sharma','pooja.sharma@email.com','tenant','rejected'),
    (13,'Manoj Reddy','manoj.reddy@email.com','owner','rejected'),
    (14,'Rithvik Kumar','rithvik.k@email.com','tenant','duplicate'),
    (15,'Sindhu Rajan','sindhu.rajan@email.com','co_owner','duplicate'),
    (16,'Pranav Rao','pranav.rao@email.com','owner','pending'),
    (17,'Swathi Nair','swathi.nair@email.com','tenant','pending'),
    (18,'Abhishek Sharma','abhi.sharma@email.com','owner','pending'),
    (19,'Nivedhitha Reddy','nive.reddy@email.com','tenant','pending'),
    (20,'Arjun Menon','arjun.m@email.com','owner','pending'),
    (21,'Keerthi Rao','keerthi.rao@email.com','co_owner','pending'),
    (22,'Sai Teja','sai.teja@email.com','owner','pending'),
    (23,'Haritha Krishnan','haritha.k@email.com','tenant','pending'),
    (24,'Rohit Kumar','rohit.kumar@email.com','owner','pending'),
    (25,'Ananya Sharma','ananya.s@email.com','tenant','pending'),
    (26,'Tarun Nair','tarun.nair@email.com','owner','pending'),
    (27,'Deepthi Rao','deepthi.rao@email.com','tenant','pending'),
    (28,'Gautam Reddy','gautam.r@email.com','owner','pending'),
    (29,'Ishaan Kumar','ishaan.k@email.com','co_owner','pending'),
    (30,'Tejasri Menon','tejasri.m@email.com','owner','pending')
  ),
  ins AS (
    INSERT INTO registration_requests(society_id, full_name, email, occupancy_type,
                                       status, id_type, reviewed_by, reviewed_at, created_at)
    SELECT sid, full_name, email, occ_type, stat,
           'aadhaar', -- id_type
           CASE WHEN stat IN ('approved','rejected','duplicate') THEN adm ELSE NULL END,
           CASE WHEN stat IN ('approved','rejected','duplicate') THEN now()-((30-n)||' days')::interval ELSE NULL END,
           now()-((31-n)||' days')::interval
    FROM rr
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'registration_requests',id::text FROM ins ON CONFLICT DO NOTHING;
END $regreqs$;

-- ══════════════════════════════════════════════════════════════════════════════
-- §25  NOTIFICATIONS — 50 in-app notifications
-- ══════════════════════════════════════════════════════════════════════════════
DO $notifs$
DECLARE sid CONSTANT uuid := '00000000-0000-0000-0000-000000000001';
        adm uuid;
BEGIN
  SELECT id INTO adm FROM auth.users ORDER BY created_at LIMIT 1;
  WITH ins AS (
    INSERT INTO notifications(society_id, user_id, title, body, type,
                               channel, status, is_read, created_at)
    SELECT
      sid, adm,
      (ARRAY[
        'Complaint DEMO-TKT-0001 has been resolved',
        'New notice: Water supply shutdown 15 May',
        'Upcoming event: Ugadi Celebrations 2025',
        'Poll closing soon: Maintenance revision',
        'Maintenance dues reminder — Q1 FY2025-26',
        'New visitor approval request',
        'Facility booking confirmed — Community Hall',
        'New community post in your block',
        'Security alert: Gate access after hours',
        'System: Monthly newsletter published'
      ])[((gs-1)%10)+1],
      'Tap to view details.',
      (ARRAY['complaint','notice','event','poll','payment','visitor','facility','system','security_alert','system'])[((gs-1)%10)+1],
      'in_app',
      CASE WHEN gs%3=0 THEN 'read' WHEN gs%3=1 THEN 'delivered' ELSE 'sent' END,
      (gs%3=0),
      now()-((50-gs)||' hours')::interval
    FROM generate_series(1,50) gs
    RETURNING id
  )
  INSERT INTO _demo_data_registry(tbl,record_id) SELECT 'notifications',id::text FROM ins ON CONFLICT DO NOTHING;
END $notifs$;

COMMIT;

