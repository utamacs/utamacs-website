-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 027: Audit-observation fields for snag_items + HT inspection seed
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Extend snag_items with fields required by external audit / inspection data
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE snag_items
  ADD COLUMN IF NOT EXISTS snag_source             TEXT NOT NULL DEFAULT 'INTERNAL',
  -- 'INTERNAL' | 'EXTERNAL_AUDIT' | 'BUILDER_INSPECTION'
  ADD COLUMN IF NOT EXISTS audit_ref_no            INTEGER,           -- Sr No from audit sheet
  ADD COLUMN IF NOT EXISTS audit_source            TEXT,              -- Auditor name / org
  ADD COLUMN IF NOT EXISTS audit_date              DATE,              -- Date of audit
  ADD COLUMN IF NOT EXISTS compliance_requirement  TEXT,              -- Regulation / standard violated
  ADD COLUMN IF NOT EXISTS recommendation          TEXT,              -- Recommended corrective action
  ADD COLUMN IF NOT EXISTS equipment_machinery     TEXT,              -- Equipment / asset involved
  ADD COLUMN IF NOT EXISTS before_image_url        TEXT,              -- Photo before rectification
  ADD COLUMN IF NOT EXISTS after_image_url         TEXT,              -- Photo after rectification
  ADD COLUMN IF NOT EXISTS action_taken            TEXT,              -- Remarks / work done so far
  ADD COLUMN IF NOT EXISTS responsible_person_name TEXT,              -- Free-text name (external parties)
  ADD COLUMN IF NOT EXISTS expected_closure_date   DATE,              -- EDC from audit sheet
  ADD COLUMN IF NOT EXISTS final_remarks           TEXT;              -- Auditor's final remarks

-- Supporting index for audit source queries
CREATE INDEX IF NOT EXISTS idx_snag_items_source
  ON snag_items(society_id, snag_source) WHERE NOT deleted;

CREATE INDEX IF NOT EXISTS idx_snag_items_audit_date
  ON snag_items(society_id, audit_date) WHERE snag_source = 'EXTERNAL_AUDIT';


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Seed: March 2026 HT Infrastructure Audit — Urban Trilla Apartments
--    Auditor: Jyothikumar Kudumu  |  Location: HT Yard
--    25 observations (20 High, 5 Moderate, 0 Low)
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
  'snag-ht-audit-2026-001',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'DP Structure',
  'External – DP Structure (EB Incomer)',
  'The EB power supply to UTA, fed from the Rural Power 11 kV overhead line, does not have an isolation mechanism installed at the associated distribution pole (DP) structure.',
  'HIGH', 'OPEN',
  1, 'Jyothikumar Kudumu', '2026-03-31',
  'CEA Regulation 12 & 13: Requires provision of switching and isolation devices on overhead lines and distribution transformers for safe operation and maintenance.',
  'Provision of a power isolation mechanism at the DP structure is required for safety of the system/personnel and compliance.',
  'DP Structure – EB Incomer',
  '2026-03-31', false
),

-- ── Sr 2 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-002',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'DP Structure',
  'External – DP Structure (EB Incomer)',
  'At the DP structure, a spare HT cable with proper termination is found hanging. The end termination lugs are not adequately insulated, posing a potential safety hazard and non-compliance. Uninsulated lugs increase risk of accidental contact and flashover.',
  'HIGH', 'OPEN',
  2, 'Jyothikumar Kudumu', '2026-03-31',
  'CEA Safety Regulations (2010, amended 2024), Regulation 12/13 regarding insulation and protection of live parts.',
  '1. Provide proper insulation sleeves or covers for the HT cable termination lugs. 2. Ensure the spare cable is securely fixed and protected to avoid accidental contact to HT power lines.',
  'DP Structure – EB Incomer',
  '2026-03-31', false
),

-- ── Sr 3 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-003',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Cables',
  'HT Yard – HT Cables',
  'In the HT yard, HT power cables are laid directly on the open surface without adequate protection. No cable trench or protective covering has been provided to ensure the safe and secure routing of HT cables.',
  'HIGH', 'OPEN',
  3, 'Jyothikumar Kudumu', '2026-03-31',
  'IS 732:2019 – Electrical Wiring Installations, Section 5.2.3: Cables must be installed with mechanical protection. Section 5.3.1: Underground or trench installation is recommended for HT cables in open yards.',
  'Standard underground laying with proper mechanical protection or trench installation is recommended for HT cables in open yards.',
  'HT Cables',
  '2026-03-31', false
),

