-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 029: March 2026 Building Inspection Audit — Urban Trilla Apartments
-- Auditor: Jyothikumar Kudumu  |  30 observations
-- Categories: Electrical (LT infrastructure) + Fire Safety
-- 8 High, 22 Moderate — all OPEN
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO snag_items (
  id, society_id, snag_source, snag_scope, category, subcategory,
  location, description, severity, status,
  audit_ref_no, audit_source, audit_date,
  compliance_requirement, recommendation, equipment_machinery,
  reported_date, deleted
) VALUES

-- ── Sr 1 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-001',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Cable Trays & Cable Management',
  'C-Block – Electrical Room',
  'Power cables laid on trays entering the electrical room are not properly clamped. Temporary GI wires are being used for fixing instead of approved clamps and supports. This condition is unsafe, increases strain on cable terminations, and is non-compliant.',
  'MEDIUM', 'OPEN',
  1, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1255:1983 (Installation and Maintenance of Power Cables), BIS IS 1646:2017 (Fire Safety of Buildings), and CEA Safety Regulations (2010, amended 2024), which mandate proper cable dressing, clamping, and fire-resistant sealing of entry points.',
  '1. Replace temporary GI wire fixings with approved clamps, saddles, or cable ties. 2. Ensure all cables are securely clamped at entry points to the electrical room. 3. Provide mechanical supports to prevent sagging or strain on terminations.',
  'Main Power Cables Tray',
  '2026-03-31', false
),

-- ── Sr 2 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-002',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Cable Trays & Cable Management',
  'C-Block – Electrical Room',
  'Wide wall gaps are visible at the cable tray entry points into the electrical room. These gaps pose risks of rodent entry and increase the likelihood of fire hazards due to potential debris accumulation and exposure of cables.',
  'MEDIUM', 'OPEN',
  2, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Seal all cable tray entry wall gaps using approved fire-resistant sealants or covers. 2. Install rodent-proof barriers or mesh at vulnerable points.',
  'Main Power Cables Tray',
  '2026-03-31', false
),

-- ── Sr 3 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-003',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Cable Trays & Cable Management',
  'C-Block – Electrical Room',
  'Cables inside the electrical room are not properly dressed, and standard cable laying practices have not been followed. Several hanging cables are visible, indicating inadequate clamping and routing. This condition is unsafe and increases strain on terminations.',
  'MEDIUM', 'OPEN',
  3, 'Jyothikumar Kudumu', '2026-03-31',
  'Relevant standard: IS 15652:2006 (Insulating Mats for Electrical Purpose), which supersedes IS 5424:1969.',
  '1. Perform proper cable dressing using approved clamps, saddles, and trays. 2. Ensure standard cable laying practices are followed, including segregation of power and control cables. 3. Remove all hanging cables and provide mechanical supports to prevent strain.',
  'Main Power Cables & Tray',
  '2026-03-31', false
),

-- ── Sr 4 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-004',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Cable Trays & Cable Management',
  'C-Block – Electrical Room',
  'The distribution system output cable tray contains cables that are not properly dressed or clamped. Cable entry gaps into the electrical room are left open and not sealed with fire-retardant material/sealant. This condition poses risks of mechanical damage, fire propagation, and rodent entry.',
  'MEDIUM', 'OPEN',
  4, 'Jyothikumar Kudumu', '2026-03-31',
  'Under Indian Electricity (IE) Rule 35, owners of MV/HV/EHV installations must permanently affix a "Danger" notice in Hindi, English, and the local language at conspicuous positions on electrical equipment.',
  '1. Perform proper cable dressing and clamping using approved supports and saddles. 2. Seal all cable entry gaps with certified fire-retardant material or sealant. 3. Ensure compliance with fire-resistant construction standards for electrical rooms.',
  'MV Cable Tray & Cables',
  '2026-03-31', false
),

