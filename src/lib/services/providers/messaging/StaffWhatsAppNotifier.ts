/**
 * Staff-specific WhatsApp notification helpers.
 * Each function maps to one pre-registered Meta template (see WA_TEMPLATES).
 *
 * Template registration guide (do this in Meta's Template Manager):
 *
 * utamacs_staff_task_assigned  (hi/te/en_IN)
 *   Body: "नमस्ते {{1}}, आपको काम सौंपा गया: {{2}}। समय: {{3}}। - UTAMACS"
 *         "నమస్కారం {{1}}, మీకు పని అప్పగించబడింది: {{2}}. సమయం: {{3}}. - UTAMACS"
 *         "Hi {{1}}, task assigned: {{2}}. Due by {{3}}. - UTAMACS"
 *
 * utamacs_staff_checkin_confirm  (hi/te/en_IN)
 *   Body: "✅ {{1}} को हाजिरी दर्ज हुई {{2}} बजे। - UTAMACS"
 *
 * utamacs_late_checkin_alert  (en_IN)
 *   Body: "⚠ ALERT: {{1}} ({{2}}) hasn't checked in. Shift started at {{3}}. - UTAMACS Staff"
 *
 * utamacs_absent_alert  (en_IN)
 *   Body: "📋 UTAMACS Daily: {{1}} staff absent today — {{2}}. Please arrange cover."
 *
 * utamacs_proposal_approved  (hi/te/en_IN)
 *   Body: "✅ Your task proposal '{{1}}' has been approved and added to the template library. - UTAMACS AFM"
 *
 * utamacs_proposal_rejected  (hi/te/en_IN)
 *   Body: "❌ Task proposal '{{1}}' was not approved. Reason: {{2}}. - UTAMACS AFM"
 *
 * utamacs_compliance_overdue  (en_IN)
 *   Body: "🔴 COMPLIANCE ALERT: {{1}} log for {{2}} is {{3}} day(s) overdue. Immediate action required. - UTAMACS"
 *
 * utamacs_agency_license_expiring  (en_IN)
 *   Body: "⚠ Agency '{{1}}' license ({{2}}) expires in {{3}} days. Please renew. - UTAMACS Admin"
 *
 * utamacs_monthly_staff_report  (en_IN)
 *   Body: "📊 UTAMACS Staff Report — {{1}}: Attendance {{2}}%, Tasks {{3}}% complete. Download: {{4}}"
 *
 * utamacs_staff_task_overdue  (hi/te/en_IN)
 *   Body: "⏰ Task overdue: '{{1}}'. Was due at {{2}}. Please complete and update. - UTAMACS"
 */

import {
  sendWhatsApp,
  sendWhatsAppBulk,
  WA_TEMPLATES,
  LANG_MAP,
  type WaLangCode,
  type BulkResult,
} from './WhatsAppService';

// ── Staff self-service notifications ──────────────────────────────────────────

export async function notifyTaskAssigned(params: {
  phone: string;
  staffName: string;
  taskTitle: string;
  dueTime: string;       // e.g. "5:00 PM"
  langPref?: string;     // 'en' | 'hi' | 'te'
}) {
  const lang: WaLangCode = LANG_MAP[params.langPref ?? 'en'] ?? 'en_IN';
  return sendWhatsApp({
    to: params.phone,
    templateName: WA_TEMPLATES.STAFF_TASK_ASSIGNED,
    languageCode: lang,
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.staffName },
        { type: 'text', text: params.taskTitle },
        { type: 'text', text: params.dueTime },
      ],
    }],
  });
}

export async function notifyCheckInConfirmed(params: {
  phone: string;
  staffName: string;
  time: string;          // e.g. "08:02 AM"
  langPref?: string;
}) {
  const lang: WaLangCode = LANG_MAP[params.langPref ?? 'en'] ?? 'en_IN';
  return sendWhatsApp({
    to: params.phone,
    templateName: WA_TEMPLATES.STAFF_CHECKIN_CONFIRM,
    languageCode: lang,
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.staffName },
        { type: 'text', text: params.time },
      ],
    }],
  });
}

export async function notifyCheckOutConfirmed(params: {
  phone: string;
  staffName: string;
  time: string;
  langPref?: string;
}) {
  const lang: WaLangCode = LANG_MAP[params.langPref ?? 'en'] ?? 'en_IN';
  return sendWhatsApp({
    to: params.phone,
    templateName: WA_TEMPLATES.STAFF_CHECKOUT_CONFIRM,
    languageCode: lang,
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.staffName },
        { type: 'text', text: params.time },
      ],
    }],
  });
}

