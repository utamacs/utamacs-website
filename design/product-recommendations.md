# UTAMACS Portal — Product Improvement Recommendations

> **Context**: Senior product owner research covering all 22 existing portal modules + Indian apartment market benchmarking.
> Market peers studied: NoBrokerHood, MyGate, ApnaComplex, Adda.
> Regulatory context: Telangana MACS Act 1995, TSRERA, DPDPA 2023, GST AAR on RWA maintenance, TDS §194C/194J, GHMC regulations.
>
> Priority tiers: **P1** = critical gap / compliance risk / broken UX | **P2** = significant improvement | **P3** = polish / future

---

## Already Implemented (this session)

| Item | Module |
|------|--------|
| Replace `alert()` with toast notifications | Polls |
| Vote result bars with % after casting | Polls |
| Exec "Close Poll" button (manual close) | Polls |
| `GET /api/v1/polls/:id/results` endpoint | Polls |
| `POST /api/v1/polls/:id/close` endpoint | Polls |
| Scheduled notices auto-publish via cron | Notices |
| In-app notifications on event create | Events |
| In-app notifications on poll create | Polls |
| In-app notifications on community post create | Community |
| `fanoutNotification()` utility + pref opt-out | Notifications |
| Religious + Maintenance category icons | Events |
| `comment_count` on community posts feed | Community |
| `community` type in notifications icon/link map | Notifications |

---

## 1. Notices & Announcements

### P1
- **Acknowledgement tracking dashboard**: `requires_acknowledgement = true` notices have no exec view of who has/hasn't acknowledged. Add a read-receipt list per notice showing unit-wise status.
- **Expiry auto-archive**: Notices past `expires_at` are still returned by the GET — filter them out or mark `status = 'archived'` via cron. Currently expired notices appear live.
- **Notice attachment signed URL**: Attachment stored in Supabase but the portal has no "View Attachment" button on the notices feed. Wire signed URL generation.
- **Announcement push (WhatsApp / SMS)**: Urgent notices need an out-of-band channel. Integrate Gupshup or Twilio WhatsApp Business API. Exec can tick "Send WhatsApp" at publish time.
- **Notice delivery receipt**: Track per-user `is_read` at open time (not just acknowledgement). Useful for audit trail under DPDPA Article 9.

### P2
- **Scheduled notices UI**: The `new.astro` form lets execs pick a scheduled time, but there is no "Scheduled" tab on the index page — execs can't see what's pending publication.
- **Notice categories as coloured pills on feed**: All categories currently render the same. Apply colour coding: Urgent = red, Financial = amber, General = blue, Maintenance = orange, Events = purple, Governance = teal.
- **Target audience filter (unit-type based)**: `target_audience` column exists but the API doesn't filter by it. A notice targeted at "Flat owners only" reaches renters too.
- **Bulk resend**: Allow exec to resend a notice notification to members who haven't acknowledged.
- **Notice search**: Full-text search on title + body for members to find old announcements.

### P3
- **Notice templates**: Common notice types (AGM reminder, water cut, maintenance shutdown) should have pre-filled templates.
- **Multilingual notices**: Telugu translation field alongside English body. Render toggle on feed.

---

## 2. Polls & Voting

### P1
- **`result_visibility` respected in UI**: The DB column exists (`always` / `after_close` / `after_vote`) but the UI always shows results after voting. Enforce `after_close` — show a "Results will be visible after the poll closes" placeholder until then.
- **Multiple-choice poll type**: `poll_type = 'multiple_choice'` is a valid enum value but the vote API only stores one `option_id`. Need multi-select UI + array vote storage.
- **Rating poll type**: `poll_type = 'rating'` needs a 1–5 star or 1–10 slider UI.
- **Yes/No poll type**: Special two-button layout, larger tap targets.
- **One-vote-per-unit enforcement**: `one_vote_per_unit` column exists but the vote API checks only by `user_id`. If two residents from the same unit vote, both go through.
- **Poll notification to voters when results published**: After close, send a notification linking to results.

