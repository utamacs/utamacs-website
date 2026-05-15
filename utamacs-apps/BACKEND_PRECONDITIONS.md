# Mobile Pre-Conditions — Backend Changes Required

These changes to the existing Astro portal are **required before any native app ships**.
All are non-breaking additions — they do not affect the existing web portal.

---

## 1. Bearer Token Support in `resolveFromRequest()`

**File:** `src/lib/permissions.ts`
**Effort:** ~2 hours  
**Priority:** P0 (launch blocker)

The current implementation reads only `Set-Cookie` session cookies. Native mobile
apps cannot use `HttpOnly` cookies. Add `Authorization: Bearer <token>` header support.

```typescript
// Diff: src/lib/permissions.ts
// In the resolveFromRequest() function, add this BEFORE the cookie-based check:

export async function resolveFromRequest(request: Request, societyId: string) {
  // NEW: Try Authorization header first (mobile clients send Bearer token)
  const authHeader = request.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    return resolveFromBearerToken(token, societyId);
  }

  // EXISTING: Fall back to cookie (web clients)
  // ... existing cookie logic unchanged ...
}

// NEW helper function (add to permissions.ts):
async function resolveFromBearerToken(token: string, societyId: string) {
  const sb = createClient(
    process.env.PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
  const { data: { user }, error } = await sb.auth.getUser(token);
  if (error || !user) return null;
  return resolveUserPermissions(user.id, societyId, sb);
}
```

---

## 2. Permissions Endpoint

**File:** `src/pages/api/v1/members/me/permissions.ts` (new file)  
**Effort:** ~2 hours  
**Priority:** P0

Mobile apps fetch the full resolved permission set once after login and cache it.

```typescript
export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  const user = await resolveFromRequest(request, SOCIETY_ID);
  if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

  return Response.json({
    role: user.role,
    portalRole: user.portalRole,
    isAdmin: user.isAdmin,
    committeeTitle: user.committeeTitle ?? null,
    unitId: user.unitId ?? null,
    features: Array.from(user.permissions),  // string[]
  });
};
```

---

## 3. Mobile Home BFF Endpoint

**File:** `src/pages/api/v1/mobile/home.ts` (new file)  
**Effort:** ~4 hours  
**Priority:** P0

Aggregates 5 separate API calls into 1 for fast home screen load.

```typescript
export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { createSupabaseServerClient } from '@lib/supabase/server';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = createSupabaseServerClient();

    // All queries run in parallel
    const [dues, openComplaints, recentNotices, upcomingEvents, pendingGateRequests, unreadNotifications] =
      await Promise.all([
        // Dues: current period status for the member's unit
        sb.from('dues')
          .select('amount, due_date, status, billing_period:billing_periods(name)')
          .eq('society_id', SOCIETY_ID)
          .eq('unit_id', user.unitId!)
          .eq('status', 'pending')
          .order('due_date', { ascending: true })
          .limit(1)
          .single(),

        // Open complaints count
        sb.from('complaints')
          .select('id', { count: 'exact', head: true })
          .eq('society_id', SOCIETY_ID)
          .eq('submitted_by', user.id)
          .in('status', ['open', 'in_progress']),

        // Recent notices (last 3)
        sb.from('notices')
          .select('id, title, published_at, is_urgent')
          .eq('society_id', SOCIETY_ID)
          .eq('status', 'published')
          .order('published_at', { ascending: false })
          .limit(3),

        // Upcoming events (next 2)
        sb.from('events')
          .select('id, title, starts_at, location')
          .eq('society_id', SOCIETY_ID)
          .gte('starts_at', new Date().toISOString())
          .order('starts_at', { ascending: true })
          .limit(2),

        // Pending gate requests for this unit (guard/member view)
        user.unitId
          ? sb.from('visitor_gate_requests')
            .select('id, visitor_name, requested_at, expires_at')
            .eq('society_id', SOCIETY_ID)
            .eq('unit_id', user.unitId)
            .eq('status', 'pending')
            .order('requested_at', { ascending: false })
            .limit(3)
          : Promise.resolve({ data: [], error: null }),

        // Unread notification count
        sb.from('notification_logs')
          .select('id', { count: 'exact', head: true })
          .eq('society_id', SOCIETY_ID)
          .eq('profile_id', user.id)
          .eq('is_read', false),
      ]);

    return Response.json({
      dues_summary: dues.data ?? null,
      open_complaints: openComplaints.count ?? 0,
      recent_notices: recentNotices.data ?? [],
      upcoming_events: upcomingEvents.data ?? [],
      pending_gate_requests: pendingGateRequests.data ?? [],
      unread_notifications: unreadNotifications.count ?? 0,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
```

---

## 4. Push Token Registration

**Migration:** Next sequential migration after migration 089

```sql
CREATE TABLE device_push_tokens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  profile_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token         text NOT NULL,
  platform      text NOT NULL CHECK (platform IN ('expo', 'fcm', 'apns')),
  app_version   text,
  os_version    text,
  device_model  text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (profile_id, token)
);

ALTER TABLE device_push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_own_tokens" ON device_push_tokens
  FOR ALL USING (profile_id = auth.uid());
```

**New route:** `src/pages/api/v1/notifications/push/register.ts`

```typescript
export const POST: APIRoute = async ({ request }) => {
  const user = await resolveFromRequest(request, SOCIETY_ID);
  if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

  const { token, platform, app_version, os_version, device_model } = await request.json();
  if (!token || !platform) return Response.json({ error: 'VALIDATION', message: 'token and platform required' }, { status: 400 });

  const sb = createSupabaseServerClient();
  await sb.from('device_push_tokens').upsert({
    society_id: SOCIETY_ID,
    profile_id: user.id,
    token, platform, app_version, os_version, device_model,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'profile_id,token' });

  return Response.json({ ok: true });
};
```

---

## 5. Gate Approval Push Dispatch

**File:** `src/pages/api/v1/visitors/gate-requests.ts` (existing — add after insert)

After inserting the gate request, dispatch push notification to the unit's residents:

```typescript
// Add to POST handler, after successful insert:
import { sendPushNotification } from '@lib/notifications';

// Fetch push tokens for the unit's residents
const { data: tokens } = await sb
  .from('device_push_tokens')
  .select('token, platform')
  .in('profile_id', 
    sb.from('profiles').select('id').eq('unit_id', validatedUnitId).eq('society_id', SOCIETY_ID)
  );

if (tokens && tokens.length > 0) {
  await sendPushNotification(tokens, {
    title: '🚪 Gate Approval Request',
    body: `${visitorName} is at the gate. Tap to approve or reject.`,
    data: { 
      type: 'gate_request', 
      gate_request_id: newRequest.id,
      expires_at: newRequest.expires_at,
    },
    priority: 'high',
  });
}
```

---

## 6. Feature Flag Platform Column

```sql
ALTER TABLE feature_flags 
  ADD COLUMN IF NOT EXISTS platform text NOT NULL DEFAULT 'all' 
  CHECK (platform IN ('all', 'web', 'android', 'ios'));

COMMENT ON COLUMN feature_flags.platform IS 'Platform scope for this flag. all = web + native apps.';
```

This allows rolling out modules to web before mobile (or vice versa).
The mobile app includes `?platform=android` or `?platform=ios` in the feature flags fetch.