-- ── Sr 5 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-005',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'UPS / Battery Systems',
  'C-Block – Electrical Room',
  'Inverter/UPS unit cables are lying directly on the ground without proper wiring or cable dressing. One UPS unit is placed on the ground without a stand. Insulation rubber mats are not provided near the UPS units and RTCC panel. RTCC panel cables are not properly dressed or clamped, and panel earthing is missing on both sides.',
  'MEDIUM', 'OPEN',
  5, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1255:1983 (Installation and Maintenance of Power Cables) and BIS IS 15652:2006 (Insulating Mats for Electrical Purposes). Per IE Rules 1956, Rule 61(2), the body of electrical panels must be earthed with two separate and distinct connections.',
  '1. Provide proper cable dressing and clamping for UPS and RTCC panel cables. 2. Install the UPS unit on a dedicated stand to prevent direct floor placement. 3. Place IS-certified insulating rubber mats near UPS units and RTCC panel. 4. Ensure panel earthing connections are installed and verified on both sides.',
  'UPS / Inverter Systems',
  '2026-03-31', false
),

-- ── Sr 6 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-006',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'C-Block – Electrical Room',
  'Rising mains main isolator panels are full of dust and dirt, indicating lack of regular cleaning and preventive maintenance. Panel identification tags/boards are not in place, and 3-phase indication lamps are not installed. Safety insulated rubber mats are not provided. These deficiencies compromise safety, monitoring, and traceability.',
  'MEDIUM', 'OPEN',
  6, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 8623:1993 (Low-voltage switchgear and controlgear assemblies) and BIS IS 1646:2017 (Fire Safety of Buildings).',
  '1. Carry out regular cleaning and preventive maintenance of isolator panels. 2. Install permanent identification tags/boards on all panels. 3. Fix 3-phase indication lamps to monitor supply. 4. Place IS-certified insulating rubber mats near panels.',
  'Rising Mains',
  '2026-03-31', false
),

-- ── Sr 7 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-007',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'All Electrical Rooms',
  'In all electrical rooms and panels, gland earthing for power cables is missing. Cable identification tags are not provided, and routing markings (incoming or outgoing) are absent for all power cables.',
  'MEDIUM', 'OPEN',
  7, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Provide gland earthing connections for all power cables in electrical rooms and panels. 2. Fix permanent identification tags on all cables. 3. Mark incoming and outgoing cable routes clearly as per IS standards.',
  'All Electrical Panels',
  '2026-03-31', false
),

-- ── Sr 8 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-008',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'All Blocks – Electrical Rooms',
  'Distribution boards (DBs) in the electrical rooms are found open, without permanent feeder identification tags or numbers. The DB single line diagram (SLD) is not placed, and feeder MCB blank cutouts are left open without proper spacers. DB identification numbers/tags as per the approved SLD are also missing.',
  'MEDIUM', 'OPEN',
  8, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Close all DBs securely and fit proper spacers for blank MCB cutouts. Install permanent feeder identification tags/numbers on all DBs. Place DB-SLDs inside each electrical room for reference and traceability. Ensure DB identification numbers/tags match the approved SLD.',
  'All Electrical DBs',
  '2026-03-31', false
),

-- ── Sr 9 ──────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-009',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'UPS / Battery Systems',
  'B-Block – Electrical Room',
  'UPS units are placed on masonry blocks without proper stands. Cables are lying directly on the ground, with no proper dressing or clamping observed.',
  'MEDIUM', 'OPEN',
  9, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Install UPS units on proper stands to avoid direct floor placement. 2. Provide cable dressing and clamping using approved supports, trays, and saddles.',
  'UPS / Inverter Systems',
  '2026-03-31', false
),

-- ── Sr 10 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-010',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'All Electrical Rooms',
  'Dust and dirt accumulation is observed inside the cable chambers and bus chambers of electrical panels. Regular preventive maintenance (PM) activities are not being carried out. This condition compromises equipment reliability and increases fire risk.',
  'MEDIUM', 'OPEN',
  10, 'Jyothikumar Kudumu', '2026-03-31',
  'Per IE Rules 1956, Rule 61(2), the body of electrical panels must be earthed with two separate and distinct connections to the earth.',
  'Implement a regular preventive maintenance schedule for cleaning cable terminations and bus chambers. Use vacuum cleaning or dry methods to avoid moisture ingress. Maintain PM records and history cards for all electrical panels. Ensure dust-proof sealing of chambers wherever possible.',
  'Electrical Panels',
  '2026-03-31', false
),

