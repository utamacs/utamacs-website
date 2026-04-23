export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import Anthropic from '@anthropic-ai/sdk';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const apiKey = import.meta.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'AI insights not configured' }), {
        status: 503, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const [complaintsRes, assetsRes, duesRes] = await Promise.all([
      sb
        .from('complaints')
        .select('category, priority, status, created_at, sla_deadline, resolved_at')
        .eq('society_id', SOCIETY_ID)
        .gte('created_at', thirtyDaysAgo),
      sb
        .from('infrastructure_assets')
        .select('name, category, next_service_date, amc_end')
        .eq('society_id', SOCIETY_ID),
      sb
        .from('maintenance_dues')
        .select('status, total_amount, due_date')
        .eq('society_id', SOCIETY_ID)
        .in('status', ['pending', 'overdue', 'partially_paid']),
    ]);

    const complaints = complaintsRes.data ?? [];
    const assets = assetsRes.data ?? [];
    const dues = duesRes.data ?? [];
    const today = new Date().toISOString().slice(0, 10);

    // Aggregate complaint patterns (no PII)
    const categoryCount: Record<string, number> = {};
    const priorityCount: Record<string, number> = {};
    let slaBreaches = 0;
    for (const c of complaints) {
      categoryCount[c.category] = (categoryCount[c.category] ?? 0) + 1;
      priorityCount[c.priority] = (priorityCount[c.priority] ?? 0) + 1;
      if (c.sla_deadline && c.sla_deadline < today && !['Resolved', 'Closed'].includes(c.status)) {
        slaBreaches++;
      }
    }

    // Assets due for service in next 30 days
    const assetsDueSoon = assets.filter((a: any) => {
      if (!a.next_service_date) return false;
      const daysUntil = Math.ceil((new Date(a.next_service_date).getTime() - Date.now()) / 86400000);
      return daysUntil >= 0 && daysUntil <= 30;
    });

    const overdueAmount = dues
      .filter((d: any) => d.status === 'overdue')
      .reduce((sum: number, d: any) => sum + Number(d.total_amount), 0);

    const prompt = `You are an assistant for a residential cooperative society management committee in India.

Analyze the following operational data from the last 30 days and provide 3-5 concise, actionable insights.

COMPLAINT DATA (last 30 days, ${complaints.length} total):
- By category: ${JSON.stringify(categoryCount)}
- By priority: ${JSON.stringify(priorityCount)}
- SLA breaches: ${slaBreaches}

INFRASTRUCTURE ASSETS due for service in next 30 days:
${assetsDueSoon.map((a: any) => `- ${a.name} (${a.category}): service due ${a.next_service_date}`).join('\n') || 'None'}

FINANCE:
- Outstanding overdue dues: ₹${overdueAmount.toLocaleString('en-IN')}

Respond ONLY with a valid JSON array of objects. Each object must have:
- "type": one of "complaint_pattern", "maintenance_alert", "finance_alert", "general"
- "priority": one of "high", "medium", "low"
- "title": short headline (max 10 words)
- "body": 1-2 sentence insight or recommendation (no PII, no names)

Example format:
[{"type":"complaint_pattern","priority":"high","title":"Plumbing issues spiking","body":"Plumbing complaints are up 40% this month. Consider scheduling a preventive inspection of water lines."}]`;

    const client = new Anthropic({ apiKey });
    const message = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    });

    const rawText = message.content[0].type === 'text' ? message.content[0].text : '[]';

    let insights: unknown[];
    try {
      // Extract JSON array from response (model may wrap in markdown)
      const match = rawText.match(/\[[\s\S]*\]/);
      insights = match ? JSON.parse(match[0]) : [];
    } catch {
      insights = [];
    }

    return new Response(JSON.stringify({ insights, generated_at: new Date().toISOString() }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