-- ── Sr 4 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-004',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Cables',
  'HT Yard – HT Cables',
  'A spare HT cable with a termination joint is lying on the ground, covered only with temporary PVC wrapping. The opposite end is mounted on the pole without proper insulation. Exposed terminations increase risk of electrocution and flashover.',
  'HIGH', 'OPEN',
  4, 'Jyothikumar Kudumu', '2026-03-31',
  'IS 732:2019 requirements for mechanical protection and insulation of high-voltage cable terminations.',
  '1. Provide permanent insulation for all HT cable termination lugs or approved insulating covers. 2. Relocate the spare HT cable into a dedicated trench or protective enclosure to prevent accidental contact and mechanical damage.',
  'HT Cables',
  '2026-03-31', false
),

-- ── Sr 5 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-005',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Metering Equipment',
  'HT Yard – HT Metering Equipment (CT/PT Box)',
  '1. HT cable entry points into the Metering cubicle (CT/PT box) are not properly sealed — allows dust, dirt, and moisture ingress, which can lead to insulation damage or flashover. 2. HT cables are not properly clamped; GI wires used instead of approved cable clamps. 3. HT cable joint earth ribbon strip is hanging without proper termination to the earth strip.',
  'HIGH', 'OPEN',
  5, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliance with BIS IS 732:2019 (Section 5.2.3, 6.1.2); BIS IS 1255:1983 (installation and maintenance of power cables); BIS IS 3043:2018 (Code of practice for earthing).',
  '1. Seal all HT cable entry points using approved cable glands or sealing compounds. 2. Replace GI wire supports with standard HT cable clamps. 3. Properly terminate the earth ribbon strip to the designated earth strip using approved connectors and verify continuity.',
  'HT Metering Equipment (CT/PT Box)',
  '2026-03-31', false
),

-- ── Sr 6 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-006',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Breakers',
  'HT Yard – HT Breakers',
  '1. HT breakers are currently in operation under Local Mode. 2. Fault indication lights are observed glowing on both HT breakers. 3. The termination chambers of the HT breakers could not be inspected as the equipment was energized.',
  'MEDIUM', 'OPEN',
  6, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Ensure breakers are operated in Remote mode to maintain monitoring and control. 2. Investigate the cause of fault indication lights and rectify abnormalities. 3. Conduct a detailed inspection of HT breaker termination chambers after safely isolating the power supply. 4. HT Breaker field test and commissioning reports are to be checked.',
  'HT Breakers',
  '2026-03-31', false
),

-- ── Sr 7 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-007',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Power Transformer',
  'HT Yard – Power Transformer',
  'The input HT cable termination at the power transformer is not properly connected. Small-sized flat washers have been used, resulting in inadequate surface contact between the lug and the bolt. This can lead to loose contact, overheating, eventual failure, flashover risk, and extended EB power downtime.',
  'HIGH', 'OPEN',
  7, 'Jyothikumar Kudumu', '2026-03-31',
  'IS 1255:1983 (Code of practice for installation and maintenance of power cables).',
  '1. Replace small flat washers with appropriate spring washers or conical washers to ensure firm contact. 2. Re-terminate the HT cable lugs with proper torque tightening as per manufacturer''s specifications. 3. Conduct periodic thermographic inspection post-rectification to confirm no hotspots at the termination.',
  'Power Transformer',
  '2026-03-31', false
),

-- ── Sr 8 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-008',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Power Transformer',
  'HT Yard – Power Transformer',
  'HT cable entry into the transformer marshalling box shows visible gaps at the bottom plate (inside and below the box). These gaps permit ingress of dust, dirt, and moisture, particularly during the winter season, which can lead to deterioration of cable joints, flashover risk at the transformer input, and extended EB power downtime.',
  'HIGH', 'OPEN',
  8, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Seal all cable entry points and bottom plate gaps using approved cable glands, sealing compounds, or metallic covers. 2. Ensure the marshalling box achieves minimum IP54/IP55 protection rating against dust and moisture ingress.',
  'Power Transformer',
  '2026-03-31', false
),

