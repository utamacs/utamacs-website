# UTA MACS Portal — Operations Runbook

**Society:** Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited  
**Registration No:** TG/RRD/MACS/2026-15/FOW & M  
**Portal:** portal.utamacs.org  
**Runbook Version:** 1.0 — May 2026  
**Validated by:** Secretary (follow every procedure without assistance before go-live)

---

## Table of Contents

1. [Quick Reference — Emergency Contacts & URLs](#1-quick-reference)
2. [Daily Monitoring Checks](#2-daily-monitoring-checks)
3. [Adding a New Member](#3-adding-a-new-member)
4. [Resetting a Member's Password](#4-resetting-a-members-password)
5. [Changing a Member's Role](#5-changing-a-members-role)
6. [Running a Committee Election](#6-running-a-committee-election)
7. [Activating Delegation (President Absent)](#7-activating-delegation)
8. [Deactivating Delegation (President Returns)](#8-deactivating-delegation)
9. [Checking and Clearing the Upload Queue](#9-upload-queue)
10. [Recovering from GitHub Storage Failure](#10-recovering-from-github-storage-failure)
11. [Recovering from Supabase Database Failure](#11-recovering-from-supabase-database-failure)
12. [Rotating the GitHub App Private Key](#12-rotating-the-github-app-private-key)
13. [Deactivating a Member (Flat Sold / Vacancy)](#13-deactivating-a-member)
14. [Enabling / Disabling Proxy Voting](#14-proxy-voting)
15. [Managing the Email Draft Queue](#15-email-draft-queue)
16. [Updating a Rule (Rules Engine)](#16-updating-a-rule)
17. [Monitoring Cron Jobs](#17-monitoring-cron-jobs)
18. [Granting or Revoking Admin Access](#18-admin-access)
19. [Monthly Maintenance Checklist](#19-monthly-maintenance-checklist)
20. [What to Do If the Portal Is Completely Down](#20-portal-down)

---

## 1. Quick Reference

### Emergency Contacts

| Role | Name | Contact |
|---|---|---|
| System Admin | [Admin Name] | [Phone / WhatsApp] |
| Secretary | [Secretary Name] | [Phone / WhatsApp] |
| President | Bal Reddy | [Phone / WhatsApp] |
| Hosting (Vercel) | Support | vercel.com/support |
| Database (Supabase) | Support | supabase.com/support |
| Email (Resend) | Support | resend.com/support |

### Key URLs

| Service | URL | Login |
|---|---|---|
| Portal | portal.utamacs.org | Committee member email |
| Admin panel | portal.utamacs.org/portal/admin | Admin account |
| Vercel dashboard | vercel.com | Admin's Vercel account |
| Supabase dashboard | supabase.com/dashboard | Admin's Supabase account |
| GitHub | github.com/utamacs | Admin's GitHub account |
| Resend | resend.com | Admin's Resend account |

### Vercel Environment Variables (Never share these)

| Variable | What it is |
|---|---|
| `GITHUB_APP_PRIVATE_KEY` | Private key for governance-data repo access |
| `GITHUB_APP_ID` | GitHub App ID |
| `GITHUB_INSTALLATION_ID` | Installation ID for utamacs org |
| `SUPABASE_URL` | Database connection URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (never expose to browser) |
| `RESEND_API_KEY` | Email sending key |
| `CRON_SECRET` | Secret to authenticate cron job calls |
| `ADMIN_EMAIL` | Email address for system alerts |

---

## 2. Daily Monitoring Checks

Do this every morning (takes 2 minutes):

1. Open portal.utamacs.org/portal/admin/queue
2. Verify:
   - **GitHub Storage:** ✅ Connected (not ⚠️ or ❌)
   - **Circuit Breaker:** ✅ Closed
   - **Upload Queue:** 0 pending failed items (if any, see §9)
   - All cron jobs show recent timestamps

3. Check email-drafts dashboard at /portal/admin/email-drafts
   - Any **Tier 3 drafts** (formal builder/member communications) older than 48 hours should be reviewed and sent or discarded.

4. Check dashboard for:
   - Any items flagged as PERMANENTLY_FAILED in upload queue
   - Any approval-pending items older than 72 hours (re-notify the approver)

---

## 3. Adding a New Member

**When:** A new apartment owner moves in or an existing owner registers for portal access.
**Who does this:** Admin, after receiving authorization from President or Secretary via WhatsApp/meeting.

### Steps

1. Log into portal.utamacs.org with admin account
2. Go to **Admin → Users** → click **[+ Invite Member]**
3. Enter:
   - Email address (exactly as the member provided — case-sensitive)
   - Flat number (e.g., "207")
   - Intended role: for regular owners, leave as **Member**; for committee members, select their role
4. Click **[Send Invitation]**
5. The system sends an email to the member with a link. The link expires in 7 days.
6. Member receives: email with link → clicks → fills name and password → accepts privacy consent → account created
7. You receive an email: "[Name] (Flat 207) has accepted their invitation"

### If the invite expires before the member clicks

1. Go to Admin → Users → **Pending Invites** tab
2. Find the expired invite → click **[Resend]**
3. A new 7-day link is generated and sent

### If the invite needs to be cancelled

1. Go to Admin → Users → Pending Invites tab
2. Find the invite → click **[Cancel]**
3. The link is immediately invalidated

---

## 4. Resetting a Member's Password

**The portal uses Supabase Auth.** Password resets are self-service through the login page.

### Standard reset (member can receive email)

1. Tell the member to go to portal.utamacs.org
2. Click "Forgot Password" on the login page
3. Enter their email address
4. They receive a reset link (valid for 1 hour)
5. They set a new password and log back in

### Admin-assisted reset (member's email is inaccessible)

1. Log into Supabase dashboard → Authentication → Users
2. Find the member by email
3. Click **[Send password reset email]** (this uses the member's registered email)
4. If the email is also lost: escalate to Supabase support (identity verification required)

**Admin cannot directly set a member's password** — this is a security feature. Password resets always go through the member's email.

---

## 5. Changing a Member's Role

**When:** Committee election, resignation, role expansion, or error correction.
**Who does this:** Admin, after verbal/WhatsApp/email authorization from President or Secretary.

There are **two independent fields** to update: the **Role** (determines permissions) and
the **Committee Title** (display label only, no permission effect).

### Steps — Role change

1. Admin → Users → find the member → click **[View]** → click **[Change Role]**
2. **Role dropdown** — four choices only: `member`, `executive`, `secretary`, `president`
   - Do NOT try to encode "Treasurer" or "VP" here — those are titles, not roles
3. **Committee Title field** — set the display designation, e.g.:
   - `Vice President`, `Working President`, `Joint Secretary`
   - `Treasurer`, `Joint Treasurer`, `Executive Member`, `General Secretary`, `President`
4. Enter a reason: e.g., "Committee election — June 2026 AGM" or "Treasurer resigned"
5. Review the permission diff preview:
   - "Changing [Name] from Member to Executive. Gaining: hoto.create, snag.create, vendor.vote, audit.view. Losing: nothing."
6. **If assigning Treasurer or Joint Treasurer title:** system prompts "Grant finance.view + finance.enter overrides for this user? [Yes] [No]" — click **[Yes]**
7. Click **[Confirm Change]**
8. The member receives an email: "Your UTA MACS access has been updated"
9. The Secretary is notified (FYI)

### Steps — Title-only change (no permission change)

1. Admin → Users → Roles View → find the member → click **[Edit]** next to their name
2. Update the Committee Title field (e.g., change "Executive Member" → "Vice President")
3. Click **[Save Title]**
4. A `role_change_log` entry is created with `change_type = 'TITLE_ONLY'`
5. No permissions change; member receives a brief FYI email

**Rule:** Admin cannot change their own role. A second admin must do it.

---

## 6. Running a Committee Election

**When:** After the Annual General Body Meeting where new committee members are elected.
**Who does this:** Admin, after receiving the election outcome from President or Secretary (via minutes, WhatsApp, or meeting).

The election bulk-update workflow handles two types of change simultaneously:
- **Role changes** — change `portal_role` value (determines permissions)
- **Title changes** — update `committee_title` (display designation; no permission effect)

### Steps

1. Admin → Elections → click **[New Election]**
2. Enter:
   - Election date (the actual AGM date)
   - Description: "Annual General Body Meeting 2026"
   - Attach AGM minutes document (optional but recommended)
3. The system shows the current committee roster as a spreadsheet-like grid with **two columns per person: Role | Title**
4. For each person, set their new Role (member / executive / secretary / president) and their new Title (free text: "President", "Vice President", "Treasurer", etc.)
   - If someone is re-elected to the same role with the same title: leave both unchanged
   - If a person leaves the committee entirely: set Role = `member`, clear the Title
5. Review the **Change Preview** screen — it shows two sections:
   - **ROLE CHANGES** — people whose `portal_role` is changing (includes permission diff)
   - **TITLE-ONLY CHANGES** — people whose role stays the same but title changes (no permission impact)
   - Outgoing members not re-elected automatically revert to `member` role + blank title
6. **Finance access prompt:** If any person is newly assigned Treasurer or Joint Treasurer title, the preview highlights them: "Grant finance.view + finance.enter overrides? [Yes for each] [Yes for all] [Skip]" — select **[Yes]** for each Treasurer-title holder
7. Click **[Confirm Election]**
8. All changes happen simultaneously (atomic — all succeed or none change)
9. Every affected member receives an email with their new role and title
10. The President and Secretary receive a summary email with the full change list

### Role vs. Title quick reference

| Person | Role (`portal_role`) | Title (`committee_title`) |
|---|---|---|
| Main leader | `president` | "President" |
| #2 leader | `executive` | "Vice President" |
| Day-to-day ops | `secretary` | "General Secretary" |
| Deputy ops | `executive` | "Joint Secretary" |
| Finance lead | `executive` | "Treasurer" |
| Deputy finance | `executive` | "Joint Treasurer" |
| General committee | `executive` | "Executive Member" |
| Resident, no committee | `member` | *(blank)* |

### If the election workflow fails mid-way

- The system uses atomic transactions. Either ALL changes apply, or NONE do.
- If you see an error: check the admin queue page; no partial changes will have been saved.
- Try again after resolving any displayed error.

---

## 7. Activating Delegation

**When:** President will be absent for more than 7 working days (Byelaw §8.2) or Secretary is unavailable (§8.4).

### President → Vice President delegation

The VP is an `executive` with `committee_title = 'Vice President'`. Delegation grants
them `hoto.approve_president` as a user feature override for the delegation period.

1. Admin → Delegation → click **[Activate President Delegation]**
2. Select the Vice President (system shows executives with VP title) as the delegate
3. Enter reason: "President [Name] on medical leave from [date] to [date] (per §8.2)"
4. Click **[Activate]**
5. All future President-approval actions are now routed to the Vice President
6. Every approval action by VP is tagged: "Acting per §8.2 delegation"
7. President and VP both receive confirmation emails

### Secretary → Joint Secretary delegation

The Joint Secretary is an `executive` with `committee_title = 'Joint Secretary'`.
Delegation grants them `hoto.approve_secretary` as a user feature override.

1. Admin → Delegation → click **[Activate Secretary Delegation]**
2. Select the Joint Secretary (system shows executives with Joint Secretary title)
3. Enter reason
4. Click **[Activate]**

### Both President and VP unavailable

- If both are unavailable, the system freezes all approval gates
- A banner appears: "Approval chain unavailable — no approvals possible"
- All committee members are notified
- **There is no workaround for this in the portal** — the President must delegate before becoming unavailable, or the society must hold an emergency meeting

---

## 8. Deactivating Delegation

**When:** The delegator (President or Secretary) returns.

1. Admin → Delegation → find the active delegation
2. Click **[Deactivate]**
3. Enter: "President [Name] returned on [date]"
4. Click **[Confirm Deactivation]**
5. Routing immediately reverts to the original approval chain
6. Both parties receive email confirmation

---

## 9. Upload Queue

**Normal state:** 0 items pending in the queue. Files are processed within 60 seconds.

### Checking queue status

1. Admin → Queue Dashboard (or portal.utamacs.org/portal/admin/queue)
2. The queue shows: pending, in-progress, failed items
3. Items with **PERMANENTLY_FAILED** status need attention

### Retrying a failed upload

1. Find the PERMANENTLY_FAILED item in the Dead Letter Queue
2. Read the error message to understand what went wrong:
   - **"GitHub API 422"** — file too large (> 100MB). Download the original, compress it, re-upload through the portal
   - **"GitHub App token expired"** — GitHub App key needs rotation (see §12)
   - **"Rate limit exceeded"** — wait 1 hour, then click [Retry]
   - **"Circuit breaker open"** — GitHub storage is down (see §10)
3. For errors other than "file too large": click **[↩ Retry]** to reset the item to the queue

### Abandoning a failed upload

1. If the file is no longer needed: click **[✗ Abandon]**
2. Enter a reason: "File was test upload — not needed" or "Will re-upload via corrected format"
3. The original uploader receives an email notification

### Manually triggering the upload cron

If items are stuck in PENDING for more than 5 minutes:

1. Admin → Queue Dashboard → click **[Trigger Manually]** next to "process-uploads"
2. The cron runs immediately
3. Refresh the page after 30 seconds to see results

---

## 10. Recovering from GitHub Storage Failure

**Symptoms:** GitHub Storage shows ⚠️ or ❌ in Queue Dashboard. Files are not being committed.

### What the system does automatically

1. After 3 consecutive failures: circuit breaker opens → upload processing stops
2. Every 5 minutes: system tests GitHub connectivity (read-only)
3. When connectivity restores: circuit breaker closes automatically; queued files are processed

### If automatic recovery has not happened within 30 minutes

1. Log into GitHub (github.com/utamacs) with the admin account
2. Check if the `governance-data` repository is accessible
3. Check GitHub's status page: githubstatus.com
4. If GitHub is up but the portal cannot connect: the GitHub App token may have expired (see §12)

### Verifying recovery

1. Admin → Queue Dashboard
2. **Circuit Breaker: ✅ Closed** — recovery is complete
3. Any queued files will process automatically within 60 seconds

### During an outage

- Members can still view HOTO items, snags, and all existing records
- Status updates and comments still work (they use Supabase, not GitHub)
- **Only file uploads and new document commits are affected**
- Tell committee members: "Documents are queued and will save automatically when storage is restored"

---

## 11. Recovering from Supabase Database Failure

**Symptoms:** Portal login fails with "Service unavailable" or all pages return errors.

### Immediate steps

1. Check Supabase status: status.supabase.com
2. Log into Supabase dashboard → check your project is "Active" (not "Paused")

### If the project is paused (free tier only — we use Pro)

- This should not happen on Supabase Pro
- If it does: log into Supabase dashboard → click "Restore project"
- The keepalive cron (every 6 days) prevents this on the free tier

### If Supabase is having an outage

- Check status page for ETA
- Portal is fully offline until Supabase restores
- No data is lost — Supabase handles backups
- Notify committee: "Portal is temporarily offline. We'll notify you when it's restored."

### Verifying recovery

1. Attempt to log in to the portal
2. Successfully seeing the dashboard = Supabase is up

---

## 12. Rotating the GitHub App Private Key

**When:** Quarterly rotation, or if you suspect the key has been compromised.
**Warning:** After rotating the key, new uploads will fail until the Vercel environment variable is updated. Do this during off-peak hours.

### Steps

1. Log into GitHub → Settings → Developer settings → GitHub Apps → find "UTA MACS Governance"
2. Under "Private keys" → click **[Generate a new private key]**
3. Download the `.pem` file
4. Log into Vercel dashboard → your project → Settings → Environment Variables
5. Find `GITHUB_APP_PRIVATE_KEY`
6. Edit: paste the entire contents of the downloaded `.pem` file (including `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` lines)
7. Click **[Save]**
8. In Vercel: go to Deployments → click **[Redeploy]** on the latest deployment (this picks up the new env var)
9. Wait for deployment to complete (1-2 minutes)
10. Test: upload a small file through the portal; verify it commits to `governance-data` within 60 seconds
11. Back in GitHub: delete the OLD private key (click the trash icon next to the old key)
12. Delete the downloaded `.pem` file from your computer (it should never be stored on disk)

**Do not skip step 11** — leaving old keys active is a security risk.

---

## 13. Deactivating a Member

**When:** An apartment is sold (after NOC is issued) or a member voluntarily leaves.
**Who does this:** Admin, after authorization from President or Secretary.

### Steps

1. Admin → Users → find the member → click **[View]** → click **[Deactivate]**
2. Enter reason: "Flat 204 sold — NOC issued 2026-06-15" or "Member requested deactivation"
3. Click **[Confirm Deactivation]**
4. Immediately:
   - All active sessions for that user are ended (they are logged out)
   - Their assigned HOTO/snag items are auto-reassigned by role
   - They receive an email: "Your UTA MACS portal access has been deactivated"
   - Secretary is notified (FYI)
   - Their data is **retained** (10-year audit requirement — accounts are never deleted)

### Reactivating a member

1. Admin → Users → **Inactive** tab → find the member → click **[Reactivate]**
2. Enter mandatory reason: "Flat re-purchased — new owner same email" or "Error — deactivated incorrectly"
3. Member receives email and can log in again with their existing password

---

## 14. Proxy Voting

**Default:** Proxy voting is **disabled**. This removes complexity for the initial operation phase.

### Enabling proxy voting

1. Admin → Rules Engine → Parameters tab
2. Find "Proxy voting" → click **[Enable]**
3. Enter reason: "Enabling proxy voting for [vendor vote name] — director [Name] will be travelling"
4. Confirm → proxy voting enabled immediately

### Using proxy voting (when enabled)

1. Admin uploads the notarized PoA document to the director's profile
2. The proxy holder casts the vote during the voting window
3. The vote is linked to both the proxy document and the original director's record
4. When the vote closes, disable proxy voting again if it was only for this vote

### Disabling proxy voting

Same path as enabling — click **[Disable]** from the Rules Engine Parameters tab.

---

## 15. Email Draft Queue

**Who can act:** Secretary and President can review and send Tier 3 drafts.

### Reviewing and sending a formal email draft

1. Go to portal.utamacs.org/portal/admin/email-drafts (or click the 📧 badge in nav)
2. Find the draft — click **[Preview Full Email]** to see exactly what the recipient will see
3. If the content is correct: click **[✉ Send Now]**
   - The email is sent via Resend; the send is recorded in the system
4. If the content needs editing: click **[✏ Edit Subject / Body]** → make changes → click **[Preview]** to verify → **[✉ Send Now]**
5. If the draft is no longer needed: click **[✗ Discard]** → enter reason

**Important:** Formal builder communications (legal notices, escalation letters) should not sit as drafts for more than 48 hours. Delayed notices weaken the society's legal position.

### A draft was sent but the email bounced

1. Check the Resend dashboard (resend.com) for bounce details
2. Update the recipient's email address in their profile
3. Re-create the email draft (re-trigger the notice from the HOTO item or snag item page)
4. Send the new draft to the corrected email

---

## 16. Updating a Rule (Rules Engine)

**When:** Operational parameters need adjustment (e.g., extending invite link validity, changing SLA escalation days).
**Who does this:** Admin only. Byelaw-locked rules cannot be changed this way.

### Steps

1. Admin → Rules Engine → select the appropriate tab (Parameters / Escalation / Notification / Validation)
2. Find the rule → click **[Edit]**
3. Enter the new value
4. Enter a mandatory reason: "Extended invite validity for members with slow email — Trial period Jun-Aug 2026"
5. Review the confirmation: "You are changing [rule] from [old value] to [new value]"
6. Click **[Confirm]**
7. The change takes effect on the next action — in-flight operations use the previous value

### Reverting a rule change

1. Find the rule → click **[Reset to Default]**
2. Enter reason: "Reverting to byelaw default — temporary change no longer needed"
3. Confirm

---

## 17. Monitoring Cron Jobs

### Checking cron health

1. Admin → Queue Dashboard
2. The **CRON STATUS** section shows the last-run time for each cron
3. If a cron is overdue (last run > alert threshold), a ⚠️ appears with **[Trigger Manually]**

### Expected cron schedules

| Cron | How often | Alert if not seen for |
|---|---|---|
| process-uploads | Every 60 seconds | 5 minutes |
| github-health | Every 15 minutes | 45 minutes |
| process-pdfs | Every 30 seconds | 5 minutes |
| builder-sla | Once daily (midnight) | 36 hours |
| supabase-ping | Every 6 days | 8 days |
| pdf-purge | Once daily (midnight) | 36 hours |
| generate-weekly-digest | Every Monday 7:00 AM | On Monday: 4 hours |

### Manually triggering a cron

1. In Queue Dashboard → **[Trigger Manually]** next to the cron name
2. Wait 30 seconds → refresh page → verify "last run" timestamp updated

### If a cron consistently fails to run

1. Check Vercel dashboard → Project → Functions → Cron Jobs
2. Verify the cron is listed and the schedule is correct
3. Check the function logs for error messages
4. If the cron shows "Skipped" — this is normal for Vercel Hobby plan (hobby does not support cron); confirm we are on Vercel Pro

---

## 18. Admin Access

### Granting admin access to another person

**Only do this for people who are fully trusted with all member data and system settings.**

1. Admin → Users → **[Admin]** sub-page → **[+ Grant Admin Access]**
2. Enter the email address of the existing member
3. Confirm — `is_admin = true` is set; they receive an email notification
4. They now have full admin panel access

### Revoking admin access

1. Admin → Users → Admin sub-page → find the admin → **[Revoke Admin]**
2. Confirm
3. They lose admin panel access immediately; their governance role is unaffected
4. **You cannot revoke your own admin access.** A second admin must do it.
5. The system prevents reducing admin count below 1.

---

## 19. Monthly Maintenance Checklist

Run on the first working day of each month:

**Security**
- [ ] Review audit_log for any unexpected access patterns (Admin → Audit Log)
- [ ] Check that no pending invites are over 7 days old (delete and re-invite if needed)
- [ ] Review active per-user feature overrides — are any expired? (Admin → each user → Permissions tab)

**Compliance**
- [ ] Defaulter list published (generated automatically — first Sunday of month; verify it ran)
- [ ] Any HOTO items overdue > 30 days? (Dashboard → Critical Deadlines)
- [ ] Pending email drafts older than 7 days? (Review and act or discard)

**System Health**
- [ ] All crons running? (Queue Dashboard)
- [ ] Upload queue: 0 failed items?
- [ ] GitHub App private key: is rotation due? (Rotate every 3 months)

**Records**
- [ ] Meeting minutes from last Board meeting uploaded? (Must be within 7 days — §7.16e)
- [ ] Any vendor contracts expiring in next 90 days? (Dashboard → Vendor section)

---

## 20. What to Do If the Portal Is Completely Down

**"Completely down"** means: portal.utamacs.org returns an error, or the login page does not load.

### Step 1 — Check status pages (takes 2 minutes)

| Service | Status page |
|---|---|
| Vercel | vercel-status.com |
| Supabase | status.supabase.com |
| GitHub | githubstatus.com |

If any of these show an outage: the portal will recover automatically when the service restores. No action needed. Monitor the status page.

### Step 2 — Check Vercel deployment

1. Log into Vercel dashboard → your project
2. Is the latest deployment status "Ready" (green)?
3. If "Error": check the deployment logs → look for the error → if it is a code error, the deployment needs to be fixed
4. If the deployment is "Ready" but the portal is down: try a manual redeploy

### Step 3 — Contact Admin

If steps 1 and 2 don't resolve it within 15 minutes, contact the System Admin directly (see §1 for contact details).

### While the portal is down — interim governance

- Committee can continue using WhatsApp for coordination
- Document all decisions made during the outage with timestamp and participants
- When the portal recovers: upload all decisions as "migrated from WhatsApp" documents with `source_description = "Decision made via WhatsApp during portal outage [date]"`
- The audit trail can be reconstructed from WhatsApp messages

---

*Runbook Version 1.0 — May 2026*  
*This runbook is validated when: the Secretary can follow every procedure without asking the Admin for help.*  
*Last validated: [date — to be filled before go-live]*  
*Next review: After Phase 1 go-live (June 2026)*