export async function notifyTaskOverdue(params: {
  phone: string;
  taskTitle: string;
  dueTime: string;
  langPref?: string;
}) {
  const lang: WaLangCode = LANG_MAP[params.langPref ?? 'en'] ?? 'en_IN';
  return sendWhatsApp({
    to: params.phone,
    templateName: WA_TEMPLATES.STAFF_TASK_OVERDUE,
    languageCode: lang,
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.taskTitle },
        { type: 'text', text: params.dueTime },
      ],
    }],
  });
}

// ── Supervisor / AFM alert notifications ───────────────────────────────────────

export async function alertLateCheckIn(params: {
  supervisorPhone: string;
  staffName: string;
  department: string;
  shiftStartTime: string; // e.g. "6:00 AM"
}) {
  return sendWhatsApp({
    to: params.supervisorPhone,
    templateName: WA_TEMPLATES.LATE_CHECKIN_ALERT,
    languageCode: 'en_IN',
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.staffName },
        { type: 'text', text: params.department },
        { type: 'text', text: params.shiftStartTime },
      ],
    }],
  });
}

// Sends absent alert to AFM listing all absent staff (summarised)
export async function alertAbsentStaff(params: {
  afmPhone: string;
  absentCount: number;
  departmentSummary: string; // e.g. "Security: 2, Housekeeping: 1"
}) {
  return sendWhatsApp({
    to: params.afmPhone,
    templateName: WA_TEMPLATES.ABSENT_ALERT,
    languageCode: 'en_IN',
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: String(params.absentCount) },
        { type: 'text', text: params.departmentSummary },
      ],
    }],
  });
}

export async function notifyProposalApproved(params: {
  supervisorPhone: string;
  taskTitle: string;
  langPref?: string;
}) {
  const lang: WaLangCode = LANG_MAP[params.langPref ?? 'en'] ?? 'en_IN';
  return sendWhatsApp({
    to: params.supervisorPhone,
    templateName: WA_TEMPLATES.PROPOSAL_APPROVED,
    languageCode: lang,
    components: [{
      type: 'body',
      parameters: [{ type: 'text', text: params.taskTitle }],
    }],
  });
}

export async function notifyProposalRejected(params: {
  supervisorPhone: string;
  taskTitle: string;
  reason: string;
  langPref?: string;
}) {
  const lang: WaLangCode = LANG_MAP[params.langPref ?? 'en'] ?? 'en_IN';
  return sendWhatsApp({
    to: params.supervisorPhone,
    templateName: WA_TEMPLATES.PROPOSAL_REJECTED,
    languageCode: lang,
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.taskTitle },
        { type: 'text', text: params.reason },
      ],
    }],
  });
}

// ── Compliance alerts ─────────────────────────────────────────────────────────

export async function alertComplianceOverdue(params: {
  recipientPhone: string;  // AFM or exec
  complianceType: string;  // e.g. "Fire extinguisher inspection"
  dueDate: string;         // e.g. "01 May 2026"
  daysOverdue: number;
}) {
  return sendWhatsApp({
    to: params.recipientPhone,
    templateName: WA_TEMPLATES.COMPLIANCE_OVERDUE,
    languageCode: 'en_IN',
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.complianceType },
        { type: 'text', text: params.dueDate },
        { type: 'text', text: String(params.daysOverdue) },
      ],
    }],
  });
}

export async function alertAgencyLicenseExpiring(params: {
  adminPhone: string;
  agencyName: string;
  licenseType: string;   // e.g. "PSARA License"
  daysUntilExpiry: number;
}) {
  return sendWhatsApp({
    to: params.adminPhone,
    templateName: WA_TEMPLATES.AGENCY_LICENSE_EXPIRING,
    languageCode: 'en_IN',
    components: [{
      type: 'body',
      parameters: [
        { type: 'text', text: params.agencyName },
        { type: 'text', text: params.licenseType },
        { type: 'text', text: String(params.daysUntilExpiry) },
      ],
    }],
  });
}

// ── Monthly report to exec ────────────────────────────────────────────────────

export async function sendMonthlyStaffReport(params: {
  execPhones: string[];    // all exec committee members
  month: string;           // e.g. "April 2026"
  attendanceRatePct: number;
  taskCompletionRatePct: number;
  reportUrl: string;       // short portal URL
}): Promise<BulkResult[]> {
  const components = [{
    type: 'body' as const,
    parameters: [
      { type: 'text' as const, text: params.month },
      { type: 'text' as const, text: `${params.attendanceRatePct}` },
      { type: 'text' as const, text: `${params.taskCompletionRatePct}` },
      { type: 'text' as const, text: params.reportUrl },
    ],
  }];

  return sendWhatsAppBulk(
    WA_TEMPLATES.MONTHLY_STAFF_REPORT,
    params.execPhones.map(phone => ({ phone, langCode: 'en_IN', components })),
    'en_IN',
  );
}