-- ── Sr 11 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-011',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Cable Trays & Cable Management',
  'C-Block – Electrical Room (Main Incomer)',
  'In the main incomer cable chamber, visible gaps are observed at the cable entry area. These gaps pose risks of dust and dirt accumulation, as well as entry of lizards and rodents, compromising equipment safety and reliability.',
  'MEDIUM', 'OPEN',
  11, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Seal all cable entry gaps using approved fire-retardant sealants or covers. Install rodent-proof barriers or mesh at vulnerable points. Ensure dust-proofing and fire-resistant sealing of cable chambers.',
  'Main Incomer Electrical Panel',
  '2026-03-31', false
),

-- ── Sr 12 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-012',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'C-Block – Electrical Room',
  'The DG power cable connected to the main electrical incomer panel is not properly glanded and is hanging from the top of the panel. The cable entry hole is left open, exposing the chamber. This poses risks of mechanical damage, dust ingress, rodent entry, and fire hazards.',
  'HIGH', 'OPEN',
  12, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Provide proper glanding for the DG power cable at the incomer panel. Seal the cable entry hole with approved fire-retardant material or gland plate. Ensure cables are clamped and supported to prevent hanging or strain.',
  'Main Incomer Electrical Panel',
  '2026-03-31', false
),

-- ── Sr 13 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-013',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'C-Block – Electrical Room',
  'In the common area power supply panel, cables are not properly dressed and clamped. Cable and feeder identification tags are missing, and routing is not clearly marked. This condition compromises safety, traceability, and compliance.',
  'MEDIUM', 'OPEN',
  13, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Perform proper cable dressing and clamping using approved supports and trays. Fix permanent cable and feeder identification tags on all circuits. Mark incoming and outgoing cable routes clearly as per approved SLD.',
  'Common Area Power Panel',
  '2026-03-31', false
),

-- ── Sr 14 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-014',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Rising Mains',
  'C-Block – Rising Main Shafts',
  'Rising main shafts are not properly cleaned, and finishing works are incomplete. Floor-wise platforms require attention to ensure proper holding strength and structural stability. This condition compromises safety, accessibility, and compliance.',
  'HIGH', 'OPEN',
  14, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Carry out cleaning and finishing works in all rising main shafts. 2. Inspect and reinforce floor-wise platforms to ensure adequate holding strength. 3. Provide protective covers and sealing to prevent dust, debris, and rodent entry.',
  'Rising Mains',
  '2026-03-31', false
),

-- ── Sr 15 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-015',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'C-Block – Electrical Room',
  'The power capacitor cable gland is not fixed properly, and the cable is hanging from the panel. Proper glanding methods have not been implemented. This poses risks of mechanical strain, dust ingress, and potential fire hazards.',
  'MEDIUM', 'OPEN',
  15, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Provide proper glanding for all power capacitor cables using approved glands. 2. Ensure cables are clamped and supported to prevent hanging or strain. 3. Seal cable entry points with fire-retardant gland plates or sealants.',
  'Capacitor Panel',
  '2026-03-31', false
),

-- ── Sr 16 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-016',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'UPS / Battery Systems',
  'C-Block – Electrical Room',
  'UPS battery bank terminal connections are found open, with several safety caps missing from most terminals. This exposes live terminals and increases the risk of accidental short circuits, shock hazards for personnel, and potential fire from battery bank fault.',
  'HIGH', 'OPEN',
  16, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Provide insulation caps for all battery terminals to prevent accidental contact. Ensure all open connections are properly covered with approved protective devices. Include terminal protection checks in the monthly preventive maintenance schedule.',
  'Battery Bank',
  '2026-03-31', false
),