### P2
- **Poll detail page** `/portal/polls/[id]`: Direct link from notification should land on the specific poll, not the index.
- **Poll comment thread**: Allow members to leave a comment alongside their vote (optional, configurable at creation).
- **CSV export of votes**: In addition to PDF, allow exec to download a CSV with (if not anonymous) voter name + unit + option chosen.
- **Poll archiving**: Old closed polls clutter the feed. Add an "Archived" tab or auto-hide polls closed > 30 days.
- **Scheduled poll start**: Similar to notices, allow a poll to open at a future `starts_at` rather than immediately on create.
- **Link poll to AGM**: Associate a poll with an AGM record so minutes auto-include the result.

### P3
- **Anonymous voting audit trail**: Even when `is_anonymous = true`, allow the society's auditor role to verify unique-voter count without seeing who voted for what.
- **Poll duplication**: Copy an existing poll as a new draft.

---

## 3. Finance & Dues

### P1
- **Member ledger / running balance**: Each resident needs a statement showing all dues, payments, and adjustments in chronological order with a running balance. Currently there's no way for a member to see their balance at a glance.
- **Payment gateway integration (Razorpay / Cashfree)**: Online payment of maintenance dues is the single highest-value missing feature. Integrate Razorpay standard checkout. Store `razorpay_order_id` + `razorpay_payment_id` on payments. Webhook to confirm payment. RBI mandate: use only Indian payment aggregators.
- **Fund accounting — Sinking / Maintenance / Repair**: Telangana MACS Act requires separate accounting for Sinking Fund. Currently all expenses go into one bucket. Add `fund_type` column on expenses (`maintenance_fund`, `sinking_fund`, `repair_corpus`, `utility_pool`).
- **GST compliance for maintenance > ₹7,500/month**: RWA maintenance above ₹7,500/month/unit attracts 18% GST. The dues module must calculate and record GST on applicable units. Issuance of a GST invoice (already has pdfmake) is mandatory.
- **TDS on vendor payments (§194C / §194J)**: Already partially built (admin TDS page). Ensure every expense > ₹30,000 single / ₹1L annual triggers a TDS deduction row. Generate Form 16A from portal.
- **Overdue interest calculation**: Auto-calculate interest on overdue dues (typically 12–18% p.a. as per by-laws). Cron adds interest rows monthly.
- **Expense approval workflow**: Currently expenses insert directly. Add a two-step flow: treasurer drafts → president/secretary approves. No payment without approval.

### P2
- **Advance maintenance receipts**: Members who pay 12 months upfront get a single receipt valid for the year. Generate combined receipt PDF.
- **Partial payment handling**: A member who pays ₹3,000 against ₹5,000 due should have a `partially_paid` record, not be marked overdue.
- **Bank reconciliation view**: Upload a CSV bank statement; reconcile against payment records to identify unmatched credits.
- **Income tax receipt for flat owners**: Under IT Act §80C, RWA contributions are not deductible, but many owners ask for a receipt for Form 26AS reconciliation.
- **Budget vs. actual tracking**: Allow exec to create an annual budget per category and track actuals against it.
- **WhatsApp payment reminder**: Before the dues cron sends an in-app notif, also send a WhatsApp message with a direct payment link.

### P3
- **CA/Auditor read-only login**: A special role for chartered accountant access to finance data without any write ability.
- **Annual financial report PDF**: Auto-generate the Receipts & Payments statement in the format required for MACS society annual returns.

---

## 4. Community Board

### P1
- **Post images**: `community-images` Supabase bucket exists, and `/api/v1/community/posts/[id]/images.ts` exists, but the post creation form has no image upload UI. Wire it.
- **Moderation admin page**: Reports pile up in `community_reports` with no exec UI to review and act (remove post, warn user, dismiss report). Build `/portal/admin/moderation.astro`.
- **Edit own post**: Members can create but not edit. Add PATCH `/api/v1/community/posts/[id]` and an edit button visible to the post author.
- **Delete own post**: Author should be able to delete their own post (soft-delete `is_published = false`).
- **Pinned posts visible first**: API orders by `is_pinned DESC` but exec has no way to pin a post from the UI. Add a pin/unpin button (exec only).