-- ── Sr 9 ──────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-009',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Cables',
  'HT Yard – Power Cables',
  'Inside the HT yard, cables and pipes are laid directly on the ground without proper mechanical protection or clamping. This arrangement exposes them to dust, dirt, moisture, and mechanical damage, creating unsafe conditions and non-compliance. Risk of mechanical damage leading to cable faults, outages, and safety hazards from exposed HT cables and pipes.',
  'HIGH', 'OPEN',
  9, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Provide dedicated trenches/underground installations with protective covers for all cables and pipes. 2. Install approved clamps and supports to secure cables and maintain mechanical stability.',
  'Power Cables',
  '2026-03-31', false
),

-- ── Sr 10 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-010',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Yard',
  'HT Yard – Ground Surface',
  'The HT yard ground surface is uneven, with visible earth soil exposed in multiple areas. Proper ground levelling has not been carried out, and spread of 40 mm granite pebbles/chips is inadequate. Unwanted materials and spare cables are lying within the yard, creating unsafe conditions. Risk includes moisture accumulation, reduced insulation resistance, and trip hazards.',
  'HIGH', 'OPEN',
  10, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliance with BIS IS 732:2019 (Section 5.2.3, 6.1.2).',
  '1. Carry out proper ground levelling across the HT yard. 2. Provide adequate 40 mm granite pebbles/chips uniformly (100 mm compacted thickness). Ensure stone layer does not cover inspection chambers or earth pits. 3. Remove unwanted materials and spare cables.',
  'HT Yard Inside Ground Surface',
  '2026-03-31', false
),

-- ── Sr 11 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-011',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Yard',
  'HT Yard',
  'HT/MV installations located in the open yard do not have adequate rainwater protection or ingress prevention measures. Visible gaps and lack of sealing at HT cable chambers expose the equipment to moisture during rainy and winter seasons. This increases the risk of flashover in HT bus chambers and cable joints, potentially leading to prolonged EB power outages.',
  'HIGH', 'OPEN',
  11, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Provide rainwater protection structures — canopies or sheds covering all sides — for all HT/MV installations in the open yards.',
  'HT Yard',
  '2026-03-31', false
),

-- ── Sr 12 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-012',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Yard',
  'HT Yard – Borewell',
  'An underground borewell is located inside the HT transformer yard and near the HT breaker panel. This poses a significant safety hazard due to the risk of water ingress and moisture accumulation. The presence of a borewell within the HT yard is non-compliant.',
  'HIGH', 'OPEN',
  12, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Relocate or properly seal the borewell opening away from HT installations. 2. Provide waterproofing and drainage arrangements to prevent seepage into the HT yard. 3. Compliance authority / Electrical Inspectorate to be informed.',
  'Borewell',
  '2026-03-31', false
),

-- ── Sr 13 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-013',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Earth Pits',
  'HT Yard – Earth Pits',
  'All earth pits are found filled with cement concrete, which restricts soil contact and reduces the effectiveness of earthing. Additionally, several earth strips and bolts are corroded and earth flats are exposed on the ground. This compromises the reliability of the earthing system.',
  'MEDIUM', 'OPEN',
  13, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 3043:2018 (Code of Practice for Earthing).',
  '1. Remove cement concrete from earth pits and restore natural soil contact with proper backfill material (charcoal, salt, or bentonite compound as per IS 3043). 2. Replace corroded earth strips and bolts with galvanized or copper-bonded components. 3. Apply anti-corrosion treatment and protective coatings to corroded fasteners. 4. Conduct earth resistance testing post-rectification. 5. Lay all exposed earth flats in trench/underground.',
  'Earth Pits',
  '2026-03-31', false
),

-- ── Sr 14 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-014',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Earth Pits',
  'HT Yard – Earth Pits',
  'Earth pits within the HT yard are not provided with identification tags or numbering. Several pits are found without proper protective covers. This hampers traceability, inspection, and maintenance of the earthing system.',
  'HIGH', 'OPEN',
  14, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 3043:2018 (Code of Practice for Earthing).',
  '1. Provide painted chamber identification and fix permanent identification tags/numbers on all earth pits for traceability. 2. Provide durable protective covers to prevent ingress of dust and debris.',
  'Earth Pits',
  '2026-03-31', false
),

