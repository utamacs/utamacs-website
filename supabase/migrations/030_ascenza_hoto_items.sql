-- Migration 030: Seed HOTO items from Ascenza Global Infra Care Pvt Ltd scope of work
-- Source: Ascenza HOTO assessment scope document (March 2026)
-- Covers: Statutory Compliance, Technical Due Diligence (35+ systems), AMC, Snagging,
--         Security & Fire Safety, As-Built Drawings, Asset/Inventory, Conditional Assessment

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. STATUTORY COMPLIANCE
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-stat-001',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'GHMC Approved Drawings Handover',
 'Collect and verify GHMC-approved building plans, layout drawings, and structural drawings from builder. Confirm as-built matches approved plans.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-002',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'NOC Collection — Fire, Lift, Electrical, Environment',
 'Obtain copies of all statutory No Objection Certificates: TSFIRE (fire NOC), TSSPDCL (electrical connection), CPCB/TSPCB (environment), and lift clearance certificates.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-003',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Land Documents — Title Deed, Patta, Encumbrance Certificate',
 'Verify land title deed, Patta (registered sale deed), Encumbrance Certificate, and mutation entries to confirm clear title for common areas.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-004',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'RERA Registration and Completion Certificate',
 'Obtain RERA project registration documents, completion/occupancy certificate (CC/OC) from GHMC, and verify project details match RERA portal entries.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-005',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Water and Sewerage Connection Permissions',
 'Collect HMWS&SB / local body connection permissions for domestic water supply and sewerage outfall. Verify connection charges paid and meters installed.',
 'MEDIUM', 'NOT_STARTED', 'secretary', false, false),

('hoto-stat-006',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Society Registration Documents',
 'Verify cooperative society registration certificate, bye-laws, MOA/AOA, and member share certificates. Confirm all statutory filings are current.',
 'MEDIUM', 'NOT_STARTED', 'secretary', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. TECHNICAL DUE DILIGENCE — LT ELECTRICAL
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-lt-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — LT Electrical',
 'LT Panel and Distribution Board Inspection',
 'Inspect all LT main panels, distribution boards (DBs), and sub-DBs. Verify ratings, bus bar sizing, MCB/MCCB/ELCB ratings, labelling, earthing connections, and single-line diagrams.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-lt-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — LT Electrical',
 'LT Cable Routing and Termination Audit',
 'Verify LT cable sizes, routing through cable trays and conduits, insulation integrity, proper terminations at both ends, and cable identification tags.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-lt-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — LT Electrical',
 'Earthing System Verification',
 'Test and verify main earthing pits, electrode resistance values (< 1 ohm for equipment earth), earth continuity across all DBs, and surge protection devices.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-lt-004',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — LT Electrical',
 'Common Area Lighting — External and Internal',
 'Audit all common area lighting: lobby, corridors, staircases, podium, parking, external landscape lighting, and pathway lights. Check fixtures, controls, and timer/sensor functionality.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-lt-005',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — LT Electrical',
 'Power Factor Correction and APFC Panel',
 'Verify Automatic Power Factor Correction (APFC) panel operation, capacitor bank ratings, and current power factor at TSSPDCL meter. Confirm no penalty charges.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. TECHNICAL DUE DILIGENCE — HT ELECTRICAL
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-ht-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — HT Electrical',
 'HT Yard Equipment Documentation and Handover',
 'Collect all HT equipment manuals, test certificates, commissioning reports for transformer, VCB, LA, DO fuses, capacitor bank, and metering cubicle.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-ht-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — HT Electrical',
 'HT Connection Agreement and TSSPDCL Service Documents',
 'Obtain and file TSSPDCL HT service connection agreement, sanctioned load documents, metering arrangement approval, and any pending rectification notices.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-ht-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — HT Electrical',
 'Transformer Oil and Test Reports',
 'Obtain latest BDV (Breakdown Voltage) test report, DGA (Dissolved Gas Analysis) report, and insulation resistance test reports for the 500 KVA / 11 KV transformer.',
 'HIGH', 'NOT_STARTED', 'executive', true, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. TECHNICAL DUE DILIGENCE — DIESEL GENERATORS
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-dg-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Diesel Generators',
 'DG Set Technical Inspection and Load Test',
 'Inspect all DG sets: engine condition, alternator, control panel, ATS/AMF panel, exhaust routing, acoustic enclosure, and fuel tank. Conduct load test at 50% and 75% capacity.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-dg-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Diesel Generators',
 'DG Documentation — Warranty, CPCB Certificate, Logbooks',
 'Collect DG warranty certificates, CPCB (Central Pollution Control Board) emissions compliance certificates, engine hour logs, and maintenance logbooks from builder.',
 'HIGH', 'NOT_STARTED', 'secretary', true, false),