### P2
- **Rich text editor**: Replace the plain textarea in `new.astro` with a simple markdown or WYSIWYG editor (Trix, Quill lite, or just a toolbar over a textarea).
- **Comment notifications**: When someone comments on your post, you receive a notification.
- **Mention (@unit number)**: Notify a specific resident via `@B-204` syntax in a post or comment.
- **Category icons on feed**: Visual icons per category (Alert = 🔴, Help = 🟡, Recommendation = 🟢, Lost_Found = 🔵).
- **Post bookmarking**: Members can save posts to a personal reading list.
- **Community poll integration**: A "quick poll" widget embeddable inside a community post.

### P3
- **Trending posts**: Surface posts with most reactions in the last 48 hours at the top.
- **Auto-expire Alert posts**: Category `Alert` posts older than 7 days auto-unpublish (configurable).

---

## 5. Events & RSVP

### P1
- **QR check-in**: At event entry, a volunteer scans member's QR code (from profile) to mark attendance. Attendance vs. RSVP delta tracked.
- **Waitlist auto-promotion**: When a registered member cancels, the first person on the waitlist should be automatically promoted and notified.
- **Paid events / ticket collection**: `is_paid` and `ticket_price` columns exist but there is no payment flow. Wire Razorpay for ticket purchase. Generate a PDF ticket.
- **Event reminder notifications**: 24 hours and 1 hour before `starts_at`, push a reminder to all registered members.
- **Post-event feedback**: After `ends_at` passes, auto-send a feedback form link to attendees.

### P2
- **Recurring events**: Monthly committee meetings, weekly yoga, etc. Add a `recurrence_rule` (RRULE) so one create generates multiple events.
- **Event banner image upload**: `event-banners` bucket exists but `new.astro` has no image upload. Wire it.
- **Event capacity warnings**: When 80% full, notify the event creator and show "Only X spots left" on the card.
- **iCal / Google Calendar export**: "Add to Calendar" button that generates an `.ics` file.
- **Event categories expanded**: Add Festive, Committee Meeting, Emergency Meeting, Workshop.
- **Guest pass**: RSVP for N attendees (not just 1). Control the per-unit guest limit.

### P3
- **Event photo gallery**: After an event, exec uploads photos which appear in a linked gallery.
- **Volunteer sign-up**: Members can volunteer for event roles (setup, registration desk, cleanup).

---

## 6. Complaints

### P1
- **SLA enforcement**: Complaints have no SLA timer. After 48 hours unacknowledged (configurable), auto-escalate to the next committee member.
- **Complaint attachment**: `complaint-attachments` bucket is provisioned but the complaint form has no file upload. Wire it.
- **Status change notifications**: When exec changes status (open → in_progress → resolved), notify the complainant automatically.
- **Public complaint counter**: Show open complaint count by category on the executive dashboard for accountability.

### P2
- **Resolution notes field**: When marking resolved, exec must enter a resolution description. Currently resolution is silent.
- **Complaint categories**: Add structured categories (Water, Electrical, Lift, Security, Neighbour, Common Area, Sanitation) with sub-types.
- **Duplicate detection**: If two complaints describe the same location/category in 24 hours, prompt "a similar complaint already exists — merge?"
- **Resident satisfaction rating**: After resolution, ask the complainant to rate the resolution (1–5). Track committee performance.
- **Complaint history per unit**: On the member directory, show open complaint count per unit. Useful for tracking repeat issues.

### P3
- **WhatsApp complaint submission**: Member sends a WhatsApp message to the society number, a bot creates a complaint automatically.
- **Complaint heat map**: Visual grid of building/block showing complaint density by area.

---

## 7. Facilities Booking

### P1
- **Booking rules enforcement**: The `facility_rules` or `booking_rules` table (if it exists) is not enforced — members can book multiple consecutive slots or book on disallowed days. Add rule engine validation.
- **Cancellation refund logic**: If a member cancels a paid facility booking, the deposit refund process is manual. Automate the credit note.
- **Double-booking prevention**: Parallel POST requests for the same slot can create overlapping bookings if there's no DB-level uniqueness constraint.
- **Upcoming bookings on dashboard**: Member dashboard should show "Your next booking: Badminton Court, Tomorrow 6–7 PM".

