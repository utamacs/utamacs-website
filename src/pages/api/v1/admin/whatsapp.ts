export const prerender = false;

/**
 * GET  /api/v1/admin/whatsapp  — configuration status + template list
 * POST /api/v1/admin/whatsapp  — send a test message (admin only)
 */

import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sendWhatsApp, WA_TEMPLATES, type WaLangCode } from '@lib/services/providers/messaging/WhatsAppService';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// ── GET: WhatsApp configuration status ────────────────────────────────────────
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const configured = !!(
      import.meta.env.WHATSAPP_API_URL &&
      import.meta.env.WHATSAPP_ACCESS_TOKEN &&
      import.meta.env.WHATSAPP_PHONE_NUMBER_ID
    );

    const webhookConfigured = !!import.meta.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN;

    return Response.json({
      configured,
      webhookConfigured,
      mode: configured ? 'live' : 'stub',
      phoneNumberId: configured
        ? import.meta.env.WHATSAPP_PHONE_NUMBER_ID?.slice(0, 6) + '…'
        : null,
      templates: Object.entries(WA_TEMPLATES).map(([key, name]) => ({
        key,
        name,
        // Registration status is external (Meta + DLT) — admin verifies manually
        // This list is the single source of truth for what the system uses
      })),
      setupSteps: configured ? [] : [
        'Set WHATSAPP_API_URL (e.g. https://graph.facebook.com/v19.0)',
        'Set WHATSAPP_ACCESS_TOKEN (permanent System User token from Meta Business Manager)',
        'Set WHATSAPP_PHONE_NUMBER_ID (from Meta Developer Console → WhatsApp → API Setup)',
        'Set WHATSAPP_WEBHOOK_VERIFY_TOKEN (any random secret string you choose)',
        'Set WHATSAPP_BUSINESS_ACCOUNT_ID (WABA ID from Meta)',
        'Register webhook URL in Meta dashboard: https://portal.utamacs.org/api/webhooks/whatsapp',
        'Register each template on TRAI DLT portal, then submit to Meta for approval',
        'Enable feature flag: notifications → whatsapp_trai_dlt',
      ],
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// ── POST: Test send a WhatsApp message ────────────────────────────────────────
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json().catch(() => ({}));
    const { phone, templateKey, languageCode = 'en_IN', params = [] } = body as {
      phone: string;
      templateKey: keyof typeof WA_TEMPLATES;
      languageCode?: WaLangCode;
      params?: string[];
    };

    if (!phone || !templateKey) {
      return Response.json({ error: 'VALIDATION', message: 'phone and templateKey are required' }, { status: 400 });
    }

    if (!(templateKey in WA_TEMPLATES)) {
      return Response.json({ error: 'VALIDATION', message: `Unknown template key: ${templateKey}` }, { status: 400 });
    }

    // Basic E.164 validation
    if (!/^\+91\d{10}$/.test(phone)) {
      return Response.json({ error: 'VALIDATION', message: 'Phone must be in E.164 format: +91XXXXXXXXXX' }, { status: 400 });
    }

    const templateName = WA_TEMPLATES[templateKey];
    const components = params.length
      ? [{ type: 'body' as const, parameters: params.map(p => ({ type: 'text' as const, text: p })) }]
      : [];

    const result = await sendWhatsApp({
      to: phone,
      templateName,
      languageCode,
      components,
    });

    return Response.json({
      ...result,
      template: templateName,
      phone,
      note: result.status === 'stub'
        ? 'Running in stub mode — set WHATSAPP_API_URL, WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID to send real messages'
        : undefined,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