('hoto-dg-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Diesel Generators',
 'Fuel Management System and Storage Tank',
 'Verify diesel storage tank capacity, level indicator, fuel pump, pipelines, isolation valves, and spill containment. Confirm PESO/explosives clearance if applicable.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. TECHNICAL DUE DILIGENCE — ELEVATORS / LIFTS
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-lift-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Elevators',
 'Elevator Statutory Inspection and Fitness Certificate',
 'Verify Telangana Factories/Boilers Department fitness certificates for all lifts. Ensure certificates are current. Obtain load test reports and safety compliance records.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-lift-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Elevators',
 'Elevator Technical Handover — OEM Manuals, Warranty, AMC',
 'Collect OEM manuals, warranty documents, and AMC contracts for all elevators (passenger + service). Verify ARD (Automatic Rescue Device) and intercom functionality.',
 'HIGH', 'NOT_STARTED', 'secretary', false, false),

('hoto-lift-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Elevators',
 'Elevator Machine Room and Shaft Inspection',
 'Inspect machine room condition, rope and pulley condition, guide rails, counterweight, buffer, door locks, and pit condition for all elevator shafts.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. TECHNICAL DUE DILIGENCE — FIRE FIGHTING AND ALARM
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-fire-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Fire Fighting',
 'Fire Fighting System — Hydrant, Sprinkler, and Pump Audit',
 'Inspect fire hydrant network, sprinkler heads and zones, fire pumps (main, jockey, diesel), terrace tank capacity, and underground sump. Test pressure and flow at critical points.',
 'CRITICAL', 'NOT_STARTED', 'president', true, false),

('hoto-fire-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Fire Fighting',
 'Fire NOC and TSFIRE Compliance Documentation',
 'Obtain TSFIRE No Objection Certificate, fire audit report, and all outstanding compliance commitments. Confirm fire NOC is valid for current occupancy.',
 'CRITICAL', 'NOT_STARTED', 'president', true, false),

('hoto-fire-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Fire Alarm',
 'Fire Alarm and Detection System Commissioning',
 'Verify addressable fire alarm panel, smoke/heat detectors, manual call points, hooters, and zone wiring across all buildings and common areas. Test end-to-end alarm sequence.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-fire-004',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Fire Fighting',
 'Portable Fire Extinguishers Inventory and Certification',
 'Count and verify all portable fire extinguishers (CO2, DCP, clean agent) — type, capacity, last refill/hydro-test date, and placement as per fire plan. Update register.',
 'HIGH', 'NOT_STARTED', 'executive', false, false),

('hoto-fire-005',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Fire Fighting',
 'Fire Hose Reels and Fire Doors Inspection',
 'Inspect all fire hose reel cabinets (hose condition, nozzle, valve), and verify fire-rated doors at stairwells and fire escape routes for self-closing mechanism and seals.',
 'HIGH', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. TECHNICAL DUE DILIGENCE — WATER SUPPLY
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-water-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Water Supply',
 'Domestic Water Supply (DWS) System Audit',
 'Audit UGSS/OHSS tanks, pumping sets, header lines, riser pipes, and individual flat connection valves. Verify tank capacities match design specs. Test pressure at top-floor flats.',
 'HIGH', 'NOT_STARTED', 'executive', false, false),