-- ── Sr 17 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-017',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Fire Alarm & Detection',
  'C-Block – Fire Command Center',
  'Inside the Fire Command Center room, fire alarm panels are not provided with identification tags. Some panels are found in power-off condition, and the working status of each panel has not been confirmed. This compromises traceability, monitoring, and emergency readiness.',
  'HIGH', 'OPEN',
  17, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 2189:2019 (Selection, Installation, and Maintenance of Fire Detection and Alarm Systems), BIS IS 1646:2017 (Fire Safety of Buildings), and CEA Safety Regulations (2010, amended 2024).',
  'Fix permanent identification tags/boards on all fire alarm panels. Ensure all panels are powered ON and operational at all times. Obtain confirmation of working condition from the builder team and document it. Include fire alarm panels in the preventive maintenance schedule.',
  'Fire Command Center – Alarm Panels',
  '2026-03-31', false
),

-- ── Sr 18 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-018',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Fire Alarm & Detection',
  'C-Block – Fire Command Center',
  'Inside the Fire Command Center room, fire communication panels are not properly dressed. Identification tags, numbers, or names are missing for panels, cables, and accessories. The panels are full of dust and dirt, regular preventive maintenance activities are not being carried out, and testing history cards are not available.',
  'HIGH', 'OPEN',
  18, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Carry out proper cable dressing and clamping for fire communication panels. Fix permanent identification tags/numbers/names for panels, cables, and accessories. Implement regular preventive maintenance and cleaning of panels. Maintain testing history cards and PM records for traceability.',
  'Fire Command Center – Communication Panels',
  '2026-03-31', false
),

-- ── Sr 19 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-019',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Cable Trays & Cable Management',
  'C-Block – CCTV / Security Surveillance Room',
  'Inside the security surveillance camera room, power and network cables are lying directly on the ground without proper bifurcation or dressing. Standard secure cable-laying procedures have not been followed and identification tags are not provided, leading to poor segregation and unsafe installation practices.',
  'MEDIUM', 'OPEN',
  19, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1255:1983 (Installation and Maintenance of Power Cables), BIS IS 8623:1993 (Low-voltage switchgear and controlgear assemblies), and CEA Safety Regulations (2010, amended 2024).',
  'Carry out proper cable dressing and clamping using trays, conduits, or raceways. Ensure segregation of power and network cables to avoid interference and hazards. Follow standard secure cable-laying procedures as per IS codes. Fix identification tags for all cables to aid in maintenance and fault tracing.',
  'CCTV Room',
  '2026-03-31', false
),

-- ── Sr 20 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-020',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'C-Block – B1 Level (Ventilation Fan Panel)',
  'The ventilation fan panel is covered with dust and dirt. Cable identification tags are not provided, and gland earthing has not been implemented. Cables are not properly clamped on the tray, and temporary PVC tags are being used to fix cables instead of permanent clamping methods.',
  'MEDIUM', 'OPEN',
  20, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Clean the ventilation fan panel and maintain it under preventive maintenance schedules. Provide permanent cable identification tags as per IS standards. Implement proper cable glanding with earthing for all cables. Clamp cables securely on trays using approved saddles and supports.',
  'Ventilation Fan Panel',
  '2026-03-31', false
),

-- ── Sr 21 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-021',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'C-Block – B1 Level (Club House Main Electrical Panel)',
  'In the Club House main electrical panel, cables are not properly dressed and clamped. Gland earthing is missing for all cables. PVC glands have been used for some cables but are not properly fixed. Cable identification tags are also not available. This compromises safety, traceability, and compliance.',
  'MEDIUM', 'OPEN',
  21, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1255:1983 (Installation and Maintenance of Power Cables), BIS IS 3043:2018 (Earthing Code of Practice), and BIS IS 8623:1993 (Low-voltage switchgear and controlgear assemblies).',
  'Carry out proper cable dressing and clamping using approved trays, saddles, and supports. Provide gland earthing for all cables as per IS 3043. Replace PVC glands with properly fixed metallic glands of suitable size. Install permanent cable identification tags for traceability and maintenance.',
  'Club House Main Electrical Panel',
  '2026-03-31', false
),