### P2
- **Facility photos**: `facility-photos` bucket exists but no image is displayed on the facility listing.
- **Booking lead time rules**: e.g., "Clubhouse must be booked minimum 48 hours in advance", "Maximum 2 bookings per unit per month".
- **Maintenance blackouts**: Exec marks a facility unavailable for a date range (painting, repair) and bookings are blocked.
- **Guest booking**: Allow booking a facility for a non-resident guest (name + phone logged).
- **Automated facility check-out reminder**: 15 minutes before booking end, WhatsApp the booker "Please wrap up and restore the facility."

### P3
- **Facility utilisation analytics**: Which facilities are most booked, peak hours, average occupancy. Helps the committee justify new equipment.
- **Booking waitlist**: If a slot fills, interested members join a waitlist and are auto-notified on cancellation.

---

## 8. Visitor Management

### P1
- **Guard mobile app / PWA**: Security guards currently have a desktop portal. A lightweight mobile-first PWA is essential for gate usage. Current `/portal/visitors` is desktop-only.
- **Pre-approval notification to guard**: When a resident pre-approves a visitor, the guard should receive an in-app notification at entry time.
- **Visitor photo capture**: Allow guards to photograph the visitor/vehicle at entry (Supabase Storage).
- **Frequent visitor quick-add**: For domestic help, drivers, and regular delivery agents, a "known visitor" list per unit for one-tap check-in.

### P2
- **Visitor OTP verification**: On entry, guard triggers an OTP to the resident's phone. Resident approves via OTP. Eliminates phone tag.
- **Delivery package log**: Separate flow for package delivery (courier name, AWB, photo). Resident notified with "Package collected at gate."
- **Vehicle number plate log**: For vehicle entries, record number plate. Integrate with parivahan.gov.in API for verification (optional).
- **Contractor entry log**: Track contractor/vendor visits linked to open work orders.
- **Blacklist**: Exec can flag a person/vehicle as denied entry. Guard sees alert on check-in attempt.

### P3
- **ANPR integration**: Automatic Number Plate Recognition for frequent vehicles (residents).
- **Daily visitor report to committee**: Cron sends a daily summary of visitor count, peak entry times to the exec.

---

## 9. HOTO Tracker

### P1
- **RERA compliance packet**: Generate a single PDF "RERA Evidence Package" per unit containing all HOTO items, builder responses, and photo evidence. Required for TSRERA disputes.
- **Builder response tracking**: Currently there's a status field but no formal mechanism for the builder to upload a response or counter-response. Add a builder-response document upload.
- **HOTO item photos**: `complaint-attachments` or a dedicated bucket for HOTO photos is referenced but the HOTO item form has no photo upload UI.
- **Legal notice drafter**: When an item is overdue by 30 days, generate a draft legal notice (Word/PDF) addressed to the builder using project/builder details from system config.

### P2
- **Unit-wise HOTO dashboard**: Each flat owner can log in and see only their unit's HOTO items. Currently the full HOTO list is exec-only.
- **Builder SLA vs. actual resolution chart**: Visual bar chart of committed vs. actual resolution dates by category (Civil, Electrical, Plumbing, Façade).
- **Cost recovery tracking**: Some HOTO resolutions cost the society money first. Track cost incurred and amount recovered from builder.
- **HOTO bulk upload**: Allow uploading a CSV of HOTO items from the handover inspection report.
- **Integration with Snags**: Close a HOTO item automatically when the linked snag is resolved.

### P3
- **Telegram bot alerts**: Builder-facing Telegram bot where builder team can update status directly.

---

## 10. AGM & Governance

### P1
- **Minutes PDF auto-generation**: AGM minutes can be generated from the portal form but the output needs to be compliant with the MACS Act format (resolution numbering, quorum statement, attendance roll).
- **Quorum calculator**: Auto-check if quorum is met (e.g., 2/3 of members present) based on RSVP/attendance data linked from Events.
- **Proxy voting**: Under MACS rules, members unable to attend can assign proxy. Add proxy registration and recording.
- **AGM notice period**: Statutory 14-day notice required. The portal should warn if the AGM event is created less than 14 days out.

### P2
- **Resolution tracking**: Each resolution passed at an AGM should be trackable (open / implemented / superseded). Link resolutions to action items.
- **Special resolution workflow**: Resolutions requiring 75% majority (MACS Act) need a special flag and quorum validation different from ordinary resolutions.
- **Agenda builder**: Drag-and-drop agenda items before the meeting; auto-include pending resolutions from the poll module.
- **Committee election module**: Coordinate elections for executive committee positions — nomination, voting, result declaration.