-- ── Sr 15 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-015',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Earth Pits',
  'HT Yard – Earth Pits',
  'A power cable from the HT panel control system has been identified inside an earth pit chamber. This is an unsafe installation practice. Control cables must not pass through or be routed inside earth pits. This compromises system safety and increases the risk of accidental contact with earthing conductors.',
  'HIGH', 'OPEN',
  15, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 3043:2018 (Code of Practice for Earthing).',
  'Immediately reroute the HT panel control cable away from the earth pit chamber. Ensure control cables are laid in dedicated trenches, ducts, or conduits with proper mechanical protection. Maintain segregation between earthing systems and control/power cables as per BIS/CEA standards.',
  'Earth Pits',
  '2026-03-31', false
),

-- ── Sr 16 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-016',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Yard',
  'HT Yard – Fencing / Barricade Structure',
  'The HT yard barricade fencing/structure is not provided with an earthing connection. This is a mandatory safety requirement under the Indian Electricity (IE) Rules and CEA Safety Regulations. The absence of earthing poses a serious hazard, as metallic fencing can become energized during fault conditions, creating risk of electrocution.',
  'HIGH', 'OPEN',
  16, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 3043:2018 (Code of Practice for Earthing).',
  'Provide dedicated earthing connections to the HT yard barricade fencing/structure. Ensure earthing is carried out using galvanized/copper strips with proper bolted or welded connections. Verify earthing resistance values through earth resistance testing to confirm compliance.',
  'HT Yard Fencing / Barricade Structure',
  '2026-03-31', false
),

-- ── Sr 17 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-017',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Yard',
  'HT Yard',
  'Unwanted materials, used cables, and leftover project items are lying inside the HT yard. The presence of such materials obstructs safe access, reduces yard cleanliness, and poses hazards to day-to-day operation personnel.',
  'MEDIUM', 'OPEN',
  17, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  'Remove all unwanted materials, used cables, and leftover project items from the HT yard. Implement a regular housekeeping schedule to maintain yard cleanliness. Ensure dedicated storage areas are provided for spare materials outside the HT yard.',
  'HT Yard',
  '2026-03-31', false
),

-- ── Sr 18 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-018',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'HT Cables',
  'HT Yard – Power Cables',
  'Power cables and control cables connected to the transformer, breakers, and associated equipment are fixed without proper mechanical support or clamping. Several cables are found hanging without adequate support, posing risks of mechanical damage, strain on terminations, and unsafe working conditions.',
  'MEDIUM', 'OPEN',
  18, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 1255:1983 (Code of Practice for Installation and Maintenance of Power Cables) and CEA Safety Regulations (2010, amended 2024), which mandate secure clamping and mechanical protection of HT/MV cables.',
  '1. Provide approved clamps, trays, or supports for all power and control cables. 2. Ensure cables are routed through separate tray/MS frame with proper spacing and segregation. 3. Re-terminate cables where strain has compromised connections.',
  'Power Cables',
  '2026-03-31', false
),

-- ── Sr 19 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-019',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'DG Set',
  'HT Yard – 500 KVA DG Set',
  'The 500 KVA DG set power cable entry holes and spare openings are not properly sealed. This condition allows rodent entry into the DG set chamber, creating risks of insulation damage, short circuits, and equipment failure.',
  'HIGH', 'OPEN',
  19, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Seal all power cable entry holes and spare openings with approved cable glands, sealing compounds, or metallic covers. 2. Install rodent-proof barriers or mesh at vulnerable points to prevent entry.',
  'DG Set',
  '2026-03-31', false
),

-- ── Sr 20 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-020',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'DG Set',
  'HT Yard – 500 KVA DG Set',
  'Inside the 500 KVA DG chamber, traces of oil leakage, dust accumulation, and water ingress marks have been identified. Proper maintenance activities are not followed. Additionally, unwanted materials are stacked inside the DG exhaust chamber, compromising equipment safety and reliability.',
  'MEDIUM', 'OPEN',
  20, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Identify and rectify oil leakage sources; replace seals or gaskets where necessary. 2. Clean and remove dust deposits and water ingress residues; improve sealing and ventilation. 3. Remove all unwanted materials from the DG exhaust chamber to ensure unobstructed airflow. 4. Conduct preventive maintenance checks (Daily, Monthly, and Quarterly) and update site records.',
  'DG Set',
  '2026-03-31', false
),

