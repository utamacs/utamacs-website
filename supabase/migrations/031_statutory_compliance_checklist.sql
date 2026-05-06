-- Migration 031: Additional statutory compliance HOTO items from Residential Buildings
-- Compliance Checklist (cross-referenced against migration 030 to avoid redundancy)
--
-- Already covered in 030 (NOT re-added):
--   hoto-stat-001: Sanctioned Building Plan / Structural Drawings (GHMC)
--   hoto-stat-002: Fire NOC, Environmental Clearance (TSPCB), Lift NOC
--   hoto-stat-003: Title Deed, Encumbrance Certificate, Pattadar Passbook
--   hoto-stat-004: RERA, Completion Certificate, Occupancy Certificate
--   hoto-stat-005: Water & Sewerage Connection (HMWSSB)
--   hoto-ht-002:   TSSPDCL HT connection agreement + sanctioned load (CMD)
--
-- New items added below (7):
--   Zoning Clearance & Land Use Certificate
--   Parking Layout & Circulation Plan (GHMC)
--   Airport Authority of India (AAI) Clearance
--   Chief Electrical Inspectorate of GoT — Electrical Installation Approval
--   Soil Test Report & Foundation Design Approval
--   Structural Safety Certificate (Licensed Engineer)
--   Compliance Undertakings — NBC Affidavit & Setbacks

INSERT INTO hoto_items (id, society_id, ascenza_category, title, description, priority, status, responsible_role, rera_escalation_eligible, notice_sent) VALUES

('hoto-stat-007',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Zoning Clearance and Land Use Certificate (HMDA/GHMC)',
 'Obtain Zoning Clearance confirming the plot falls within permissible residential zone under the Master Plan, and the Land Use Certificate from HMDA/GHMC confirming approved land use. Verify no zoning violations.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-008',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'GHMC Approved Parking Layout & Circulation Plan',
 'Collect GHMC-approved parking layout drawing showing basement/stilt/open car parking, circulation aisles, ramps, and pedestrian paths. Verify actual parking count matches approved plan and RERA commitment.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-009',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Airport Authority of India (AAI) Height Clearance',
 'Verify whether building height triggers AAI clearance requirement (typically buildings near Hyderabad airport funnel zone). If applicable, obtain AAI No Objection Certificate and confirm aviation warning lights are installed per clearance conditions.',
 'MEDIUM', 'NOT_STARTED', 'president', false, false),

('hoto-stat-010',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Chief Electrical Inspectorate (GoT) — Electrical Installation Approval',
 'Obtain approval from the Chief Electrical Inspectorate of Government of Telangana for the HT electrical installation, internal wiring scheme, and single-line diagram. This is a mandatory approval separate from TSSPDCL connection — required for HT consumers above 100 KVA.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-011',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Soil Test Report and Foundation Design Approval',
 'Collect soil investigation (geotechnical) report, pile/raft foundation design, and Licensed Engineer certification of the foundation design. Verify report covers all tower locations and soil bearing capacity matches design assumptions.',
 'MEDIUM', 'NOT_STARTED', 'secretary', false, false),

('hoto-stat-012',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Structural Safety Certificate (Licensed Engineer)',
 'Obtain Structural Safety Certificate from the Licensed Structural Engineer certifying that the building has been constructed in accordance with the approved structural drawings and meets NBC/IS code requirements.',
 'HIGH', 'NOT_STARTED', 'president', true, false),

('hoto-stat-013',
 '00000000-0000-0000-0000-000000000001',
 'Statutory Compliance',
 'Compliance Undertakings — NBC Adherence, Setbacks, Height & Parking Norms',
 'Collect builder-submitted compliance undertakings: (a) affidavit on adherence to NBC and Telangana Building Rules, (b) undertaking confirming setbacks, building height, and parking norms as per sanctioned plan. File in society governance records.',
 'MEDIUM', 'NOT_STARTED', 'secretary', false, false);