('hoto-water-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Water Supply',
 'Flushing Water System (FWS) and Grey Water Reuse',
 'Inspect dedicated flushing water (STP-treated water) network, OHSS, pumping, and control valves. Verify segregation from potable water lines. Test quality compliance.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-water-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Water Supply',
 'Water Treatment Plant (WTP) Commissioning and Handover',
 'Inspect WTP components: pre-filters, softener, RO plant (if applicable), chlorination system, and online TDS/pH monitors. Collect commissioning reports and O&M manual.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-water-004',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Water Supply',
 'Borewell and Submersible Pump Audit',
 'Document all borewells: depth, yield test report, pump capacity, panel details, and CGWA registration (if required). Test pump operation and verify starter panel condition.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-water-005',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Water Supply',
 'Hydro-Pneumatic System Inspection',
 'Inspect hydro-pneumatic pressurization system (pressure vessel, pump set, pressure switches, control panel) for domestic water pressurization. Test pressure range and cut-in/cut-out.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. TECHNICAL DUE DILIGENCE — SEWAGE TREATMENT PLANT (STP)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-stp-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — STP',
 'STP Commissioning Report and TSPCB Consent',
 'Obtain STP commissioning report, design capacity (KLD), TSPCB Consent to Operate (CTO), and latest treated water quality test report (BOD/COD/TSS parameters).',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stp-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — STP',
 'STP Equipment and Process Audit',
 'Inspect STP mechanical and electrical equipment: screening chamber, aeration blowers, clarifier, sludge dewatering, UV/chlorination unit, and control panel. Collect O&M manual.',
 'HIGH', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. TECHNICAL DUE DILIGENCE — HVAC AND VENTILATION
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-hvac-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — HVAC',
 'Club House HVAC System Handover',
 'Inspect club house air conditioning units (split/VRF/central), AHUs, ductwork, and controls. Collect OEM manuals, commissioning reports, and warranty documents.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-hvac-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — HVAC',
 'Fresh Air and Exhaust Ventilation Systems',
 'Audit all fresh air handling units and exhaust fans in basement, lobbies, common toilets, pump rooms, and DG rooms. Test airflow and statutory minimum air changes.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. TECHNICAL DUE DILIGENCE — UPS AND BATTERIES
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-ups-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — UPS / Battery',
 'UPS Systems and Battery Bank Inspection',
 'Inspect all UPS units (common area lighting, CCTV, access control), battery bank condition, backup time test, and rectifier/inverter health. Collect OEM manuals and warranty.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. TECHNICAL DUE DILIGENCE — SOLAR
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-solar-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Solar',
 'Solar PV System Audit and Generation Log',
 'Inspect solar panels, mounting structure, inverters, generation meters, and net metering arrangement with TSSPDCL. Obtain commissioning report, generation log, and DISCOOM approval letter.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. TECHNICAL DUE DILIGENCE — SECURITY AND SURVEILLANCE
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-sec-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Security and Surveillance',
 'CCTV System — Camera Coverage and NVR Audit',
 'Verify all CCTV camera locations against design drawings, NVR storage capacity (minimum 30 days), recording quality, and remote viewing setup. Document any blind spots.',
 'HIGH', 'NOT_STARTED', 'executive', false, false),

('hoto-sec-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Security and Surveillance',
 'Access Control System — Boom Barriers and Intercom',
 'Inspect boom barriers at entry/exit, RFID/card readers, visitor management terminals, video door phones, and intercom network. Test fail-safe operation during power failure.',
 'HIGH', 'NOT_STARTED', 'executive', false, false),

