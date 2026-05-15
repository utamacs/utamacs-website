/**
 * Branded HTML email templates for UTA MACS notifications.
 * All templates produce self-contained HTML safe for Resend / any SMTP relay.
 */

const BRAND_PRIMARY = '#1E3A8A';
const BRAND_GREEN   = '#10B981';
const BRAND_AMBER   = '#F59E0B';
const BRAND_GRAY    = '#4B5563';

const TYPE_META: Record<string, { colour: string; icon: string; label: string }> = {
  complaint:      { colour: '#F97316', icon: '🔧', label: 'Complaint' },
  notice:         { colour: '#8B5CF6', icon: '📢', label: 'Notice' },
  event:          { colour: '#3B82F6', icon: '📅', label: 'Event' },
  poll:           { colour: '#14B8A6', icon: '📊', label: 'Poll' },
  payment:        { colour: BRAND_GREEN, icon: '₹',  label: 'Payment' },
  visitor:        { colour: '#6366F1', icon: '🚪', label: 'Visitor Alert' },
  facility:       { colour: '#EC4899', icon: '🏢', label: 'Facility Booking' },
  community:      { colour: '#06B6D4', icon: '💬', label: 'Community' },
  marketplace:    { colour: '#F59E0B', icon: '🛒', label: 'Marketplace' },
  security_alert: { colour: '#EF4444', icon: '🚨', label: 'Security Alert' },
  system:         { colour: BRAND_GRAY, icon: '⚙️', label: 'System' },
  feedback:       { colour: '#EAB308', icon: '⭐', label: 'Feedback' },
  snags:          { colour: '#78716C', icon: '🔨', label: 'Snag Update' },
};