### P3
- **Society registration documents vault**: Store all statutory filings (annual returns, audited accounts, RoCS submissions) with renewal reminders.

---

## 11. Snag / Defect Tracking

### P1
- **Snag photo upload**: `snag-attachments` Supabase bucket added in migration 048 but the snag form has no photo upload UI. Wire it.
- **Assignment to committee member**: Snags currently have no assignee. Add `assigned_to` (profile ID) so a committee member owns resolution.
- **Public snag dashboard**: A read-only view visible to all members showing open snag count by area (common areas, amenities, infrastructure). Builds trust.

### P2
- **Snag SLA by category**: Different SLA days per snag category (Electrical = 24 hours, Civil = 7 days, Painting = 30 days).
- **Snag → vendor work order**: One-click creation of a vendor work order from an open snag. Auto-links the two records.
- **Snag bulk import from Excel**: Common during possession — hundreds of defects from a single inspection.
- **Resolution photo**: Require the assignee to upload a "before/after" photo before marking resolved.

### P3
- **Snag heat map**: Building floor plan overlay showing snag locations by flat/area.

---

## 12. Documents Library

### P1
- **Real file upload**: Documents API has a signed-URL retrieval path but the upload flow needs to be end-to-end tested with actual multipart/form-data to Supabase Storage.
- **Version history**: When a document is updated (e.g., revised by-laws), keep old versions accessible with a version selector.
- **Access control per document**: Some documents (Financials, MoM) should be exec-only. Add a `visibility` enum: `all` / `exec` / `admin`.

### P2
- **Full-text search**: Index document titles and descriptions for search.
- **Document expiry alerts**: Regulatory documents (PAN, GSTIN, BBMP NOC) have renewal dates. Remind exec 30 days before expiry.
- **Document categories**: Add Civil/Structural, Legal, Insurance, Regulatory, Society Rules, AGM Records.
- **Bulk download as ZIP**: Allow exec to download all documents in a category as a ZIP.

### P3
- **OCR text extraction**: For scanned PDFs, extract text so they become searchable.

---

## 13. Members Directory

### P1
- **Unit occupancy status**: Is the flat owner-occupied, rented out, or vacant? Affects maintenance computation and voter eligibility.
- **Emergency contact per unit**: In a medical emergency, the guard needs a secondary contact. Currently not stored.
- **Member self-edit profile**: Members can only view their profile. Add ability to edit phone, email (with OTP verification), and profile photo.
- **DPDPA erasure request**: A member who exits the society must have a formal "data erasure" flow that anonymises PII while preserving financial records.

### P2
- **Owner vs. tenant differentiation**: The `user_roles` table has no concept of "I own this flat but my tenant lives here." Add a `tenant_profiles` table linked to units.
- **Flat transfer workflow**: When a flat changes hands, formal transfer with document upload (sale deed), old owner data archival, new owner onboarding.
- **WhatsApp opt-in field**: Store WhatsApp number (may differ from registered phone). Required for WhatsApp Business API.
- **Member directory privacy**: Allow members to hide their phone/email from other members (visible only to exec/guard).

### P3
- **Member anniversary/birthday**: Optional. Shows on committee dashboard; facilitates community bonding.

---

## 14. Parking Management

### P1
- **Parking zone mapping**: Multi-level or segmented parking (Basement, Open, Stilt) with zone codes. Currently one pool.
- **Vehicle-to-slot assignment audit**: When a slot is reassigned, record the old owner + effective date. Disputes arise about historical assignments.
- **Visitor parking quota**: Track how many visitor slots are occupied in real time. Guard sees available count at gate.
- **RC/Insurance document upload**: `parking-docs` bucket is provisioned. Wire it in the parking registration form.

### P2
- **EV charging slot management**: Mark specific slots as EV-charging-capable. Allocate on first-come basis with a waiting list.
- **Parking violation log**: Guard records unauthorised parking with photo; notif sent to unit; fine can be levied.
- **Guest parking pre-authorisation**: Resident reserves a visitor slot for a specific date/time window from the app.
- **Parking sticker generation**: Generate a printable PDF parking permit sticker with vehicle number and slot code.