('hoto-sec-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Security and Surveillance',
 'Security Guard Room and Infrastructure',
 'Verify security room facilities (CCTV monitor, communication, lighting, seating), guard patrol routes, visitor register system, and perimeter fencing/wall integrity.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. TECHNICAL DUE DILIGENCE — ICT (PA, OFC, TV, INTERCOM)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-ict-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — ICT',
 'Public Address (PA) System Handover',
 'Test PA system amplifiers, speakers in common areas, and emergency announcement functionality. Collect OEM manuals and wiring diagrams.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-ict-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — ICT',
 'OFC, Internet, Cable TV, and Intercom Infrastructure',
 'Verify optical fibre cabling, internet distribution points, cable TV splitter network, and telephone/intercom backbone. Confirm ISP agreements and active connections.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. TECHNICAL DUE DILIGENCE — BMS AND ELMEASURE
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-bms-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — BMS / Elmeasure',
 'BMS and Elmeasure Energy Monitoring Handover',
 'Verify Building Management System (BMS) or Elmeasure energy monitoring system: panel displays, sub-metering points, historical data access, and alarm setpoints. Collect software licenses.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. TECHNICAL DUE DILIGENCE — AVIATION WARNING LIGHTS
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-avl-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Aviation Lights',
 'Aviation Obstruction Lighting — DGCA Compliance',
 'Verify aviation warning lights on building terraces (red/white as applicable), automatic dusk-to-dawn control, UPS backup, and DGCA compliance certificate if buildings exceed 45m.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. TECHNICAL DUE DILIGENCE — DEWATERING
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-dew-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Dewatering',
 'Basement Dewatering Pump System',
 'Inspect basement/pit dewatering pump sets, float switches, auto-start control panels, discharge routing, and backup pump availability. Test operation in both manual and auto modes.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. TECHNICAL DUE DILIGENCE — GAS BANK
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-gas-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Gas Bank',
 'Piped Gas Supply System — PESO Clearance and Handover',
 'Verify piped gas (PNG/LPG bank) installation, PESO/CEA clearance, gas bank enclosure, pressure regulators, isolation valves, and leak detection system. Obtain supply agreement from provider.',
 'HIGH', 'NOT_STARTED', 'president', true, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. TECHNICAL DUE DILIGENCE — CIVIL/STRUCTURAL
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-civil-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Civil',
 'Building Façade and External Cladding Inspection',
 'Inspect external wall finishes, tile/stone cladding adhesion, sealant joints, expansion joints, and balcony railings across all blocks. Document defects and builder responsibility.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-civil-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Civil',
 'Expansion Joints and Waterproofing Audit',
 'Inspect structural expansion joints at building interfaces, terrace waterproofing, basement retaining wall waterproofing, and plinth protection. Test for active leakages.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-civil-003',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Civil',
 'Retaining Walls and Compound Boundary Walls',
 'Inspect all retaining walls, boundary compound walls, gate pillars, and perimeter security walls for structural integrity, cracks, settlement, and drainage weep holes.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 19. TECHNICAL DUE DILIGENCE — CLUB HOUSE AND AMENITIES
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-club-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Club House',
 'Club House Civil, MEP, and Amenities Inspection',
 'Inspect club house structure, finishes, gymnasium equipment, indoor sports facilities, restrooms, kitchen (if any), and all MEP services. Collect equipment warranty documents.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-club-002',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Club House',
 'Swimming Pool Equipment and Water Quality',
 'Inspect pool structure, filtration pump, chemical dosing system, water quality (pH/chlorine), deck finishing, safety equipment (ropes, depth markers, ring buoys), and pool enclosure.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 20. TECHNICAL DUE DILIGENCE — LANDSCAPING AND IRRIGATION
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-land-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Landscaping',
 'Landscaping, Irrigation, and Water Features Handover',
 'Verify landscape design vs. execution, drip/sprinkler irrigation system, fountains/water features (pump, nozzles, lights), and tree/plant inventory. Collect irrigation controller documentation.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 21. TECHNICAL DUE DILIGENCE — WASTE MANAGEMENT
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-waste-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Waste Management',
 'Solid Waste Management System and Composting',
 'Inspect waste collection rooms, segregated bins (wet/dry/hazardous), OWC/composting unit (if provided), and waste disposal agreement with GHMC/MCTSC. Verify collection schedules.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 22. TECHNICAL DUE DILIGENCE — SIGNAGES
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-sign-001',
 '00000000-0000-0000-0000-000000000001',
 'Technical Due Diligence — Signages',
 'Safety, Regulatory, and Directional Signage Audit',
 'Verify fire escape route signage (luminous/illuminated), safety warning signs (electrical rooms, pump rooms), parking directional signs, and statutory signages (RERA, society registration).',
 'LOW', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 23. AMC DUE DILIGENCE
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-amc-001',
 '00000000-0000-0000-0000-000000000001',
 'AMC Due Diligence',
 'Existing AMC Contracts Review — Elevators, DG, Fire',
 'Collect and review all existing Annual Maintenance Contracts (elevators, DG sets, fire systems, STP). Verify scope, coverage, response SLAs, and renewal dates. Decide on continuation or re-tendering.',
 'HIGH', 'NOT_STARTED', 'secretary', false, false),

('hoto-amc-002',
 '00000000-0000-0000-0000-000000000001',
 'AMC Due Diligence',
 'Vendor and Service Provider Contact Directory',
 'Compile a contact directory of all OEMs, AMC vendors, utility providers, and statutory bodies with contract reference numbers, emergency contacts, and escalation hierarchy.',
 'MEDIUM', 'NOT_STARTED', 'secretary', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 24. SNAGGING — COMMON AREAS
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-snag-001',
 '00000000-0000-0000-0000-000000000001',
 'Snagging — Common Areas',
 'Common Area Snagging — Lobbies, Corridors, and Staircases',
 'Conduct detailed snagging of all lobbies, lift lobbies, corridors, staircases, and common toilets across all blocks. Document finish defects, plumbing issues, and builder rectification timelines.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-snag-002',
 '00000000-0000-0000-0000-000000000001',
 'Snagging — Common Areas',
 'External Common Areas — Parking, Roads, Pathways',
 'Snagging of surface car parking, basement parking (striping, wheel stops, speed humps), internal roads, footpaths, drain covers, and kerb stones. Document level and drainage issues.',
 'HIGH', 'NOT_STARTED', 'executive', true, false),

