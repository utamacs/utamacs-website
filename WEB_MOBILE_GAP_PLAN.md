# UTAMACS — Web ↔ Mobile Feature Gap Plan

> Track mobile parity against the web portal. Check off each item as it is implemented and tested.
> Severity: 🔴 CRITICAL · 🟠 HIGH · 🟡 MEDIUM · 🟢 LOW

---

## Progress Summary

| Module | Total | Done | Remaining |
|--------|-------|------|-----------|
| 01 Notices | 9 | 5 | 4 |
| 02 Visitors | 14 | 0 | 14 |
| 03 Complaints | 13 | 13 | 0 |
| 04 Finance | 12 | 0 | 12 |
| 05 Events | 9 | 7 | 2 |
| 06 Polls | 9 | 7 | 2 |
| 07 Community Board | 11 | 7 | 4 |
| 08 Documents | 11 | 5 | 6 |
| 09 Gallery | 5 | 2 | 3 |
| 10 Facilities | 6 | 5 | 1 |
| 11 Parking | 12 | 6 | 6 |
| 12 Maids | 9 | 8 | 1 |
| 13 Members | 8 | 3 | 5 |
| 14 Notifications | 5 | 5 | 0 |
| 15 Feedback | 8 | 8 | 0 |
| 16 Water Tankers | 11 | 8 | 3 |
| 17 Snags | 11 | 5 | 6 |
| 18 HOTO | 8 | 2 | 6 |
| 19 Analytics | 8 | 1 | 7 |
| 20 Security Patrol | 6 | 3 | 3 |
| 21 Staff Management | 9 | 2 | 7 |
| 22 Policies | 4 | 2 | 2 |
| 23 Register / Membership | 6 | 2 | 4 |
| 24 AGM | 5 | 3 | 2 |
| 25 Tenant KYC | 5 | 4 | 1 |
| 26 Letters | 5 | 0 | 5 |
| 27 Vendors & Work Orders | 9 | 0 | 9 |
| 28 Profile & Auth | 6 | 3 | 3 |
| **TOTAL** | **234** | **119** | **115** |

---

## 01 · NOTICES

- [x] 🔴 Acknowledge notice — button + modal, writes `notice_acknowledgements` with timestamp
- [x] 🔴 Acknowledgement tracking panel (exec) — total / acknowledged / pending count per notice
- [x] 🟠 Scheduled notices tab — list scheduled notices with countdown + "Publish now" button
- [x] 🟠 Create notice form — title, category, audience (all/owners/tenants), target blocks/wings, body HTML, is_pinned, requires_acknowledgement, scheduled_at, draft mode
- [ ] 🟠 Attachment viewer — tap to open/download PDF or image via signed URL
- [ ] 🟠 Target audience & wing/block field on create form
- [x] 🟡 Video URL field + embedded player in notice detail
- [x] 🟢 Full category colour-coding (Urgent=red, Financial=amber, Governance=blue, Maintenance=orange, Events=purple, General=grey)

---

## 02 · VISITORS