### P3
- **Sensor integration**: If future hardware sensors detect a vehicle in a slot, update occupancy in real time.

---

## 15. Vendors & Work Orders

### P1
- **Work order status notifications**: When exec changes work order status, vendor and requester should receive notifications.
- **Vendor invoice upload**: After completing work, vendor uploads invoice; exec reviews and links to an expense record.
- **AMC (Annual Maintenance Contract) tracker**: Track vendor AMC contracts with `start_date`, `end_date`, `scope`, `amount`. Renewal reminders 30 days before expiry.
- **Vendor rating after work order close**: Ask the requester to rate the vendor (1–5). Build a vendor scorecard over time.

### P2
- **Vendor payment history**: View all payments made to a vendor across work orders with running total.
- **Preferred vendor list**: Mark vendors as "approved" — only approved vendors can receive new work orders from non-exec members.
- **Work order template**: Common recurring work (lift maintenance, generator service) has pre-filled SOW templates.
- **Multi-vendor tender**: For large works, create a tender, invite multiple vendors to quote, compare quotes, award to one.

### P3
- **Vendor onboarding portal**: A separate URL where new vendors self-register, upload GST registration, PAN, and insurance. Exec approves.

---

## 16. Letters

### P1
- **Letter delivery receipt**: Currently letters are generated as PDFs. Add a tracking mechanism: "Downloaded by member on [date]" — useful for legal purposes.
- **Letter templates library**: Common letters (NOC for property sale, rental NOC, dues clearance certificate) should be auto-fillable from member data.
- **Digital signature**: Society secretary signs letters with a digital stamp/signature image embedded in PDF.

### P2
- **Letter archive per unit**: All letters issued to a unit accessible from the member's profile and from the unit record in the directory.
- **Bulk letter generation**: e.g., "Generate overdue dues notices for all 12 units with outstanding balances."
- **Letter approval workflow**: Draft → secretary review → president approval → issue. Currently letters can be issued without review.

### P3
- **Registered post integration**: Partner with India Post API to dispatch physical letters where required (legal notices).

---

## 17. Notifications Centre

### P1
- **Unread badge on nav**: The notifications icon in the sidebar should show a red unread-count badge.
- **Real-time delivery**: Currently notifications are only fetched on page load / tab switch. Use Supabase Realtime to push new notifications without refresh.
- **Notification grouping**: Batch similar notifications ("3 new community posts", not 3 separate rows).
- **Digest mode**: For users who find notifications noisy, offer a daily digest email summarising the day's activities.

### P2
- **Push notifications (web)**: Register service worker + Web Push API so notifications reach members even when the portal is closed.
- **Email channel**: Send notification email via Resend for high-priority types (Urgent notice, overdue payment) even if the member hasn't opened the portal recently.
- **WhatsApp channel**: For members who opt in, deliver notifications via WhatsApp Business API.
- **Notification history filter**: Filter by type (Payments, Notices, Community…) — currently shows all in one list.
- **Mark all as read**: Currently only per-notification mark-read exists.

### P3
- **Smart notification suppression**: If a member reads a notice directly, suppress the corresponding notification automatically.

---

## 18. Domestic Help (Maids) Registry

### P1 (module built; enhance)
- **Police verification document upload**: `maid-documents` bucket is provisioned. Wire it in the registration form.
- **Entry/exit log**: Guards log each domestic helper's check-in/check-out. Searchable history for security incidents.
- **Background check integration**: API integration with a background verification provider (AuthBridge, Aadhaar bridge) for automated screening.
- **Maid profile sharing**: If the same maid works in multiple units, avoid duplicate records. Link one maid profile to multiple units.

### P2
- **Work schedule**: Track which units a maid services and on which days. Residents can see their maid's schedule and confirm.
- **Maid replacement/substitute tracking**: When a maid is on leave, track the substitute name temporarily.
- **Pay slip generation**: For societies that pay maids collectively, generate monthly pay slips.
- **Maid review / reliability rating**: Anonymous per-unit rating of the maid's reliability (opt-in).

### P3
- **Group welfare schemes**: Track if the maid is enrolled in ESIC, PF (applicable in some organised setups).

---

## 19. Photo Gallery