function baseLayout(content: string, previewText: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>UTA MACS Notification</title>
  <!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
</head>
<body style="margin:0;padding:0;background-color:#F8FAFC;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <span style="display:none;overflow:hidden;max-height:0;mso-hide:all;">${escapeHtml(previewText)}</span>

  <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background-color:#F8FAFC;">
    <tr><td align="center" style="padding:24px 16px;">

      <table width="600" cellpadding="0" cellspacing="0" role="presentation" style="max-width:600px;width:100%;">

        <!-- Header -->
        <tr>
          <td style="background-color:${BRAND_PRIMARY};border-radius:12px 12px 0 0;padding:20px 28px;">
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td>
                  <span style="color:#ffffff;font-size:18px;font-weight:700;letter-spacing:-0.3px;">UTA MACS</span>
                  <span style="color:#93C5FD;font-size:12px;display:block;margin-top:2px;">Urban Trilla Apartment Owners</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="background-color:#ffffff;padding:28px;border-left:1px solid #E5E7EB;border-right:1px solid #E5E7EB;">
            ${content}
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background-color:#F8FAFC;border:1px solid #E5E7EB;border-top:none;border-radius:0 0 12px 12px;padding:16px 28px;">
            <p style="margin:0;font-size:11px;color:#9CA3AF;text-align:center;line-height:1.5;">
              You're receiving this because you're a registered member of UTA MACS.
              <br/>To manage your notification preferences, visit the
              <a href="https://portal.utamacs.org/portal/notifications" style="color:${BRAND_PRIMARY};text-decoration:underline;">portal notifications page</a>.
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

export interface EmailRenderOptions {
  type: string;
  title: string;
  body: string;
  ctaUrl?: string;
  ctaLabel?: string;
  societyName?: string;
}

/** Render a single notification as a branded transactional email. */
export function renderNotificationEmail(opts: EmailRenderOptions): { subject: string; html: string } {
  const meta = TYPE_META[opts.type] ?? TYPE_META.system;
  const subject = `${meta.icon} ${opts.title} — UTA MACS`;

  const content = `
    <table width="100%" cellpadding="0" cellspacing="0" role="presentation">
      <!-- Type badge -->
      <tr>
        <td style="padding-bottom:16px;">
          <span style="display:inline-block;background-color:${meta.colour}1A;color:${meta.colour};
                       font-size:11px;font-weight:600;letter-spacing:0.5px;text-transform:uppercase;
                       padding:4px 10px;border-radius:100px;">
            ${meta.icon} ${meta.label}
          </span>
        </td>
      </tr>
      <!-- Title -->
      <tr>
        <td style="padding-bottom:10px;">
          <h1 style="margin:0;font-size:20px;font-weight:700;color:#111827;line-height:1.3;">${escapeHtml(opts.title)}</h1>
        </td>
      </tr>
      <!-- Body -->
      <tr>
        <td style="padding-bottom:${opts.ctaUrl ? '24px' : '8px'};">
          <p style="margin:0;font-size:15px;color:#374151;line-height:1.6;">${escapeHtml(opts.body)}</p>
        </td>
      </tr>
      ${opts.ctaUrl ? `
      <!-- CTA -->
      <tr>
        <td>
          <a href="${escapeHtml(opts.ctaUrl)}"
             style="display:inline-block;background-color:${BRAND_PRIMARY};color:#ffffff;
                    font-size:14px;font-weight:600;text-decoration:none;padding:12px 24px;
                    border-radius:8px;">
            ${escapeHtml(opts.ctaLabel ?? 'View Details')} →
          </a>
        </td>
      </tr>` : ''}
    </table>
  `;

  return { subject, html: baseLayout(content, opts.body.slice(0, 150)) };
}

export interface DigestNotification {
  title: string;
  body: string;
  type: string;
  created_at: string;
  reference_id?: string | null;
}

/** Render a daily digest of unread notifications. */
export function renderDigestEmail(
  notifications: DigestNotification[],
  societyName = 'UTA MACS',
): { subject: string; html: string } {
  const count = notifications.length;
  const subject = `${count} unread notification${count !== 1 ? 's' : ''} — UTA MACS Daily Digest`;

  const rows = notifications.slice(0, 20).map(n => {
    const meta  = TYPE_META[n.type] ?? TYPE_META.system;
    const when  = new Date(n.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
    return `
      <tr>
        <td style="padding:12px 0;border-bottom:1px solid #F3F4F6;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td width="32" valign="top" style="padding-right:12px;">
                <div style="width:32px;height:32px;border-radius:50%;background-color:${meta.colour}1A;
                             text-align:center;line-height:32px;font-size:14px;">${meta.icon}</div>
              </td>
              <td valign="top">
                <p style="margin:0 0 2px;font-size:13px;font-weight:600;color:#111827;">${escapeHtml(n.title)}</p>
                <p style="margin:0 0 4px;font-size:12px;color:#6B7280;line-height:1.4;">${escapeHtml(n.body.slice(0, 120))}${n.body.length > 120 ? '…' : ''}</p>
                <p style="margin:0;font-size:11px;color:#9CA3AF;">${when}</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    `;
  }).join('');

  const overflow = count > 20
    ? `<tr><td style="padding:10px 0;text-align:center;"><span style="font-size:12px;color:#6B7280;">…and ${count - 20} more notifications</span></td></tr>`
    : '';

  const content = `
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td style="padding-bottom:20px;">
          <h1 style="margin:0 0 4px;font-size:20px;font-weight:700;color:#111827;">Your Daily Digest</h1>
          <p style="margin:0;font-size:14px;color:#6B7280;">
            You have <strong>${count}</strong> unread notification${count !== 1 ? 's' : ''} in the portal.
          </p>
        </td>
      </tr>
      <tr>
        <td>
          <table width="100%" cellpadding="0" cellspacing="0">
            ${rows}
            ${overflow}
          </table>
        </td>
      </tr>
      <tr>
        <td style="padding-top:20px;">
          <a href="https://portal.utamacs.org/portal/notifications"
             style="display:inline-block;background-color:${BRAND_PRIMARY};color:#ffffff;
                    font-size:14px;font-weight:600;text-decoration:none;padding:12px 24px;
                    border-radius:8px;">
            View all in portal →
          </a>
        </td>
      </tr>
    </table>
  `;

  return { subject, html: baseLayout(content, `You have ${count} unread notification${count !== 1 ? 's' : ''} in UTA MACS portal.`) };
}