- [ ] 🔴 Guard: OTP verification form (6-digit input → verify → admission modal with pass details)
- [ ] 🔴 Guard: QR camera scan (jsQR) → pass validity check → Admit button
- [ ] 🔴 Guard: Log walk-in entry form (visitor_name, visitor_type, host unit lookup, gate, vehicle)
- [ ] 🔴 Guard: Active visitors list with Log Exit per row
- [ ] 🔴 Resident: Gate approval requests — approve / reject with countdown timer
- [ ] 🔴 Guard: Submit gate-approval request to resident (awaits resident response)
- [ ] 🟠 Pass download button (html2canvas) and Share button (Web Share API / share_plus)
- [ ] 🟠 Guard: Expected Today tab — pre-approved passes valid today, filtered by recurring_days
- [ ] 🟠 Deliveries tab — log delivery form (courier, tracking#, flat), Mark Collected
- [ ] 🟠 Visitor logs table with filters (type, gate, date range) and CSV export
- [ ] 🟡 Frequent visitor shortcuts — pre-fill new pass from visit history
- [ ] 🟢 Guard note displayed on pass screen
- [ ] 🟢 Vehicle number displayed on pass screen
- [ ] 🟢 Recurring pass indicator on pass card

---

## 03 · COMPLAINTS

- [x] 🔴 Sub-category dropdown — dynamic, loaded per category from `GET /api/v1/complaints/sub-categories?category=X`
- [x] 🔴 Unit selection field (`unit_id`) in submit form
- [ ] 🔴 Photo / document attachment upload — 5 files, 5 MB each, JPEG/PNG/WebP/HEIC/PDF
- [x] 🟠 Category alignment — expand mobile from 6 to 14 categories matching web (Plumbing, Electrical, Lift, Security, Housekeeping, etc.)
- [x] 🟠 Comments thread — view thread, add comment, internal-note checkbox (exec-only comments hidden from member)
- [ ] 🟠 Attachments viewer in detail screen (tap to open signed URL)
- [x] 🟠 Status update + assignee sidebar (exec) — status dropdown + note + assign-to dropdown
- [x] 🟡 Star rating widget (1–5 stars) + feedback textarea on resolved complaints
- [x] 🟡 SLA deadline display and breach indicator (red if past deadline)
- [x] 🟡 Reopen complaint within SLA window
- [x] 🟢 Resolved date display in detail
- [x] 🟢 Reopen count display in detail
- [x] 🟢 Ticket number display

---

## 04 · FINANCE

- [ ] 🔴 Pay dues — Razorpay order creation (`GET /api/v1/finance/dues/{id}/order`) + payment form + webhook verification
- [ ] 🔴 GST invoice document — HSN 9972, GSTIN, line items, late penalty, GST %, TDS deducted, Net Amount Received
- [ ] 🟠 Invoice download / print (browser print or PDF share)
- [ ] 🟠 Payment receipts — view and download per payment
- [ ] 🟠 Billing period details (period open/close dates, per-category maintenance amounts)
- [ ] 🟠 TDS deduction tracking on vendor payments >₹30k + certificate generation
- [ ] 🟡 Aging / overdue dues report
- [ ] 🟡 Expense approval workflow (exec) — approve / reject pending expenses
- [ ] 🟡 Credit memo / refund processing
- [ ] 🟢 GST report (GSTR)
- [ ] 🟢 TDS report + Form 16A certificate
- [ ] 🟢 Ledger view and member statement

---

## 05 · EVENTS

- [x] 🔴 Capacity management — spots-left counter, capacity progress bar, auto-waitlist when full
- [ ] 🟠 Waitlist auto-promotion when a spot opens + push notification to next in queue
- [ ] 🟠 Banner image — display in list and detail; upload (exec)
- [x] 🟠 Attendee list — name, unit, guest count, check-in status (exec-only)
- [x] 🟠 Create event form — title, category (8 types), capacity, start/end datetime, location, description, registration_deadline, ticket_price
- [x] 🟡 Guest count selection (1–5 attendees) in RSVP modal
- [x] 🟡 Registration deadline enforcement (disable RSVP after deadline)
- [x] 🟡 Cancel RSVP button
- [x] 🟡 8 event categories rendered as filter/badge chips

---

## 06 · POLLS

- [x] 🔴 Rating poll type — 5-star input widget, `avg_rating` display, per-star distribution bar
- [x] 🟠 Create poll form — question, poll_type (single/multi/yes_no/rating), options builder (hidden for rating), anonymous toggle, one_vote_per_unit, max_choices (multi-choice), closing datetime
- [x] 🟡 Yes/No poll type UI variant
- [x] 🟡 Multi-choice limit enforcement (`max_choices` 2–20, disable submit if over limit)
- [x] 🟡 Close poll early button (exec) with confirmation dialog
- [ ] 🟡 PDF export of results (exec) — signed PDF with society letterhead
- [x] 🟡 Anonymous voting — display layer hides voter identity
- [x] 🟡 Result visibility modes fully enforced: `after_vote` / `after_close` / `executive_only`
- [ ] 🟢 AGM session linkage on poll create

---

## 07 · COMMUNITY BOARD

- [x] 🔴 Like / Helpful reactions — `like_count`, `helpful_count`, animated toggle buttons
- [x] 🔴 Comments — view thread per post, add comment form, delete own comment
- [ ] 🟠 Image uploads in create post — up to 5 images, JPEG/PNG/WebP/HEIC, signed URL via GitHub Docs
- [x] 🟡 Edit post modal (owner-only) — title + body
- [x] 🟡 Delete / soft-delete post (owner or exec)
- [x] 🟡 Pin / unpin post (exec) with pinned visual indicator
- [x] 🟡 Report post modal — reason (spam / offensive / misinformation / harassment / other) + optional details (max 300 chars)
- [ ] 🟡 Moderation queue — 3 reports hides post; exec can clear or remove
- [x] 🟡 Category filter chips (General / Help / Lost & Found / Recommendation / Alert)
- [ ] 🟡 Marketplace sub-section (buy / sell / giveaway listings)
- [ ] 🟢 Pagination / load-more (offset-based, limit=10)

---

## 08 · DOCUMENTS

- [ ] 🟠 View full document content — PDF in viewer, video player for video-type docs
- [ ] 🟠 Upload document modal (exec) — file, title, category, description, access level, is_public flag
- [x] 🟡 Search input with debounce (real-time filter against title/description)
- [ ] 🟡 Version history drawer — all versions with download links + change notes
- [ ] 🟡 Upload new version + change notes (auto-increments version number)
- [x] 🟡 10-category filter tabs (Bylaws, Minutes, Financial, Legal, Circulars, Governance, HOTO, Maintenance, Forms, Other)
- [x] 🟡 Access control badge (`requires_role` member/executive, `is_public` indicator)
- [x] 🟢 MIME type icons (PDF=red, Word=blue, Excel=green, CSV, Image)
- [x] 🟢 File size and upload date displayed on card
- [ ] 🟢 Archive document (exec)
- [ ] 🟢 Download audit log entry (exec downloads logged in `audit_logs`)

---

## 09 · GALLERY

- [x] 🟠 Create album modal (exec) — title, description, event_date
- [ ] 🟠 Upload photos to album — multi-file picker (exec), progress indicator
- [ ] 🟡 Album cover image displayed in grid (currently placeholder colour only)
- [x] 🟡 Album description and event_date shown in detail view
- [ ] 🟢 Photo captions in lightbox view

---

## 10 · FACILITIES BOOKING

- [x] 🟠 Cancel booking — for pending / confirmed / waitlisted bookings, with optional reason input
- [x] 🟡 Booking fee and deposit amount displayed before and on booking confirmation
- [x] 🟡 Client-side advance booking validation (enforce `advance_booking_days` minimum)
- [x] 🟢 Advance booking window indicator ("Up to X days in advance")
- [ ] 🟢 No-show suspension warning (3 no-shows = account flagged)
- [x] 🟢 Deposit refund / credit details on cancellation

---

## 11 · PARKING

- [x] 🔴 Slot grid — colour-coded availability for all slots (slot_number, type, level, monthly_charge, occupied/free status)
- [x] 🔴 Waitlist — join waitlist, view position in queue, withdraw
- [x] 🔴 Transfer request — member requests slot transfer to another unit with reason
- [ ] 🟠 Slot type / vehicle type filter dropdowns
- [ ] 🟠 Insurance document upload + expiry date tracking
- [ ] 🟠 RC document upload at allocation
- [x] 🟡 Vehicle details — make, model, colour on allocation card
- [x] 🟡 Monthly charge (`₹X/month`) displayed on allocation card
- [x] 🟡 Allocation expiry date (`expires_at`) displayed
- [ ] 🟢 Allocation history (past allocations list)
- [ ] 🟢 Allocate / release slot (exec)
- [ ] 🟢 Add new slot (exec)

---

## 12 · MAIDS / DOMESTIC HELP

- [x] 🔴 Log attendance modal — date, entry_time, exit_time, notes; saves to `maid_attendance`
- [x] 🔴 Monthly summary tab — days_present / total_working_days, attendance %, progress bar per helper
- [x] 🔴 Register helper form (exec) — full_name, phone, work_type (8 options), agency, id_type (6 options), id_number, police_verified + verification_date
- [x] 🟠 Find & Approve tab — browse all registered helpers, approve for own unit
- [x] 🟠 Attendance tab with date picker and attendance table
- [x] 🟡 KYC expiry / renewal warnings (`kyc_expires_at`)
- [x] 🟢 Agency name displayed on helper card
- [x] 🟢 Toggle helper active / inactive (exec)
- [ ] 🟢 Photo display for registered helpers

---

## 13 · MEMBERS DIRECTORY

- [x] 🔴 Edit own profile — bio, preferred_language, WhatsApp number, emergency contact (name / phone / relation)
- [ ] 🔴 Avatar upload — JPEG/PNG/WebP with progress indicator; stored via GitHub Docs
- [x] 🟠 Occupancy filter — owner_occupied / tenant_occupied / vacant / under_renovation
- [x] 🟡 Role badge on member card (member / executive / secretary / president)
- [x] 🟡 Move-in date ("Member since MMM YYYY") on profile
- [ ] 🟡 Vehicle details section (reg_no, make, model) in own profile
- [ ] 🟢 Tenancy expiry filter ("Expiring in 30 days")
- [ ] 🟢 CSV export (exec)

---

## 14 · NOTIFICATIONS

- [x] 🔴 Notification preferences screen — 12 category toggles + 5 channel toggles (email, email_digest, SMS, push, WhatsApp)
- [x] 🟠 Quiet hours configuration (from/to time picker)
- [x] 🟠 Delete individual notification (swipe-to-delete or trash icon)
- [x] 🟡 Type filter chips (11 types: complaint / notice / event / poll / payment / community / visitor / facility / amc / feedback / system)
- [x] 🟡 Notification type icons — expand mobile switch from 5 to all 11 types

---

## 15 · FEEDBACK

- [x] 🔴 Management response view — show `response` text + `responded_at` in detail panel
- [x] 🔴 Full detail drawer — subject, body, star rating, status, priority, management response section
- [x] 🟠 Category alignment — replace mobile categories with web set: general / maintenance / safety / amenities / management / events / other
- [x] 🟠 Status filter dropdown (7 statuses: open / acknowledged / in_progress / resolved / closed)
- [x] 🟠 Priority field on submit form (low / normal / high / urgent)
- [x] 🟡 Priority badge on feedback list card
- [x] 🟡 Body preview (2-line truncate) in list card
- [x] 🟡 Unit display in exec list view

---

## 16 · WATER TANKERS

- [x] 🔴 Log delivery modal (exec) — delivery_date, supplier, capacity_kl, tanker_count, cost_per_kl, total_cost (auto-calc), payment_mode, invoice#, notes
- [x] 🔴 Cost alert banner — threshold warnings from `/api/v1/water-tankers/cost-alert`
- [ ] 🟠 12-month trend chart — bar chart with KL delivered + cost per month
- [x] 🟠 Month picker filter (input type=month to select viewing period)
- [x] 🟡 Payment mode badge (Cash / UPI / Bank Transfer / Credit)
- [x] 🟡 Invoice number displayed on delivery card
- [x] 🟡 Notes field displayed on delivery card
- [x] 🟡 Cost-per-KL displayed
- [x] 🟢 Year-to-date KL stat card
- [ ] 🟢 CSV export (exec)
- [x] 🟢 Total monthly spend stat card

---

## 17 · SNAGS

- [x] 🔴 Status transition buttons — OPEN → IN_PROGRESS → RESOLVED → VERIFIED_CLOSED; VERIFIED_CLOSED → REOPENED (with mandatory reason)
- [x] 🔴 Edit snag after creation — category, subcategory, location, description, severity, builder_ref, builder_committed_date
- [x] 🔴 Reopen workflow — VERIFIED_CLOSED → REOPENED with mandatory reason text
- [ ] 🟠 Photo management — upload (multi-file), lightbox view, delete, before/after comparison
- [ ] 🟠 Document uploads — PDF/DOC/CSV up to 50 MB with description
- [x] 🟠 Comments thread — view + add comments on snag
- [ ] 🟡 Create vendor work order from snag (linked WO with deadline + quoted amount)
- [ ] 🟡 Assignee field — assign to committee member (exec/secretary/president)
- [ ] 🟡 HOTO item linkage — view linked HOTO item; HOTO blocked until snag verified
- [ ] 🟡 CSV export with filters (status, severity, scope, category)
- [ ] 🟢 Builder reference fields (`builder_ref`, `builder_committed_date`)

---

## 18 · HOTO

- [x] 🔴 HOTO item detail screen — full status workflow: NOT_STARTED → IN_PROGRESS → UNDER_REVIEW → PENDING_SECRETARY / PENDING_PRESIDENT → APPROVED / REJECTED → CLOSED
- [ ] 🔴 Snag ↔ HOTO bidirectional linking (attach snag to HOTO item; block HOTO review if snag open)
- [x] 🟠 Status transition buttons (advance / submit for review / approve / reject)
- [ ] 🟠 Delegation management — assign authority to committee member
- [ ] 🟠 Elections workflow screen
- [ ] 🟠 Finance tab — resolutions, budget approvals, funding decisions
- [ ] 🟡 Comments on HOTO items
- [ ] 🟡 User invitations to HOTO process

---

## 19 · ANALYTICS

- [x] 🔴 Overview KPI cards — total members, units, dues collection %, complaints, visitors
- [ ] 🔴 Charts — bar (complaints by status, visitor types), line (14-day visitor trend, 6-month P&L, collection efficiency), pie (member composition, expense breakdown)
- [ ] 🟠 Filtered data CSV export
- [ ] 🟠 Executive PDF report (`/api/v1/reports/executive-pdf`)
- [ ] 🟡 Wing / block / billing-period filters
- [ ] 🟡 Real-time KPI refresh
- [ ] 🟡 All 11 report types — Collection, Pending Dues, Complaint Resolution, Facility Utilisation, Visitor Log, Tenant Expiry, Member Directory, Trends, Expense Breakdown, Occupancy
- [ ] 🟢 Occupancy heatmap by unit status

---

## 20 · SECURITY PATROL

- [x] 🔴 Log patrol form — patrol_date, shift, guard_name, remarks, incident flag, incident_type, severity, location, description
- [x] 🟠 Incident management — view open incidents list (exec)
- [x] 🟠 Guard attendance dashboard — days worked / absent / late over 7 / 30 / 60 / 90-day windows
- [ ] 🟡 Shift schedule — view and create shifts (exec)
- [ ] 🟡 CSV export of patrol logs (exec)
- [ ] 🟢 Open incident count badge on tab

---

## 21 · STAFF MANAGEMENT

- [x] 🔴 Staff directory screen — department-grouped list with role, status, contact, designation
- [x] 🔴 KYC onboarding — photo upload, ID type/number, annual renewal tracking
- [ ] 🟠 Task creation and assignment — title, description, assigned_to, department, deadline, priority (HIGH/MEDIUM/LOW)
- [ ] 🟠 Attendance marking and log view
- [ ] 🟠 Shift scheduling — view and create shifts per department
- [ ] 🟡 Hiring / exit proposals workflow (committee approval)
- [ ] 🟡 Staff analytics — attendance %, compliance status, activity logs
- [ ] 🟡 Agency management — PSARA / PF / ESIC expiry tracking
- [ ] 🟢 Department configuration

---

## 22 · POLICIES

- [x] 🟠 Policy detail / full-content view — render HTML body, embed PDF iframe, YouTube/video player
- [ ] 🟡 PDF upload / replace (exec) — max 20 MB via GitHub Docs
- [ ] 🟡 Policy edit form (title, description, effective_date, version, gate_portal_access toggle)
- [x] 🟡 `gate_portal_access` indicator clearly surfaced on policy card ("Blocks portal access until acknowledged")

---

## 23 · REGISTER / MEMBERSHIP

- [x] 🔴 Public self-registration form — Step 1 (name / email / phone / occupancy_type), Step 2 (flat / move-in date / ID type+number / vehicle), Step 3 (DPDPA consent review + submit)
- [ ] 🟡 Sale deed upload — PDF/JPG/PNG, max 10 MB (for membership application)
- [x] 🟡 Member type alignment — add: original_owner / purchaser / successor / heir / joint_owner_nominee (currently only resident_owner / investor_owner)
- [ ] 🟡 Membership status timeline — Application Submitted → Fee Confirmed → Approved → Share Cert Issued
- [ ] 🟡 Joint owners names field
- [ ] 🟢 Fee payment notice (₹1,000 admission + ₹1,000 share capital with direct-pay instructions)

---

## 24 · AGM

- [x] 🔴 AGM detail screen — resolutions list with votes_for / votes_against / votes_abstain / passed_at
- [ ] 🟡 AGM document view and download (type badge, status, public indicator, file download)
- [x] 🟡 Create AGM session modal — year, type (annual/extraordinary), meeting_date, venue, notes
- [x] 🟡 Quorum tracking — update attendees_count, progress bar vs quorum_threshold
- [ ] 🟡 Document workflow display — draft → submitted → secondary-approved → approved/rejected with `is_public` flag

---

## 25 · TENANT KYC

- [x] 🔴 Add tenant KYC form (exec/owner) — unit, full_name, tenancy_start/end, aadhaar_last4, monthly_rent, PAN, notes
- [x] 🟠 Police verification form — police_station, verification_date, reference#, "Mark Police Verified" button
- [x] 🟡 Owner consent toggle + date stamp
- [x] 🟡 Status transition buttons — Pending → Submitted → Police Verified → Completed
- [ ] 🟡 As-Tenant tab — full implementation (tenant views own KYC record)

---

## 26 · LETTERS

- [ ] 🔴 PDF generation and download (exec) — society letterhead, sequential reference#, secretary sign-off
- [ ] 🟠 Template system — select template, fill variables (resident name / unit / date / amount), auto render, reference# auto-generation
- [ ] 🟡 Secretary sign-off step before PDF issue
- [ ] 🟡 Letter detail / full-content view on mobile
- [ ] 🟡 Cross-module linking — AGM notice → AGM session, demand notice → Finance due, RERA notice → Snag/HOTO item

---

## 27 · VENDORS & WORK ORDERS

- [ ] 🔴 Create work order form — vendor (select), linked complaint/snag (optional), description, quoted_amount, schedule_date, TDS applicable checkbox
- [ ] 🔴 Invoice upload on work order + mark complete flow
- [ ] 🔴 Procurement module — create requirement, vendor candidates, committee vote, select winner
- [ ] 🟠 Vendor contact details, GST#, PAN#, bank account in detail view
- [ ] 🟠 WO status workflow buttons — Mark In Progress → Inspect → Complete → Close / Dispute
- [ ] 🟡 Licence expiry warnings for agency vendors (PSARA / PF / ESIC)
- [ ] 🟡 TDS management — flag >₹30k WOs, link TDS certificate to Finance module
- [ ] 🟡 Complaint / snag auto-link on WO creation and auto-resolve on WO close
- [ ] 🟡 Vendor rating after WO completion (1–5 stars + review)

---

## 28 · PROFILE & AUTH

- [x] 🟠 Edit own profile — bio, preferred_language (en/te/hi), WhatsApp number, emergency contact (name / phone / relation)
- [ ] 🟠 Avatar upload — JPEG/PNG/WebP with upload progress; stored via GitHub Docs `avatar(profileId, ext)` path
- [ ] 🟡 Unit details view — building, floor, area_sqft, residency_type, move_in_date, num_occupants
- [ ] 🟡 Password reset flow — forgot-password email → reset-password token screen
- [ ] 🟢 NRI flag and occupant count display
- [ ] 🟢 Consent version and date display (DPDPA)

---

## Notes

- **File uploads on mobile** go through the Supabase client directly (not the GitHub Docs API used by web portal). The signed URL model is equivalent — store the path, generate fresh URL on retrieval.
- **Exec-only features** marked above should be gated using `profile.isExec` (check `portal_role` ∈ {executive, secretary, president} or `is_admin`).
- **Payment integration** requires `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` in the mobile `.env`; use the `razorpay_flutter` package.
- **Charts** use `fl_chart` (already a common Flutter package); no new dependency needed for most visualisations.
- When marking an item complete, update the **Progress Summary** table at the top.