('hoto-snag-003',
 '00000000-0000-0000-0000-000000000001',
 'Snagging — Common Areas',
 'Terrace and Roof Common Areas Snagging',
 'Inspect terrace finishes, parapet walls, rainwater outlets, overhead tank housing, equipment mounted on terrace, and access hatches. Document waterproofing defects and builder liability.',
 'HIGH', 'NOT_STARTED', 'executive', true, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 25. SECURITY AND FIRE SAFETY DUE DILIGENCE
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-secfs-001',
 '00000000-0000-0000-0000-000000000001',
 'Security and Fire Safety Due Diligence',
 'Fire Safety Management Plan and Emergency Procedures',
 'Prepare or obtain fire safety management plan, emergency evacuation procedures, fire warden assignments, and mock drill schedule. Confirm TSFIRE inspection schedule.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-secfs-002',
 '00000000-0000-0000-0000-000000000001',
 'Security and Fire Safety Due Diligence',
 'Security Operations Protocol and Guard Deployment Plan',
 'Define and document security guard deployment (posts, shift timings, duties), visitor management procedure, vehicle access control policy, and emergency response protocol.',
 'MEDIUM', 'NOT_STARTED', 'secretary', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 26. AS-BUILT DRAWINGS DUE DILIGENCE
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-asbuilt-001',
 '00000000-0000-0000-0000-000000000001',
 'As-Built Drawings Due Diligence',
 'As-Built Drawing Collection — All Disciplines',
 'Collect as-built drawings for all disciplines: architectural, structural, LT/HT electrical, plumbing (DWS/SWS/FWS), fire fighting, HVAC, CCTV, fire alarm, landscaping, and STP. Store in society archive.',
 'HIGH', 'NOT_STARTED', 'secretary', false, false),

('hoto-asbuilt-002',
 '00000000-0000-0000-0000-000000000001',
 'As-Built Drawings Due Diligence',
 'As-Built Drawing Verification vs. Actual Installation',
 'Cross-verify key as-built drawings against actual site installation for LT electrical, fire fighting, and water supply — particularly underground runs and shaft routing.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 27. ASSET AND INVENTORY VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-asset-001',
 '00000000-0000-0000-0000-000000000001',
 'Asset and Inventory Verification',
 'Mechanical and Electrical Equipment Asset Register',
 'Create a comprehensive asset register for all major M&E equipment: DG sets, transformers, pumps, elevators, BMS, solar, UPS, CCTV NVRs, fire panel, etc. — with make, model, serial number, capacity, and warranty expiry.',
 'HIGH', 'NOT_STARTED', 'secretary', false, false),

('hoto-asset-002',
 '00000000-0000-0000-0000-000000000001',
 'Asset and Inventory Verification',
 'Common Area Furniture, Fixtures, and Fittings Inventory',
 'Inventory all handover items for common areas: lobby furniture, gym equipment, club house fixtures, signage boards, garden furniture, and pool equipment. Match against project handover schedule.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false),

('hoto-asset-003',
 '00000000-0000-0000-0000-000000000001',
 'Asset and Inventory Verification',
 'Spare Parts and Consumables Handover',
 'Collect mandatory spare parts from builder: extra tiles (10% batch stock), paint (one coat quantity), electrical fuses/lamps, filter media for STP/WTP, and DG maintenance kit.',
 'MEDIUM', 'NOT_STARTED', 'executive', false, false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 28. CONDITIONAL ASSESSMENT
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-cond-001',
 '00000000-0000-0000-0000-000000000001',
 'Conditional Assessment',
 'Active Leakage and Seepage Survey — All Blocks',
 'Conduct building-wide survey to identify all active water leakages, seepage, dampness, and efflorescence in basement, podium, terraces, and common areas. Map defects and obtain builder commitment for rectification.',
 'CRITICAL', 'NOT_STARTED', 'president', true, false),

('hoto-cond-002',
 '00000000-0000-0000-0000-000000000001',
 'Conditional Assessment',
 'Structural Crack and Settlement Survey',
 'Document all visible cracks (hairline vs. structural), settlement cracks at plinth/columns, and expansion joint failures. Obtain structural engineer assessment where required.',
 'HIGH', 'NOT_STARTED', 'president', true, false);