-- ── Sr 22 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-022',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'LT Distribution Panels',
  'C-Block – B1 Level (Club House Panel Room)',
  'Inside the Club House panel room, multiple drain water pipelines are routed directly above the electrical panels and cable trays. This poses a major risk of water spillage onto electrical equipment in case of joint failure or pipe damage, compromising electrical safety and reliability.',
  'HIGH', 'OPEN',
  22, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1646:2017 (Fire Safety of Buildings).',
  'Reroute drain water pipelines away from electrical panels and cable trays. Provide protective covers or drip trays above panels where rerouting is not immediately feasible. Seal all pipe joints with approved leak-proof fittings. Conduct regular inspections of pipelines crossing near electrical installations.',
  'Club House Electrical Panel Room',
  '2026-03-31', false
),

-- ── Sr 23 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-023',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical', 'Cable Trays & Cable Management',
  'C-Block – B1 Level (Club House Panel Room)',
  'In the Club House panel room, visible wall gaps are observed at the cable tray entry points. These gaps pose a risk of rodents passing through the tray into the room. Additionally, a power socket has been installed without proper protection, conduit piping, or clamping.',
  'MEDIUM', 'OPEN',
  23, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Seal cable tray entry wall gaps with fire-retardant and rodent-proof material. Install the power socket with proper conduit piping and clamping as per IS standards. Ensure earthing and mechanical protection for all sockets and cable entries.',
  'Club House Panel Room',
  '2026-03-31', false
),

-- ── Sr 24 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-024',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Fire Hydrant & Sprinkler',
  'All Blocks – Fire Hydrant Posts',
  'Fire hydrant posts are not provided with proper identification tags or numbers as per the approved Fire Department layout plan. This omission compromises traceability, emergency readiness, and regulatory compliance.',
  'MEDIUM', 'OPEN',
  24, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1646:2017 (Fire Safety of Buildings), BIS IS 15325:2003 (Fire Fighting Equipment – Identification), and Fire Department guidelines, which mandate clear identification and numbering of hydrant posts.',
  'Install permanent identification tags/numbers on all fire hydrant posts as per the approved layout plan. Ensure uniform labeling for easy recognition during emergencies. Update site records and fire safety drawings to reflect hydrant identification. Conduct a joint inspection with the Fire Department to confirm compliance.',
  'All Fire Hydrant Posts',
  '2026-03-31', false
),

-- ── Sr 25 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-025',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Fire Hydrant & Sprinkler',
  'All Blocks – Fire Hydrant Main Lines',
  'Fire hydrant main line valves are found closed/shut at multiple locations and blocks without any valid reason or operational requirement. The fire system valves should only be closed through a proper authorized approval mechanism and must not remain shut for longer durations, as this compromises the safety of residents and property.',
  'HIGH', 'OPEN',
  25, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1646:2017 (Fire Safety of Buildings), NFPA 25 (Inspection, Testing, and Maintenance of Water-Based Fire Protection Systems), and Fire Department guidelines, which mandate that hydrant valves remain open and operational at all times unless under authorized maintenance.',
  'Ensure all fire hydrant main line valves remain open and operational at all times. Implement a formal approval mechanism for any temporary valve closure with documented justification. Conduct regular inspections to verify valve positions and functionality. Train facility staff on fire system operational protocols. Maintain records of valve status and approvals in fire safety logs.',
  'Fire Hydrant / Sprinkler System',
  '2026-03-31', false
),

-- ── Sr 26 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-026',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Fire Hydrant & Sprinkler',
  'All Blocks – All Floors',
  'Across all blocks and floors, fire hydrant and sprinkler pipelines do not have flow-direction markings. This omission compromises emergency readiness, traceability, and compliance with approved fire safety layout plans.',
  'MEDIUM', 'OPEN',
  26, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1646:2017 (Fire Safety of Buildings), BIS IS 15325:2003 (Fire Fighting Equipment – Identification), NFPA 25, and Fire Department guidelines, which mandate clear directional markings on fire protection pipelines.',
  'Provide permanent flow-direction markings on all hydrant and sprinkler pipelines across blocks and floors. Use standardized arrows and color coding as per IS/NFPA guidelines. Update fire safety drawings and site records to reflect directional markings.',
  'Fire Hydrant / Sprinkler System',
  '2026-03-31', false
),

