-- ═══════════════════════════════════════════════════════════════
-- 014_seed.sql
-- Development seed data: test users, sample content
-- NOTE: auth.users rows must be inserted via Supabase Dashboard
--       or CLI seeding; this file seeds application-layer tables
--       using pre-known UUIDs that match those test auth users.
--
-- In production (no auth users present) this block exits cleanly.
-- ═══════════════════════════════════════════════════════════════

DO $$
BEGIN
  -- Skip entirely if dev auth users have not been pre-created
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = 'a0000000-0000-0000-0000-000000000001') THEN
    RAISE NOTICE 'Seed skipped: dev auth users not present (production environment).';
    RETURN;
  END IF;

  -- ─── Test user UUIDs (match Supabase Auth seed) ─────────────
  -- admin@utamacs.org      → 'a0000000-0000-0000-0000-000000000001'
  -- exec@utamacs.org       → 'a0000000-0000-0000-0000-000000000002'
  -- member1@utamacs.org    → 'a0000000-0000-0000-0000-000000000003'
  -- member2@utamacs.org    → 'a0000000-0000-0000-0000-000000000004'
  -- guard@utamacs.org      → 'a0000000-0000-0000-0000-000000000005'

  -- ─── Profiles ────────────────────────────────────────────────
  INSERT INTO profiles (id, society_id, full_name, unit_id, residency_type, is_active, consent_version, consent_at)
  VALUES
    ('a0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'Subrahmanyam Admin',
     (SELECT id FROM units WHERE unit_number = 'A-101' LIMIT 1),
     'owner', true, 1, now()),

    ('a0000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     'Rajeshwari Executive',
     (SELECT id FROM units WHERE unit_number = 'B-201' LIMIT 1),
     'owner', true, 1, now()),

    ('a0000000-0000-0000-0000-000000000003',
     '00000000-0000-0000-0000-000000000001',
     'Venkatesh Member',
     (SELECT id FROM units WHERE unit_number = 'C-301' LIMIT 1),
     'owner', true, 1, now()),

    ('a0000000-0000-0000-0000-000000000004',
     '00000000-0000-0000-0000-000000000001',
     'Kavitha Member',
     (SELECT id FROM units WHERE unit_number = 'D-401' LIMIT 1),
     'tenant', true, 1, now()),

    ('a0000000-0000-0000-0000-000000000005',
     '00000000-0000-0000-0000-000000000001',
     'Ravi Security',
     NULL,
     'owner', true, 1, now())
  ON CONFLICT (id) DO NOTHING;

  -- ─── User Roles ───────────────────────────────────────────────
  INSERT INTO user_roles (user_id, role, society_id, granted_by, expires_at)
  VALUES
    ('a0000000-0000-0000-0000-000000000001', 'admin',          '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', NULL),
    ('a0000000-0000-0000-0000-000000000002', 'executive',      '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '2027-03-31'),
    ('a0000000-0000-0000-0000-000000000003', 'member',         '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', NULL),
    ('a0000000-0000-0000-0000-000000000004', 'member',         '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', NULL),
    ('a0000000-0000-0000-0000-000000000005', 'security_guard', '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', NULL)
  ON CONFLICT (user_id) DO NOTHING;

  -- ─── Notification Preferences ────────────────────────────────
  INSERT INTO notification_preferences (user_id)
  VALUES
    ('a0000000-0000-0000-0000-000000000001'),
    ('a0000000-0000-0000-0000-000000000002'),
    ('a0000000-0000-0000-0000-000000000003'),
    ('a0000000-0000-0000-0000-000000000004'),
    ('a0000000-0000-0000-0000-000000000005')
  ON CONFLICT (user_id) DO NOTHING;

  -- ─── Sample Notices ──────────────────────────────────────────
  INSERT INTO notices (id, society_id, title, body, category, target_audience, is_published, requires_acknowledgement, created_by)
  VALUES
    ('b0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'Welcome to UTA MACS Resident Portal',
     '<p>Dear Residents,</p><p>We are pleased to announce the launch of the UTA MACS Resident Portal. You can now raise complaints, view notices, pay maintenance dues, and book community facilities online.</p><p>For any assistance, please contact the Management Office.</p><p>Regards,<br/>UTA MACS Management Committee</p>',
     'General', 'all', true, false,
     'a0000000-0000-0000-0000-000000000002'),

    ('b0000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     'Q1 FY2025-26 Maintenance Due — Payment Reminder',
     '<p>Dear Residents,</p><p>This is a reminder that Q1 FY2025-26 maintenance dues of <strong>₹5,000</strong> are due by <strong>15th April 2025</strong>. Please pay online via the portal or by cheque at the Management Office.</p><p>Late payments attract a penalty of 2% per month.</p>',
     'Financial', 'all', true, true,
     'a0000000-0000-0000-0000-000000000002'),

    ('b0000000-0000-0000-0000-000000000003',
     '00000000-0000-0000-0000-000000000001',
     'Water Supply Interruption — 23rd April 2025',
     '<p><strong>URGENT:</strong> Water supply will be interrupted on 23rd April 2025 from 9:00 AM to 5:00 PM due to maintenance of the WTP system. Please store adequate water. We regret the inconvenience.</p>',
     'Urgent', 'all', true, false,
     'a0000000-0000-0000-0000-000000000002'),

    ('b0000000-0000-0000-0000-000000000004',
     '00000000-0000-0000-0000-000000000001',
     'Annual General Body Meeting — 30th April 2025',
     '<p>The Annual General Body Meeting of UTA MACS will be held on <strong>30th April 2025 at 6:00 PM</strong> in the Community Hall. Agenda includes:<br/>1. Annual accounts approval<br/>2. Election of office bearers<br/>3. Maintenance fee revision<br/>4. Open house Q&A</p><p>All flat owners are requested to attend.</p>',
     'Governance', 'all', true, true,
     'a0000000-0000-0000-0000-000000000002');

  -- ─── Sample Events ────────────────────────────────────────────
  INSERT INTO events (id, society_id, title, description, category, starts_at, ends_at, location, capacity, is_published, created_by)
  VALUES
    ('c0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'Ugadi Cultural Festival 2025',
     'Join us for a grand Ugadi celebration with cultural programs, traditional food, and fun activities for all age groups. All residents and their families are welcome.',
     'Cultural',
     '2025-04-06 17:00:00+05:30',
     '2025-04-06 21:00:00+05:30',
     'Community Hall, UTA MACS',
     300, true,
     'a0000000-0000-0000-0000-000000000002'),

    ('c0000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     'Community Fitness Drive — Yoga Session',
     'Free yoga session for all residents every Saturday morning at the clubhouse lawn. All fitness levels welcome. Bring your own mat.',
     'Sports',
     '2025-04-26 06:30:00+05:30',
     '2025-04-26 08:00:00+05:30',
     'Clubhouse Lawn, UTA MACS',
     50, true,
     'a0000000-0000-0000-0000-000000000002'),

    ('c0000000-0000-0000-0000-000000000003',
     '00000000-0000-0000-0000-000000000001',
     'Annual General Body Meeting',
     'UTA MACS AGM 2025 — Review of annual accounts, election of committee, maintenance revision, and open house.',
     'Governance',
     '2025-04-30 18:00:00+05:30',
     '2025-04-30 21:00:00+05:30',
     'Community Hall, UTA MACS',
     400, true,
     'a0000000-0000-0000-0000-000000000002');

  -- ─── Sample Billing Period ────────────────────────────────────
  INSERT INTO billing_periods (id, society_id, name, start_date, end_date, due_date, base_amount, is_active)
  VALUES
    ('d0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'Q1 FY2025-26',
     '2025-04-01', '2025-06-30', '2025-04-15',
     5000.00, true);

  -- ─── Sample Maintenance Dues ──────────────────────────────────
  INSERT INTO maintenance_dues (id, society_id, unit_id, user_id, billing_period_id, base_amount, penalty_amount, gst_amount, status, due_date)
  VALUES
    ('e0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     (SELECT id FROM units WHERE unit_number = 'A-101' LIMIT 1),
     'a0000000-0000-0000-0000-000000000001',
     'd0000000-0000-0000-0000-000000000001',
     5000.00, 0.00, 0.00, 'pending', '2025-04-15'),

    ('e0000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     (SELECT id FROM units WHERE unit_number = 'B-201' LIMIT 1),
     'a0000000-0000-0000-0000-000000000002',
     'd0000000-0000-0000-0000-000000000001',
     5000.00, 0.00, 0.00, 'paid', '2025-04-15'),

    ('e0000000-0000-0000-0000-000000000003',
     '00000000-0000-0000-0000-000000000001',
     (SELECT id FROM units WHERE unit_number = 'C-301' LIMIT 1),
     'a0000000-0000-0000-0000-000000000003',
     'd0000000-0000-0000-0000-000000000001',
     5000.00, 0.00, 0.00, 'overdue', '2025-04-15'),

    ('e0000000-0000-0000-0000-000000000004',
     '00000000-0000-0000-0000-000000000001',
     (SELECT id FROM units WHERE unit_number = 'D-401' LIMIT 1),
     'a0000000-0000-0000-0000-000000000004',
     'd0000000-0000-0000-0000-000000000001',
     5000.00, 100.00, 0.00, 'overdue', '2025-04-15');

  -- ─── Sample Complaints ────────────────────────────────────────
  INSERT INTO complaints (id, society_id, title, description, category, priority, status, raised_by,
    unit_id, sla_hours, sla_deadline)
  VALUES
    ('f0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'Block A Lift not working since morning',
     'The lift in Block A has been non-functional since 8 AM today. Residents including elderly are unable to climb stairs. Please expedite repair.',
     'Lift', 'Critical',
     'Open',
     'a0000000-0000-0000-0000-000000000003',
     (SELECT id FROM units WHERE unit_number = 'C-301' LIMIT 1),
     4, now() + interval '4 hours'),

    ('f0000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     'Water leakage in B-Wing corridor — 2nd floor',
     'There is a significant water leakage from a pipe in the 2nd floor corridor of B-Wing. Water is dripping onto the staircase creating a slip hazard.',
     'Plumbing', 'High',
     'Assigned',
     'a0000000-0000-0000-0000-000000000004',
     (SELECT id FROM units WHERE unit_number = 'D-401' LIMIT 1),
     24, now() + interval '20 hours'),

    ('f0000000-0000-0000-0000-000000000003',
     '00000000-0000-0000-0000-000000000001',
     'CCTV camera near main gate not working',
     'The CCTV camera at the main entrance has been non-functional for the past 3 days. This is a security concern as the area is unmonitored.',
     'Security', 'High',
     'In_Progress',
     'a0000000-0000-0000-0000-000000000003',
     (SELECT id FROM units WHERE unit_number = 'C-301' LIMIT 1),
     24, now() + interval '12 hours'),

    ('f0000000-0000-0000-0000-000000000004',
     '00000000-0000-0000-0000-000000000001',
     'Stray dogs in parking area',
     'Multiple stray dogs have been seen in the basement parking area for the past week. Residents are afraid to park their vehicles.',
     'Common_Area', 'Medium',
     'Resolved',
     'a0000000-0000-0000-0000-000000000003',
     (SELECT id FROM units WHERE unit_number = 'C-301' LIMIT 1),
     48, now() - interval '2 hours'),

    ('f0000000-0000-0000-0000-000000000005',
     '00000000-0000-0000-0000-000000000001',
     'Electricity fluctuation in A-Wing',
     'We are experiencing frequent voltage fluctuations in A-Wing, especially during evenings between 7-10 PM. This is damaging appliances.',
     'Electrical', 'Medium',
     'Open',
     'a0000000-0000-0000-0000-000000000001',
     (SELECT id FROM units WHERE unit_number = 'A-101' LIMIT 1),
     48, now() + interval '46 hours');

  -- ─── Sample Complaint Status History ─────────────────────────
  INSERT INTO complaint_status_history (complaint_id, old_status, new_status, note, changed_by)
  VALUES
    ('f0000000-0000-0000-0000-000000000002', 'Open', 'Assigned',
     'Assigned to plumbing contractor — Ravi Plumbers. Will inspect today.',
     'a0000000-0000-0000-0000-000000000002'),
    ('f0000000-0000-0000-0000-000000000003', 'Open', 'Assigned',
     'AMC vendor informed. Technician scheduled for tomorrow morning.',
     'a0000000-0000-0000-0000-000000000002'),
    ('f0000000-0000-0000-0000-000000000003', 'Assigned', 'In_Progress',
     'Technician arrived and is working on the camera replacement.',
     'a0000000-0000-0000-0000-000000000002'),
    ('f0000000-0000-0000-0000-000000000004', 'Open', 'Assigned',
     'GHMC Animal Husbandry department called for removal.',
     'a0000000-0000-0000-0000-000000000002'),
    ('f0000000-0000-0000-0000-000000000004', 'Assigned', 'Resolved',
     'Stray dogs removed by GHMC team. Area sanitized.',
     'a0000000-0000-0000-0000-000000000002');

  -- ─── Sample Complaint Comments ────────────────────────────────
  INSERT INTO complaint_comments (complaint_id, user_id, comment, is_internal)
  VALUES
    ('f0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003',
     'This is very urgent. My parents are elderly and cannot climb 8 floors.',
     false),
    ('f0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000002',
     'We have contacted OTIS Elevator Services. They will send a technician by 12 PM today.',
     false),
    ('f0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000002',
     'AMC contract states 4-hour SLA for lift failure. Tracking closely.',
     true),
    ('f0000000-0000-0000-0000-000000000003',
     'a0000000-0000-0000-0000-000000000002',
     'CCTV vendor warranty claim submitted. Replacement camera being procured.',
     true);

  -- ─── Sample Poll ──────────────────────────────────────────────
  INSERT INTO polls (id, society_id, title, description, poll_type, scope, is_anonymous, one_vote_per_unit,
    starts_at, ends_at, is_published, result_visibility, created_by)
  VALUES
    ('g0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'Preferred Timing for Community Yoga Sessions',
     'We are planning to organize community yoga sessions. Please vote for your preferred timing so we can schedule accordingly.',
     'single_choice', 'all_members', false, false,
     now() - interval '2 days', now() + interval '5 days',
     true, 'after_close',
     'a0000000-0000-0000-0000-000000000002');

  INSERT INTO poll_options (poll_id, option_text, order_index)
  VALUES
    ('g0000000-0000-0000-0000-000000000001', '5:30 AM – 7:00 AM', 1),
    ('g0000000-0000-0000-0000-000000000001', '6:00 AM – 7:30 AM', 2),
    ('g0000000-0000-0000-0000-000000000001', '6:30 AM – 8:00 AM', 3),
    ('g0000000-0000-0000-0000-000000000001', 'Evening 6:00 PM – 7:30 PM', 4);

  -- ─── Sample Community Post ────────────────────────────────────
  INSERT INTO community_posts (id, society_id, author_id, unit_id, category, title, body, is_published)
  VALUES
    ('h0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003',
     (SELECT id FROM units WHERE unit_number = 'C-301' LIMIT 1),
     'Recommendation',
     'Good plumber recommendation for residents',
     '<p>Hi everyone! I recently got my bathroom fixtures repaired by <strong>Sri Srinivas Plumbing Works</strong> (contact: available at the management office). Very professional, reasonable rates, and completed work on time. Highly recommend for any plumbing work within flats.</p>',
     true),

    ('h0000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000004',
     (SELECT id FROM units WHERE unit_number = 'D-401' LIMIT 1),
     'Lost_Found',
     'Found: Black umbrella near main gate',
     '<p>Found a black umbrella near the main gate security cabin yesterday evening. If it belongs to you, please contact security or visit D-401 to collect it. Please describe the umbrella to claim it.</p>',
     true);

  -- ─── Sample Facility Booking ──────────────────────────────────
  INSERT INTO facility_bookings (id, society_id, facility_id, user_id, unit_id,
    booking_date, start_time, end_time, attendees_count, purpose, status)
  VALUES
    ('i0000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-000000000001',
     (SELECT id FROM facilities WHERE name = 'Community Hall' LIMIT 1),
     'a0000000-0000-0000-0000-000000000003',
     (SELECT id FROM units WHERE unit_number = 'C-301' LIMIT 1),
     '2025-04-28',
     '2025-04-28 18:00:00+05:30',
     '2025-04-28 22:00:00+05:30',
     50, 'Housewarming ceremony', 'confirmed');

  -- ─── Sample In-App Notifications ─────────────────────────────
  INSERT INTO notifications (society_id, user_id, title, body, type, reference_table, reference_id, channel, status)
  VALUES
    ('00000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003',
     'Complaint Update: Lift repair in progress',
     'Your complaint about Block A Lift has been updated. OTIS technician is on the way.',
     'complaint', 'complaints', 'f0000000-0000-0000-0000-000000000001',
     'in_app', 'delivered'),

    ('00000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000003',
     'New Notice: Water Supply Interruption',
     'Water supply will be interrupted on 23rd April 2025. Please store adequate water.',
     'notice', 'notices', 'b0000000-0000-0000-0000-000000000003',
     'in_app', 'delivered'),

    ('00000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001',
     'Maintenance Due Reminder',
     'Your Q1 FY2025-26 maintenance due of ₹5,000 is pending. Due date: 15th April 2025.',
     'payment', 'maintenance_dues', 'e0000000-0000-0000-0000-000000000001',
     'in_app', 'delivered');

END $$;
