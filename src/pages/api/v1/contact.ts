export const prerender = false;
import type { APIRoute } from 'astro';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': 'https://utamacs.org',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export const OPTIONS: APIRoute = async () =>
  new Response(null, { status: 204, headers: CORS_HEADERS });

export const POST: APIRoute = async ({ request }) => {
  const json = await request.json() as {
    name?: string; email?: string; flat?: string; subject?: string; message?: string;
  };
  const { name, email, flat, subject, message } = json;

  if (!name || !email || !subject || !message) {
    return new Response(JSON.stringify({ error: 'All required fields must be filled.' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
    });
  }

  const resendKey = process.env.RESEND_API_KEY ?? import.meta.env.RESEND_API_KEY;

  if (resendKey) {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: 'no-reply@utamacs.org',
        to: ['management@utamacs.org'],
        reply_to: email,
        subject: `[Contact Form] ${subject} — ${name}`,
        text: [
          `Name: ${name}`,
          flat ? `Flat: ${flat}` : '',
          `Email: ${email}`,
          `Subject: ${subject}`,
          '',
          'Message:',
          message,
        ].filter(Boolean).join('\n'),
      }),
    });

    if (!res.ok) {
      console.error('[contact] Resend error:', await res.text());
      return new Response(JSON.stringify({ error: 'Failed to send message. Please try again.' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
      });
    }
  } else {
    // Log when Resend key is not configured
    console.log('[contact] No RESEND_API_KEY — message from:', email, '|', subject);
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
};