-- ── Sr 27 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-027',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Portable Fire Extinguishers',
  'All Blocks',
  'Fire extinguishers do not have evidence of regular maintenance. The condition of the extinguishers at the time of inspection and their working status is not available. Signages are missing in some places. Preventive Maintenance (PM) data cards are not placed on the extinguishers. This omission compromises traceability, readiness, and compliance.',
  'MEDIUM', 'OPEN',
  27, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 2190:2010 (Selection, Installation, and Maintenance of Portable Fire Extinguishers), NFPA 10 (Standard for Portable Fire Extinguishers), and Fire Department guidelines, which mandate documented inspection, maintenance, and tagging of extinguishers.',
  '1. Conduct regular preventive maintenance and inspection of all fire extinguishers. 2. Place PM data cards/tags on each extinguisher, recording inspection dates and working condition. 3. Ensure placing of signages for fire extinguishers. 4. Ensure quarterly/yearly servicing and refilling by authorized agencies.',
  'Fire Fighting System – Portable Extinguishers',
  '2026-03-31', false
),

-- ── Sr 28 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-028',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Fire Hydrant & Sprinkler',
  'All Blocks',
  'Power cables are tied to the fire sprinkler pipeline and laid along the line. This is a clear non-compliance and poses a significant hazard, as electrical cables must not be routed or supported on fire protection systems. Such routing compromises both electrical safety and fire system reliability.',
  'HIGH', 'OPEN',
  28, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Immediately remove power cables from fire sprinkler pipelines. 2. Provide dedicated trays, conduits, or raceways for electrical cable routing. 3. Ensure segregation of electrical and fire protection systems as per IS standards.',
  'Fire Fighting System – Sprinkler Pipeline',
  '2026-03-31', false
),

-- ── Sr 29 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-029',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Fire Hydrant & Sprinkler',
  'All Blocks',
  'Overhead sprinkler pipeline support clamps are not properly fixed. Several clamps are hanging loose without holding the pipeline, and some clamps are open or not secured correctly. This condition compromises the stability of the fire protection system and poses a risk of pipeline displacement or failure.',
  'MEDIUM', 'OPEN',
  29, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Properly fix and tighten all support clamps to securely hold sprinkler pipelines. 2. Replace damaged or open clamps with approved fire-rated supports. 3. Ensure spacing and load distribution of clamps as per IS standards. 4. Conduct periodic inspections to verify clamp integrity and pipeline stability.',
  'Fire Hydrant / Sprinkler System',
  '2026-03-31', false
),

-- ── Sr 30 ─────────────────────────────────────────────────────────────────────
(
  'snag-bldg-audit-2026-030',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Fire Safety', 'Ventilation & Plumbing',
  'All Blocks',
  'Ventilation jet fans are not provided with identification tags, asset tags, or numbering. In addition, fire pipelines and CPC water pipelines are missing flow-direction markings. This omission compromises traceability, emergency readiness, and compliance with approved fire safety plan layouts.',
  'MEDIUM', 'OPEN',
  30, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1646:2017 (Fire Safety of Buildings), BIS IS 15325:2003 (Fire Fighting Equipment – Identification), and NFPA 25.',
  '1. Provide permanent identification tags/asset numbers for all ventilation jet fans. 2. Install flow-direction markings on fire pipelines and CPC water pipelines across all blocks and floors. 3. Use standardized arrows and color coding (red for fire lines, blue for water lines) as per IS/NFPA guidelines.',
  'Ventilation / Plumbing',
  '2026-03-31', false
)

ON CONFLICT (id) DO NOTHING;