### P1 (module built; enhance)
- **Lazy loading**: All gallery images should use `loading="lazy"` and thumbnail variants. Currently full-resolution images are loaded immediately.
- **Image compression on upload**: Resize and compress images server-side before storing in Supabase to keep storage costs low.
- **Album grouping**: Group photos into albums (Diwali 2024, Pool Inauguration, Yoga Day). Currently flat list.
- **Member upload**: Allow any member to contribute photos to a shared album (with exec approval before publish).

### P2
- **Download original**: Allow members to download original resolution photos.
- **Slideshow mode**: Full-screen slideshow with auto-advance.
- **Face privacy**: Before publishing event photos, allow members to request their face be blurred (DPDPA compliance).
- **Photo reactions**: Like/love reactions on photos.

### P3
- **Video support**: Short videos (< 50 MB) alongside photos.
- **Year-in-review auto-album**: Cron auto-creates a year-end album from the top-reacted photos of the year.

---

## 20. Feedback

### P1 (module built; enhance)
- **SLA for exec response**: Feedback submitted should receive an exec response within N days (configurable). Cron escalates overdue feedback.
- **Response visible to submitter**: Currently it's unclear if the exec's response is surfaced back to the member who submitted feedback. Wire the response display.
- **Anonymous feedback analysis**: Aggregate anonymous feedback by category for committee without revealing identities.

### P2
- **Periodic feedback surveys**: Exec creates a multi-question survey (NPS + open text) and sends to all members. Results aggregated automatically.
- **Feedback categories**: Cleanliness, Security, Committee Performance, Amenities, Communication. Helps trend analysis.
- **Public satisfaction score**: Show society's average member satisfaction score on the exec dashboard.

### P3
- **Benchmarking**: Compare satisfaction score month-over-month.

---

## 21. Analytics / Reports Hub

### P1
- **Financial summary report**: Monthly P&L — collections vs. expenses vs. outstanding. Downloadable PDF for committee review.
- **Occupancy report**: How many flats are owner-occupied vs. rented vs. vacant. Important for voter lists and maintenance load.
- **Collection efficiency**: Percentage of dues collected on time, overdue rate by month.

### P2
- **Complaint resolution time chart**: Average days-to-resolve by category over rolling 6 months.
- **Event attendance analytics**: RSVP vs. actual attendance ratio per event type.
- **Vendor spend analysis**: Top 5 vendors by expenditure; spend by category (Civil, Electrical, Landscaping).
- **Facility utilisation**: Booking hours per facility per month.
- **Member engagement score**: Polls voted, events attended, community posts — a simple engagement index per unit.

### P3
- **Predictive maintenance calendar**: Based on equipment age and past expense history, suggest when lifts, generators, pumps need servicing.
- **Export to Excel/CSV**: All reports downloadable as spreadsheets in addition to PDF.

---

## 22. Admin (RBAC, Audit, Staff, TDS)

### P1
- **Audit log viewer**: `audit_logs` table exists but there's no portal page to search/filter it. Exec/admin should be able to search by user, resource type, date range.
- **Session management**: Show all active sessions for a user and allow remote logout (DPDPA requirement for data access control).
- **Staff account lifecycle**: Security guard and vendor accounts need formal deactivation when the person leaves. Currently it's a manual Supabase operation.
- **RBAC change audit**: All role grants/revocations must be logged in audit_logs with the grantor's identity.

### P2
- **Feature flag UI**: Currently feature flags are database rows. Provide a toggle UI so admin can enable/disable modules per society without SQL.
- **System health dashboard**: Show Supabase connection status, recent cron run results, upload queue depth, storage usage.
- **TDS certificate generation (Form 16A)**: Download Form 16A for each vendor for the financial year.
- **Bulk user import**: Upload a CSV of new members for batch onboarding.

### P3
- **Multi-society support**: The schema already has `society_id` throughout. A future admin role can manage multiple societies from one login.

---

## New Modules — High Priority

### NM-1: Water / Tanker Management (P1)
Indian apartment societies routinely order water tankers during HMWSSB supply interruptions. Residents currently call the committee directly.

**Features**: Tanker booking with vendor, volume, and cost tracking; notify all members when a tanker is ordered; per-unit water consumption log if sub-meters exist; bore-well pump maintenance log; water quality test record with upload.