-- ── Sr 21 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-021',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'DG Set',
  'HT Yard – DG Set Earth Pits',
  'Designated DG set earth pits for Neutral and Body earthing are not clearly identifiable. Identification tags or markings are missing, making it difficult to distinguish between Neutral earth pits and Body earth pits. This hampers traceability, inspection, and maintenance.',
  'HIGH', 'OPEN',
  21, 'Jyothikumar Kudumu', '2026-03-31',
  'Non-compliant with BIS IS 3043:2018 (Code of Practice for Earthing) and CEA Safety Regulations (2010, amended 2024), which mandate proper identification and segregation of Neutral and Body earth pits.',
  '1. Clearly mark and segregate Neutral earth pits and Body earth pits as per IS 3043 guidelines. 2. Fix permanent identification tags/numbers on all DG set earth pits.',
  'DG Set',
  '2026-03-31', false
),

-- ── Sr 22 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-022',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'DG Set',
  'HT Yard – DG Set Area',
  'Temporary arrangement cables with open joints have been identified routed from the HT yard wall without any protection or proper clamping. Loose cables with multiple joints are lying near the DG set, and traces of HSD oil are visible on the floor. This condition is unsafe and increases fire risk.',
  'HIGH', 'OPEN',
  22, 'Jyothikumar Kudumu', '2026-03-31',
  'BIS IS 1255:1983 and CEA Safety Regulations (2010, amended 2024), which mandate secure clamping, mechanical protection, and safe routing of HT/MV cables.',
  'Remove all temporary cable arrangements and replace with properly terminated, clamped, and protected cables. Eliminate open joints by using approved jointing kits and enclosures. Provide mechanical supports and clamps. Clean and remove HSD oil traces from the floor; ensure spill containment measures are in place.',
  'DG Set',
  '2026-03-31', false
),

-- ── Sr 23 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-023',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Water System',
  'HT Yard – CPVC Water Pipeline',
  'A CPVC water pipeline has been identified laid directly on the ground, alongside power cables, without following proper laying methods. No identification signage or markings are provided for the pipeline. This arrangement poses safety hazards including risk of accidental damage to the pipeline, and potential water splashing on HT panels and other equipment.',
  'HIGH', 'OPEN',
  23, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Relocate or properly route the CPVC water pipeline away from HT/MV power cables. 2. Provide identification signage/markings for the pipeline as per IS standards. 3. Follow standard laying methods, including supports, clamps, and protective covers. 4. Ensure segregation of utility pipelines from electrical installations.',
  'Water Pipe System',
  '2026-03-31', false
),

-- ── Sr 24 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-024',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Signage & Labelling',
  'HT Yard – All Equipment',
  'Identification tags or names are not placed on panels and breakers in the HT yard. Additionally, the size of input and output cables and routing identification marks are not provided for the equipment. This lack of labelling and cable identification hampers traceability, inspection, and maintenance.',
  'HIGH', 'OPEN',
  24, 'Jyothikumar Kudumu', '2026-03-31',
  NULL,
  '1. Fix permanent identification tags/nameplates on all HT yard panels, breakers, transformers, and DG sets. 2. Provide cable size markings and routing identification labels for input and output cables for all equipment.',
  'All Equipment',
  '2026-03-31', false
),

-- ── Sr 25 ─────────────────────────────────────────────────────────────────────
(
  'snag-ht-audit-2026-025',
  '00000000-0000-0000-0000-000000000001',
  'EXTERNAL_AUDIT', 'COMMON_AREA',
  'Electrical - HT Infrastructure', 'Fire Safety',
  'HT Yard – Fire Fighting Equipment',
  'A fire extinguisher is placed inside the HT yard without a proper monitoring mechanism. The extinguisher history card is not available. Sufficient-capacity fire extinguishers are not provided, and fire sand buckets are placed in the middle of the HT yard without easy access in case of a fire hazard.',
  'HIGH', 'OPEN',
  25, 'Jyothikumar Kudumu', '2026-03-31',
  'Fix permanent identification tags/numbers on all DG set earth pits.',
  '1. Provide adequate-capacity fire extinguishers suitable for electrical fires (CO₂, DCP type) at designated areas of HT yard and DG sets. 2. Ensure each extinguisher has a history card and is included in the monitoring/maintenance schedule. 3. Relocate fire sand buckets to accessible points at the entrance of HT yard and DG sets. 4. Establish a fire safety monitoring mechanism with periodic checks and documentation.',
  'Fire Fighting Equipment',
  '2026-03-31', false
)

ON CONFLICT (id) DO NOTHING;