---

### NM-2: Security Patrol Log (P1)
Guards need to log their patrol checkpoints and any incidents observed during rounds. Currently entirely manual.

**Features**: Guard taps a QR sticker at each patrol checkpoint (lift, gate, parking, terrace); timestamp + location logged; incident flag with photo; daily patrol report auto-emailed to exec; patrol gaps alerted (if no checkpoint scanned in 2 hours during night duty).

---

### NM-3: AMC / Planned Maintenance Calendar (P1)
Lifts, generators, pumps, and CCTV are maintained on annual contracts. Due dates are tracked in spreadsheets, causing missed services.

**Features**: AMC register for each equipment item (vendor, contract start/end, value, scope); preventive maintenance schedule (monthly, quarterly, half-yearly); cron sends reminder 30 days before each service due; service completion log with engineer name and remarks; link to vendor record and expense entry.

---

### NM-4: Move-In / Move-Out (P2)
Flat handovers involve NOC clearance, utility meter reading, and damage deposit. No structured workflow exists.

**Features**: Resident initiates move-out request; exec checklist (dues cleared, parking surrendered, maid access removed); meter reading recorded at move-out; damage deposit refund approval workflow; flat re-listed as vacant until new owner/tenant registered; move-in checklist for new resident.

---

### NM-5: GST / TDS Compliance Dashboard (P1)
UTAMACS must file GSTR-1, GSTR-3B and TDS returns quarterly. Currently done manually from spreadsheet data.

**Features**: Consolidate all maintenance income (GST applicable above ₹7,500/unit/month); generate GSTR-1 data export; consolidate TDS deducted on vendor payments; generate Form 26Q data export; track GST registration status and return due dates; alert exec 7 days before filing deadline.

---

### NM-6: Delivery / Package Tracking (P2)
E-commerce deliveries to gated communities are a daily friction point. Guards receive packages on behalf of residents.

**Features**: Guard logs package (courier, AWB, photo); resident notified immediately; resident acknowledges pickup; report of packages held for > 24 hours; integration with major courier tracking APIs (Delhivery, BlueDart, Ekart) for auto-log on SMS.

---

### NM-7: Tenant KYC / Police Verification (P1)
Under Hyderabad City Police guidelines and TSRERA, rental tenants must be police-verified. Society must maintain a tenant register.

**Features**: Owner registers tenant with ID proof (Aadhaar masked), photo, emergency contact; auto-generate police verification letter for submission to local station; Aadhaar verification (DigiLocker API); tenant lease document upload; notify exec on new tenant registration for approval.

---

### NM-8: Utility Monitoring (P2)
Common area electricity and water consume a large portion of the society's expense. Proactive monitoring reduces cost.

**Features**: Monthly common area electricity unit entry (or smart meter integration); benchmark per-month usage; alert if month-on-month exceeds threshold; water consumption from tanker + borewell log; solar rooftop generation log (if applicable); utility expense auto-linked to finance module.

---

### NM-9: School Bus Coordination (P3)
Many apartment societies in Hyderabad run school bus pooling. Currently managed by parent WhatsApp groups.

**Features**: Bus route and stop registration; student registration (unit, school, class, timing); parent receives route deviation alert (GPS integration optional); monthly fee collection via Finance module; driver profile with license and background check; emergency SOS button on bus.

---

## Indian Market Context: Key Differentiators to Build

These items are absent from or weak in NoBrokerHood / MyGate but highly valued in Telangana-specific societies:

1. **Telugu language support**: NavBar, notices, and key forms in Telugu. Significant portion of non-English-comfortable residents.
2. **TSRERA-ready evidence packaging**: Automatic generation of a RERA complaint packet (photos + correspondence timeline + builder SLA + cost incurred).
3. **GHMC property tax integration**: Help members verify their property tax status and due amounts from the society portal (screen-scrape or GHMC API if available).
4. **HMWSSB water bill tracking**: Track municipality water supply hours per building block; correlate with tanker spend.
5. **Telangana MACS Act compliance**: Statutory meeting frequency, notice periods, quorum requirements, register maintenance — all built into workflows rather than left to exec knowledge.

---

*Last updated: 2026-05-07 | Generated from multi-session product research*
