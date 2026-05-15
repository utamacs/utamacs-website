# UTA MACS — Enterprise SaaS Platform Architecture
## Revised Design v2.0 — Incorporating All Critical Review Findings

**Classification:** Architecture Decision Record — Engineering Leadership  
**Date:** 2026-05-11  
**Status:** Proposed — Pending Engineering Council Approval  
**Supersedes:** MOBILE_ARCHITECTURE.md v1.0  
**Addresses:** All 10 Critical Findings + 7 Missing Concerns from CRITICAL_REVIEW.md

---

## DESIGN PRINCIPLES (NON-NEGOTIABLE)

These 12 principles govern every decision in this document. Any proposal that violates them requires a formal architecture exception.

| # | Principle | Implication |
|---|---|---|
| 1 | **Security is not a feature, it is the foundation** | Every data path is authenticated, authorized, encrypted, and audited — no exceptions |
| 2 | **Offline resilience for safety-critical paths** | Gate verification works with zero network connectivity |
| 3 | **Data residency by design** | All PII, KYC, and financial data stored in India (Azure Central India) |
| 4 | **Tenant isolation by architecture** | No code path can access another tenant's data — enforced at DB, network, and API layers simultaneously |
| 5 | **Cost attribution is mandatory** | Every Azure resource is tagged with `tenant_id`, `environment`, `service`, `cost_center` |
| 6 | **Observability before deployment** | No service ships without structured logs, metrics, and traces instrumented |
| 7 | **IaaC or it does not exist** | No manual cloud resource creation; all infrastructure lives in Terraform |
| 8 | **Optimize at every layer** | Unnecessary compute, bandwidth, storage, and latency are treated as bugs |
| 9 | **AI-assisted, human-approved** | AI reviews every code change; a human approves before merge |
| 10 | **Consistent design across all surfaces** | One design system, one motion language, every platform — no exceptions |
| 11 | **Governance is automated** | Approvals, audit trails, and compliance checks are enforced by tooling, not process |
| 12 | **Measure everything that matters** | If it cannot be measured, it cannot be managed or improved |

---

## PART 1 — PLATFORM STRATEGY

### 1.1 Framework Decision: Flutter Everywhere

**Final decision: Flutter (Dart) for iOS, Android, macOS, Windows, Linux, and Web.**

This directly corrects Critical Finding #1 from the review. The justification is final and not revisitable unless a specific Flutter limitation is demonstrated through a working prototype:

| Platform | Technology | Build Target | Distribution |
|---|---|---|---|
| iOS | Flutter | ARM64 native (Impeller) | App Store + Enterprise MDM |
| Android | Flutter | ARM64 + ARM32 native (Impeller) | Play Store + Enterprise MDM |
| macOS | Flutter | ARM64 + x86_64 native | Mac App Store + direct DMG |
| Windows | Flutter | x86_64 native | Microsoft Store + MSI |
| Linux | Flutter | x86_64 native | Snap + AppImage |
| Web | Flutter Web (WASM) | WebAssembly | Azure Static Web Apps |
| Admin Portal | Next.js 14 (App Router) | SSR | Azure Static Web Apps |

**Why Flutter Web (WASM) for the resident portal:**
Flutter Web's Skia/Canvaskit renderer was slow. The WASM compilation target (stable in Flutter 3.22+) compiles Dart to WebAssembly, runs at near-native speed in the browser, and eliminates the JavaScript bridge entirely. For a portal used by authenticated residents (not public-facing, no SEO requirement), Flutter Web WASM is appropriate.

**Why Next.js for the Super-Admin Portal only:**
The system-admin portal (society onboarding, subscription management, global config) is used by a small internal team and benefits from SSR, rapid iteration, and rich data table libraries. It does not need Flutter's rendering pipeline.

**Shared code across all Flutter targets:**
```
dart_core/               ← Pure Dart business logic, 100% shared
  lib/
    domain/              ← Entities, value objects, domain events
    repositories/        ← Abstract interfaces
    usecases/            ← All business rules
    services/            ← Cross-cutting: auth, analytics, config
    utils/               ← Formatters, validators, crypto

flutter_shared/          ← Flutter-specific shared UI, 80% shared
  lib/
    design/              ← Tokens, themes, typography, motion
    widgets/             ← All UI components (platform-adaptive)
    navigation/          ← GoRouter routes, deep linking
    l10n/                ← Internationalization (en, te, hi)
```

Platform-specific code (the remaining 20%):
- iOS: Share extensions, Siri Shortcuts, Apple Wallet pass generation
- Android: Home screen widgets, predictive back gesture, Dynamic Color (Material You)
- macOS/Windows: Menu bar, system tray, file drag-and-drop
- Web: URL bar sync, browser history management, browser notifications

### 1.2 Application Topology

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                         USER-FACING APPLICATIONS                                │
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  iOS App     │  │ Android App  │  │  Desktop App │  │  Web App (WASM)  │  │
│  │  (Flutter)   │  │  (Flutter)   │  │  (Flutter)   │  │  (Flutter Web)   │  │
│  │  App Store   │  │  Play Store  │  │  Win/Mac/Lin │  │  portal.utamacs  │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         └─────────────────┴─────────────────┴──────────────────┘             │
│                                    │ HTTPS + TLS 1.3                          │
└────────────────────────────────────┼────────────────────────────────────────────┘
                                     │
┌────────────────────────────────────▼────────────────────────────────────────────┐
│                         CLOUDFLARE EDGE LAYER                                   │
│                                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │  WAF + DDoS     │  │  Bot Management │  │  Rate Limiting  │                │
│  │  Protection     │  │  (device-aware) │  │  (per device_id)│                │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘                │
│           └───────────────────┬┘                    │                          │
│                               │                     │                          │
│  ┌────────────────────────────▼─────────────────────▼──────────────────────┐   │
│  │                    Cloudflare Workers (API Gateway)                      │   │
│  │  Auth validation · Request routing · Tenant resolution · Cache hits     │   │
│  └────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  R2 Storage  │  │  CF Images   │  │  CF KV       │  │  CF D1           │  │
│  │  (documents) │  │  (transform) │  │  (feature    │  │  (edge cache     │  │
│  │              │  │              │  │   flags)     │  │   metadata)      │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────────┘  │
└────────────────────────────────────┬────────────────────────────────────────────┘
                                     │ Private tunnel / mTLS
┌────────────────────────────────────▼────────────────────────────────────────────┐
│                         AZURE CLOUD (Central India — pune)                      │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  Azure Kubernetes Service (AKS) — System Node Pool + User Node Pools    │   │
│  │                                                                          │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐               │   │
│  │  │  API Service  │  │ Worker Service│  │  Notification │               │   │
│  │  │  (Fastify +   │  │ (Event proc,  │  │  Service      │               │   │
│  │  │   GraphQL)    │  │  background   │  │  (FCM+APNs)   │               │   │
│  │  │  3–10 pods    │  │  jobs)        │  │               │               │   │
│  │  └───────────────┘  └───────────────┘  └───────────────┘               │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Azure PG    │  │  Azure Redis │  │  Service Bus │  │  Azure Key Vault │  │
│  │  Flexible    │  │  (HA)        │  │  (Premium)   │  │  (HSM-backed)    │  │
│  │  (Zone HA)   │  │              │  │              │  │                  │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────────┘  │
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Azure Notif │  │  Azure       │  │  Azure       │  │  Azure SignalR   │  │
│  │  Hubs        │  │  Monitor +   │  │  Entra ID B2C│  │  Service         │  │
│  │  (push uni.) │  │  App Insights│  │  (auth)      │  │  (realtime)      │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## PART 2 — MULTI-TENANT SAAS ARCHITECTURE

### 2.1 Tenant Isolation Model

Tenant isolation is enforced at **four independent layers**. A failure in any one layer does not expose tenant data — the other three prevent it. This is defense-in-depth for data isolation.

**Layer 1 — Network:** Each tenant's traffic flows through Cloudflare Workers that resolve `tenant_id` from the JWT and attach it to every downstream request header. API services never receive a request without a verified `tenant_id`.

**Layer 2 — API:** Every API resolver validates `tenant_id` from the verified JWT matches the resource being accessed. A bug that skips Layer 1 hits this check.

**Layer 3 — Database:** Row Level Security policies enforce `tenant_id` match on every table. A bug in the API that skips Layer 2 hits RLS.

**Layer 4 — Audit:** Every database read that touches tenant data is logged to `domain_events` with `tenant_id`. A violation in layers 1–3 is detectable in the audit log.

### 2.2 Database Tier Strategy (Pooled → Siloed)

| Tier | Plan | DB Strategy | Tenant Profile |
|---|---|---|---|
| **Starter** | Shared DB, schema isolation | Single Azure PostgreSQL Flexible, one schema per tenant | < 200 residents, < 50 units |
| **Professional** | Dedicated compute, shared server | Dedicated connection pool via PgBouncer, dedicated schema | 200–1000 residents |
| **Enterprise** | Dedicated server | Dedicated Azure PostgreSQL Flexible instance, own VNET | 1000+ residents, custom SLA |

```
Azure PostgreSQL Flexible Server (Starter/Pro shared)
  ├── schema: tenant_a01 (housing society A)
  │     └── all tables with tenant_id = 'a01'
  ├── schema: tenant_b02 (housing society B)
  └── schema: tenant_c03 (housing society C)

Azure PostgreSQL Flexible Server (Enterprise dedicated)
  └── schema: public (housing society D — Enterprise)
        └── all tables, dedicated instance, VNET peered
```

**Schema provisioning is fully automated:**
```
POST /api/v1/admin/tenants (super-admin only)
→ Creates tenant record
→ Publishes TenantProvisioningRequestedEvent to Service Bus
→ Worker: creates schema, runs migrations, seeds feature flags, creates default rules
→ Worker: provisions Cloudflare KV entry for tenant domain routing
→ Worker: provisions Entra ID B2C application for tenant
→ Publishes TenantProvisionedEvent
→ Sends welcome email to society admin
Total time: < 90 seconds for Starter; < 5 minutes for Enterprise (new DB instance)
```

### 2.3 Tenant Resolution at the Edge

Every request to `api.utamacs.org` goes through a Cloudflare Worker that resolves the tenant:

```javascript
// cloudflare-workers/src/gateway.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Resolution strategies (in priority order):
    // 1. Subdomain: tenant-slug.portal.utamacs.org
    // 2. Custom domain: portal.mysociety.com (mapped in KV)
    // 3. X-Tenant-ID header (for native apps with known tenant)
    // 4. JWT claim: tenant_id in the access token

    const tenantId = await resolveTenantId(request, env);
    if (!tenantId) return new Response('Tenant not found', { status: 404 });

    // Validate tenant is active and plan allows this endpoint
    const tenant = await env.TENANT_KV.get(`tenant:${tenantId}`, 'json');
    if (!tenant || tenant.status !== 'active') {
      return new Response('Subscription inactive', { status: 402 });
    }

    // Rate limit per device_id (authenticated) or IP (unauthenticated)
    const rateLimitKey = extractDeviceId(request) ?? request.headers.get('CF-Connecting-IP');
    const { success } = await env.RATE_LIMITER.limit({ key: `${tenantId}:${rateLimitKey}` });
    if (!success) return new Response('Rate limited', { status: 429 });

    // Forward to AKS with tenant context injected
    const upstream = new Request(request);
    upstream.headers.set('X-Tenant-ID', tenantId);
    upstream.headers.set('X-Tenant-Plan', tenant.plan);
    upstream.headers.set('X-CF-Ray', request.headers.get('CF-Ray') ?? '');
    return fetch(upstream);
  }
}
```

### 2.4 Subscription & Licensing Model

**Tiers:**

| Feature | Starter (₹2,999/mo) | Professional (₹7,999/mo) | Enterprise (Custom) |
|---|---|---|---|
| Max residential units | 100 | 500 | Unlimited |
| Modules | Core 12 | All 28 | All + custom |
| Storage (Cloudflare R2) | 10 GB | 100 GB | Custom |
| Push notifications | 10,000/mo | 100,000/mo | Unlimited |
| API calls | 100,000/mo | 1,000,000/mo | Unlimited |
| Support | Email (48h) | Priority (8h) | Dedicated CSM |
| SLA | 99.5% | 99.9% | 99.99% |
| Data residency | India | India | India + custom region |
| Dedicated DB | ❌ | ❌ | ✅ |
| Custom domain | ❌ | ✅ | ✅ |
| SSO (Entra/Okta) | ❌ | ❌ | ✅ |
| Audit export | 30 days | 1 year | Unlimited |

**Billing infrastructure:**
- **Stripe** for payment processing (Stripe India, supports UPI, net banking, cards)
- **Stripe Billing** for recurring subscriptions and usage-based components
- Usage metering: API calls, storage bytes, push notifications → reported daily to Stripe via Azure Function
- Tenant `subscription_status` cached in Cloudflare KV — checked on every request at edge (no DB hit)
- Subscription events (payment failed, plan upgraded, trial expired) → Azure Service Bus → all relevant services

**Trial model:**
- 30-day full Professional trial
- No credit card required for Starter trial
- Trial expiry: app shows "upgrade required" banner 7 days before; data preserved for 30 days post-expiry

---

## PART 3 — SECURITY ARCHITECTURE (NO COMPROMISE)

Every item from Critical Finding #3 in the review is addressed here.

### 3.1 Zero-Trust Network Architecture

```
Internet
  → Cloudflare (WAF, DDoS, Bot, TLS termination)
  → Cloudflare Tunnel (encrypted, no public IP for AKS)
  → AKS Ingress (NGINX, internal only)
  → API Service (mutual TLS to PostgreSQL)
  → Azure PostgreSQL (Private Endpoint, no public internet access)
  → Azure Key Vault (Private Endpoint, RBAC, no access key)
```

**No Azure resource has a public IP.** All traffic flows through Cloudflare Tunnel. This eliminates the entire class of "bypass the API gateway and hit the origin directly" attacks.

### 3.2 Authentication Architecture — Corrected

**Identity Provider:** Azure Entra External ID (formerly Azure AD B2C) — replaces Supabase Auth.

**Why Entra External ID:**
- Native multi-tenant with tenant isolation built into the identity layer
- Supports: email/password, OTP (SMS), FIDO2/WebAuthn (passkeys), SAML, OIDC (for Enterprise SSO)
- Conditional Access policies: require MFA for executives, block sign-in from rooted devices
- Token rotation: single-use refresh tokens enforced natively
- Token revocation: device-level revocation via Continuous Access Evaluation (CAE)

**Token design (addresses all token lifecycle gaps from the review):**

```
Access Token (JWT, 15-minute lifetime):
  iss: https://utamacs.b2clogin.com/...
  aud: api.utamacs.org
  sub: <user-uuid>
  tenant_id: <society-uuid>
  device_id: <device-uuid-from-secure-store>
  portal_role: member | executive | secretary | president
  is_admin: false
  plan: starter | professional | enterprise
  jti: <unique-token-id>           ← for revocation
  exp: now + 15 minutes

Refresh Token:
  - Single-use rotation (each use issues new refresh token)
  - 90-day lifetime (reset on every use)
  - Stored in SecureStore / Keychain only
  - Server-side revocation list in Azure Cache for Redis (O(1) lookup)
  - Revoked on: logout, password change, suspicious activity, device reported stolen
```

**Session management (missing from original):**
```
GET /api/v1/auth/sessions
→ Lists all active devices with: device_model, platform, last_seen, location
→ Resident can revoke any session from their profile screen
→ Revocation writes jti to Redis revocation list (TTL = token expiry)
→ All subsequent requests with that jti → 401 even if token is not expired
```

### 3.3 Step-Up Authentication (Critical Finding #3b — Corrected)

For operations that change physical state or access PII, a re-authentication challenge is required regardless of when the user last logged in.

**Step-up trigger matrix:**

| Operation | Step-Up Method | Timeout |
|---|---|---|
| Gate approval (approve) | Biometric | Per-action (no timeout) |
| Payment recording | Biometric | 5-minute window |
| View KYC documents (Aadhaar/PAN) | Biometric | Per-session |
| Change member role | Biometric + confirmation PIN | Per-action |
| Export member data | Biometric | Per-action |
| Delete community post (exec) | Biometric | Per-action |
| View full phone number | Biometric | 60-second window |

**Flutter implementation:**
```dart
// dart_core/lib/services/step_up_auth_service.dart
class StepUpAuthService {
  final LocalAuthService _localAuth;
  final SecureStorageService _secureStorage;

  Future<StepUpResult> require(StepUpReason reason) async {
    final available = await _localAuth.isAvailable();
    if (!available) {
      // Fallback: require PIN entry (PIN stored as PBKDF2 hash in SecureStore)
      return _requirePin(reason);
    }

    final result = await _localAuth.authenticate(
      localizedReason: _reasonString(reason),
      options: const AuthenticationOptions(
        biometricOnly: false,  // allow PIN as fallback
        stickyAuth: true,
      ),
    );

    if (!result) return StepUpResult.denied;

    // Issue a short-lived step-up token (server-signed, 5-minute TTL)
    // This token is sent alongside the API call to prove step-up was completed
    return _issueStepUpToken(reason);
  }
}
```

The step-up token is verified server-side on the sensitive endpoint. No server-side change accepts a sensitive operation without a valid step-up token.

### 3.4 Cryptographically Self-Verifying QR Passes (Critical Finding #8 — Corrected)

This is the most important security fix. Gate verification must work with zero network connectivity.

**Pass structure (HMAC-SHA256 signed, offline-verifiable):**

```dart
// dart_core/lib/domain/visitor_pass.dart
class VisitorPass {
  final String passId;          // UUID
  final String tenantId;        // Society UUID
  final String unitId;          // Unit UUID
  final String visitorName;     // String
  final int validFromEpoch;     // Unix timestamp (seconds)
  final int validUntilEpoch;    // Unix timestamp (seconds)
  final String passType;        // 'otp' | 'qr' | 'pre_approved'
  final String signature;       // HMAC-SHA256 of all above fields

  // Canonical string for signing (field order MUST be stable)
  String get _signingInput =>
    '$passId:$tenantId:$unitId:$validFromEpoch:$validUntilEpoch:$passType';

  // Offline verification — no network required
  bool verifySignature(String societyHmacKey) {
    final mac = Hmac(sha256, utf8.encode(societyHmacKey));
    final expectedSig = base64Url.encode(mac.convert(utf8.encode(_signingInput)).bytes);
    return constantTimeEquals(signature, expectedSig);
  }

  bool get isExpired => DateTime.now().millisecondsSinceEpoch / 1000 > validUntilEpoch;
  bool get isActive => !isExpired && DateTime.now().millisecondsSinceEpoch / 1000 >= validFromEpoch;
}
```

**societyHmacKey** is a 256-bit random key generated per tenant at provisioning time, stored in Azure Key Vault, and delivered to the guard app during login (stored in device SecureStore, refreshed daily). It never appears in QR code payloads — only the signature does.

**QR payload (compact, scannable at 200x200px):**
```
UTAMACS:v1:<base64url(passId)>:<base64url(tenantId)>:<unitId[last8]>:<validUntil>:<sig[first16]>
```

**Guard app verification flow (offline):**
```
1. Scan QR → parse payload
2. Verify signature using locally cached societyHmacKey (SecureStore)
3. Check validUntil > now (device clock, ±5 minute tolerance)
4. Check pass is not in local revocation list (refreshed every 5 min when online, cached offline)
5. Show VALID (green) / EXPIRED (amber) / INVALID (red)
6. Log entry locally → sync to server when network available
```

**Revocation list delivery:** A compact bloom filter of revoked pass IDs is pushed to all guard devices via Azure SignalR every 5 minutes. A bloom filter for 10,000 revoked passes fits in ~15KB — negligible bandwidth.

### 3.5 App Attestation Integrated into Auth Flow (Critical Finding #3c)

```
Login flow (Flutter Android):
  1. User submits credentials
  2. App requests Play Integrity token from Google Play
  3. POST /api/v1/auth/login { ...credentials, integrity_token: "..." }
  4. Server verifies integrity token with Google Play Integrity API
  5. Server validates: MEETS_DEVICE_INTEGRITY + MEETS_APP_INTEGRITY
  6. If valid: issue access + refresh tokens
  7. If invalid: return 403 with reason code (ROOTED_DEVICE, TAMPERED_APP, EMULATOR)

Gate approval flow (additional attestation):
  For every gate approval POST:
  - Include fresh integrity token (max 1 minute old)
  - Server rejects stale tokens even for authenticated sessions
```

iOS equivalent: Apple AppAttest / DeviceCheck, same flow.

### 3.6 Certificate Pinning — Corrected (Critical Finding #3e)

Pin the **Intermediate CA**, not the leaf:

```dart
// flutter_shared/lib/network/tls_config.dart
// Pin DigiCert Global Root G2 (Cloudflare's intermediate CA)
// and Baltimore CyberTrust Root (Azure's intermediate CA)
// These rotate every 2–5 years, not every 90 days like leaf certs.

const pinnedCertHashes = [
  // Cloudflare intermediate: DigiCert SHA2 Secure Server CA
  'sha256/5kJvNEMw0KjrCAu7eXY5HZdvyCS13BbA0VJG1RSP91w=',
  // Azure intermediate: Microsoft RSA TLS CA 02
  'sha256/qylGqV7MJTGsFRaRFRfTY7TuEUFgUpChOQyJfOBRSAo=',
  // Backup pin (MUST always have two in case of rotation)
  'sha256/++MBgDH5WGvL9Bcn5Be30cRcL0f5O+NyoXuWtQdX1aI=',
];

// Pin rotation procedure:
// 1. Google/Apple publish new intermediate CA → update backup pin
// 2. Ship OTA update with new backup pin (30 days before old primary expires)
// 3. After 30 days: promote backup to primary, remove old
// 4. Never have fewer than 2 pins active simultaneously
```

### 3.7 Data Encryption Architecture

```
At-rest encryption:
  - Azure PostgreSQL: ADE (Azure Disk Encryption) + TDE (Transparent Data Encryption)
  - Azure Blob / Cloudflare R2: AES-256 server-side encryption
  - SQLite (device): SQLCipher with key = PBKDF2(user_pin + device_salt, 100_000 iterations)
  - Aadhaar numbers: Application-layer AES-256-GCM with key from Azure Key Vault
  - Key rotation: Key Vault supports versioned keys; old data re-encrypted in background job

In-transit encryption:
  - All external traffic: TLS 1.3 minimum (enforced at Cloudflare WAF)
  - Internal AKS: mTLS via Istio service mesh (pod-to-pod encryption)
  - AKS → Azure PostgreSQL: TLS with certificate verification
  - AKS → Azure Key Vault: HTTPS over Private Endpoint (no internet path)

Key Management:
  - Azure Key Vault HSM (Hardware Security Module) for HMAC keys, AES keys, signing keys
  - Keys never leave HSM; operations are performed inside HSM
  - Key access: AKS workload identity (no service account credentials)
  - Audit: every key operation logged to Azure Monitor
```

---

## PART 4 — AZURE CLOUD ARCHITECTURE (IaaC)

### 4.1 Azure Services Inventory

| Service | Purpose | SKU | Redundancy |
|---|---|---|---|
| Azure Kubernetes Service | API + Worker workloads | Standard (D4s v5 nodes) | Zone-redundant node pools |
| Azure PostgreSQL Flexible | Primary database | Burstable B4ms → General Purpose D4s | Zone-redundant HA standby |
| Azure Cache for Redis | Session cache, rate limits, revocation list, pub/sub | Standard C1 → Premium P1 (with geo-replication) | Zone-redundant |
| Azure Service Bus | Event bus (async operations, push triggers) | Premium (1 messaging unit) | Zone-redundant |
| Azure Key Vault (HSM) | All secrets and cryptographic keys | Premium (HSM) | Geo-redundant |
| Azure Container Registry | Docker images | Premium | Geo-replication |
| Azure Notification Hubs | Unified push (FCM + APNs) | Standard | Built-in HA |
| Azure SignalR Service | WebSocket real-time channels | Standard | Zone-redundant |
| Azure Monitor + App Insights | Logs, metrics, traces | Pay-per-use | Built-in HA |
| Azure Entra External ID | Multi-tenant identity | P2 (for Conditional Access) | Global HA |
| Azure Static Web Apps | Flutter Web WASM + Next.js admin | Standard | Global CDN |
| Azure DevOps | Pipelines + Boards (optional, can use GitHub Actions) | Basic + Test Plans | Global HA |
| Azure Cost Management | Budget alerts, cost allocation | Free | Built-in |
| Azure Defender for Cloud | Security posture, vulnerability scanning | P2 | Global |

### 4.2 IaaC Structure (Terraform + Terragrunt)

```
infrastructure/
├── modules/                     ← Reusable Terraform modules
│   ├── aks/
│   │   ├── main.tf              ← AKS cluster, node pools, OIDC
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── postgresql/
│   │   ├── main.tf              ← PG Flexible, HA standby, PgBouncer
│   │   └── ...
│   ├── redis/
│   ├── service-bus/
│   ├── key-vault/
│   ├── notification-hubs/
│   ├── signalr/
│   ├── container-registry/
│   ├── monitoring/              ← Log Analytics, App Insights, Dashboards
│   ├── networking/              ← VNET, subnets, Private Endpoints, NSGs
│   └── cloudflare/              ← Workers, R2 buckets, KV namespaces, DNS
│
├── environments/
│   ├── dev/
│   │   ├── terragrunt.hcl
│   │   └── terraform.tfvars     ← dev-specific values (smaller SKUs, single AZ)
│   ├── staging/
│   │   ├── terragrunt.hcl
│   │   └── terraform.tfvars     ← staging: production-like, zone-redundant
│   └── production/
│       ├── terragrunt.hcl
│       └── terraform.tfvars     ← production: full SKUs, geo-replication
│
└── global/
    ├── backend.tf               ← Azure Blob remote state
    ├── providers.tf             ← azurerm, cloudflare, kubernetes providers
    └── versions.tf
```

**Sample AKS module (`infrastructure/modules/aks/main.tf`):**

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = "utamacs-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "utamacs-${var.environment}"
  kubernetes_version  = var.kubernetes_version

  # System node pool — runs cluster-critical workloads
  default_node_pool {
    name                = "system"
    node_count          = 2
    vm_size             = "Standard_D2s_v5"
    zones               = ["1", "2", "3"]
    os_disk_type        = "Ephemeral"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 4
    node_labels         = { "node-role" = "system" }
  }

  # API node pool — scales to traffic
  dynamic "agent_pool_profile" {
    for_each = var.user_node_pools
    content {
      name                = agent_pool_profile.value.name
      vm_size             = agent_pool_profile.value.vm_size
      zones               = ["1", "2", "3"]
      enable_auto_scaling = true
      min_count           = agent_pool_profile.value.min_count
      max_count           = agent_pool_profile.value.max_count
      node_labels         = agent_pool_profile.value.labels
      node_taints         = agent_pool_profile.value.taints
    }
  }

  identity { type = "SystemAssigned" }

  workload_identity_enabled         = true   # No service account credentials
  oidc_issuer_enabled               = true   # For Key Vault access
  azure_policy_enabled              = true   # Policy enforcement
  local_account_disabled            = true   # No local admin accounts
  role_based_access_control_enabled = true

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"              # Pod-to-pod network policy
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"  # All egress via firewall
  }

  microsoft_defender { log_analytics_workspace_id = var.log_analytics_workspace_id }

  tags = merge(var.common_tags, { "component" = "kubernetes" })
}
```

**Terragrunt environment config (`environments/production/terragrunt.hcl`):**
```hcl
include "root" { path = find_in_parent_folders() }

terraform { source = "../../modules//aks" }

inputs = {
  environment          = "production"
  location             = "centralindia"       # Data residency: India
  kubernetes_version   = "1.31"
  user_node_pools = [
    {
      name      = "apipool"
      vm_size   = "Standard_D4s_v5"
      min_count = 3
      max_count = 10
      labels    = { "workload" = "api" }
      taints    = []
    },
    {
      name      = "workerPool"
      vm_size   = "Standard_D2s_v5"
      min_count = 2
      max_count = 6
      labels    = { "workload" = "worker" }
      taints    = ["workload=worker:NoSchedule"]
    }
  ]
  common_tags = {
    environment  = "production"
    cost_center  = "platform"
    managed_by   = "terraform"
    project      = "utamacs"
  }
}
```

### 4.3 Kubernetes Deployment Architecture

```yaml
# k8s/api-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  labels:
    app: api-service
    version: "{{ .Values.image.tag }}"
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0        # Zero-downtime deployments
  selector:
    matchLabels:
      app: api-service
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: { app: api-service }
            topologyKey: topology.kubernetes.io/zone  # Spread across AZs
      containers:
      - name: api-service
        image: "{{ .Values.registry }}/api-service:{{ .Values.image.tag }}"
        resources:
          requests: { cpu: "250m", memory: "256Mi" }
          limits:   { cpu: "1000m", memory: "512Mi" }
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials    # Populated by Azure Key Vault CSI driver
              key: connection-string
        startupProbe:
          httpGet: { path: /health, port: 3000 }
          failureThreshold: 30
          periodSeconds: 2
        readinessProbe:
          httpGet: { path: /ready, port: 3000 }
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet: { path: /live, port: 3000 }
          initialDelaySeconds: 30
          periodSeconds: 30
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-service-pdb
spec:
  minAvailable: 2              # At least 2 pods always running during node drain
  selector:
    matchLabels:
      app: api-service
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: { type: Utilization, averageUtilization: 60 }
  - type: Resource
    resource:
      name: memory
      target: { type: Utilization, averageUtilization: 70 }
```

---

## PART 5 — API ARCHITECTURE (GraphQL + REST + Event-Driven)

### 5.1 API Layer Design

**Reads:** GraphQL (Pothos schema-builder + Mercurius on Fastify)  
**Mutations:** REST (better for audit logging, idempotency keys, optimistic locking)  
**Real-time:** Azure SignalR WebSocket channels  
**Async operations:** Azure Service Bus (fire-and-forget with guaranteed delivery)

**Why this split:**
- GraphQL for reads: clients request exactly the fields they need (solves mobile over-fetching). Query complexity analysis prevents abuse. Persisted queries (hash-based) eliminate query injection.
- REST for mutations: explicit URL paths are more auditable, easier to rate-limit per operation, natural for idempotency keys, and compatible with existing Astro portal API routes.

### 5.2 Solving Mobile Over-Fetching (Critical Finding #5)

**GraphQL query example — complaints list screen:**
```graphql
query ComplaintsList($tenantId: ID!, $filters: ComplaintFilters, $first: Int!, $after: String) {
  complaints(tenantId: $tenantId, filters: $filters, first: $first, after: $after) {
    edges {
      node {
        id
        title
        status
        category
        createdAt
        # Only these 5 fields — NOT the full entity with comments and attachments
      }
      cursor
    }
    pageInfo {
      hasNextPage
      endCursor
      totalCount
    }
  }
}
```

**Complaint detail screen (different query, more fields):**
```graphql
query ComplaintDetail($id: ID!) {
  complaint(id: $id) {
    id title description status category priority
    createdAt resolvedAt slaDeadline
    unit { unitNumber block }
    submittedBy { fullName avatarUrl }
    comments(last: 20) { edges { node { id content author { fullName } createdAt } } }
    attachments { id url mimeType fileSize }
    rating { score feedback }
  }
}
```

Bandwidth reduction vs REST for list screen: **~85%** (5 fields vs 30+ fields per complaint).

### 5.3 Optimistic Locking for Financial Data (Critical Finding #4)

Every mutation on financial data includes an `expected_version` field:

```typescript
// REST mutation: record payment
PUT /api/v1/finance/dues/:id/payment
{
  "amount": 5000,
  "mode": "upi",
  "reference": "UPI-123456",
  "expected_version": 7,           // Client's last known version of this dues record
  "idempotency_key": "uuid-v4"     // Client-generated, prevents double-submit
}

// Server:
// 1. Check idempotency_key in Redis — if seen before, return cached response
// 2. BEGIN TRANSACTION
// 3. SELECT version FROM dues WHERE id = ? FOR UPDATE
// 4. IF version != expected_version: ROLLBACK → 409 Conflict
//    { error: "CONFLICT", message: "Dues record was modified. Refresh and retry." }
// 5. INSERT INTO payments (immutable record)
// 6. UPDATE dues SET status = 'paid', version = version + 1
// 7. INSERT INTO domain_events (PaymentRecordedEvent)
// 8. COMMIT
// 9. Cache idempotency_key → response (TTL: 24 hours)
```

**Offline-allowed vs online-only operations (Critical Finding #4):**

```dart
// dart_core/lib/usecases/offline_policy.dart
enum MutationPolicy {
  onlineOnly,      // Payment recording, gate approval, role changes, policy acknowledgment
  offlineQueue,    // Complaint creation, attendance log, community post, maid check-in
  optimisticLocal, // Like/react, notification read — local first, server sync later
}

const mutationPolicies = {
  'complaints.create':         MutationPolicy.offlineQueue,
  'finance.recordPayment':     MutationPolicy.onlineOnly,
  'visitors.gateApprove':      MutationPolicy.onlineOnly,
  'members.changeRole':        MutationPolicy.onlineOnly,
  'policies.acknowledge':      MutationPolicy.onlineOnly,
  'attendance.log':            MutationPolicy.offlineQueue,
  'community.createPost':      MutationPolicy.offlineQueue,
  'notifications.markRead':    MutationPolicy.optimisticLocal,
};
```

### 5.4 Event-Driven Architecture (Missing from original)

All critical async operations use Azure Service Bus with guaranteed at-least-once delivery:

```
Domain Events (published after DB commit):
  VisitorGateRequestedEvent
    → push notification to unit residents (Notification Service)
    → log to audit_events
    → update real-time SignalR channel

  PaymentRecordedEvent
    → generate PDF receipt (async, background)
    → update billing metrics (Stripe usage reporting)
    → send confirmation WhatsApp/email

  ComplaintCreatedEvent
    → assign SLA timer
    → notify relevant maintenance staff

  TenantProvisioningRequestedEvent
    → create DB schema (Worker Service)
    → provision Cloudflare KV entry
    → send welcome email

  SubscriptionExpiredEvent
    → switch tenant to read-only mode
    → update Cloudflare KV tenant status
    → send grace period notification
```

**Retry and dead-letter policy:**
- Max delivery count: 5
- Retry intervals: 30s, 2m, 10m, 30m, 2h (exponential backoff)
- Dead-letter queue: unprocessed after 5 attempts → alert to engineering Slack + PagerDuty
- Dead-letter monitoring: Azure Monitor alert on DLQ depth > 10

---

## PART 6 — DOCUMENT & MEDIA STORAGE (Cloudflare R2)

This directly corrects Critical Finding #2 — replacing GitHub document store.

### 6.1 Storage Architecture

```
Cloudflare R2 (apac region — Singapore, closest to India):
  buckets:
    utamacs-documents-{tenantId}     ← KYC, policies, letters, invoices (private)
    utamacs-media-{tenantId}         ← Images, gallery photos (private)
    utamacs-exports                  ← CSV/PDF exports (private, 24h TTL)

  Access pattern:
    Upload: App → CF Worker → R2 (pre-signed URL, 15-minute upload window)
    Download: App → CF Worker (validates auth + tenant) → R2 pre-signed URL (1h)
    Images: App → CF Images URL (resizing + WebP conversion at edge, cached)
```

**No more synchronous commits.** Upload is fully async:

```
1. App → POST /api/v1/uploads/request { fileName, mimeType, sizeBytes }
2. Server validates MIME + size against rules engine
3. Server generates R2 pre-signed upload URL (15-min TTL)
4. Server creates upload_jobs record (status: pending)
5. Returns { jobId, uploadUrl } to app immediately (< 50ms)
6. App uploads directly to R2 using uploadUrl (no server in the loop)
7. R2 triggers Cloudflare Worker on object creation
8. Worker publishes FileUploadedEvent to Service Bus
9. Worker Service processes event: virus scan, thumbnail generation, update DB
10. Publishes FileProcessedEvent → SignalR → app receives real-time completion
```

**This eliminates:**
- The 2–8 second synchronous GitHub commit
- The 60-second Vercel function timeout risk for large uploads
- The GitHub ToS violation
- The DPDPA data residency issue (R2 apac region data stays in Asia-Pacific)

### 6.2 Image Optimization at Edge

```
Cloudflare Images transformation URL:
  Original (from R2): r2.utamacs.cloud/media/avatars/user-123.jpg
  
  Mobile avatar (100x100, WebP):
  /cdn-cgi/image/width=100,height=100,fit=cover,format=webp/media/avatars/user-123.jpg

  Gallery thumbnail (400x300, WebP):
  /cdn-cgi/image/width=400,height=300,fit=cover,format=webp,quality=80/media/gallery/...

  Full-res viewer (max 1200px wide, auto format):
  /cdn-cgi/image/width=1200,format=auto,quality=90/media/gallery/...
```

Cloudflare caches transformed variants at edge nodes worldwide. A gallery photo requested at 400x300 WebP is transformed once and served from cache for all subsequent requests — zero R2 bandwidth cost.

---

## PART 7 — REAL-TIME ARCHITECTURE

### 7.1 Azure SignalR Service

Replaces all polling. Three channel types:

```
Tenant-scoped channels (all members of a society):
  /hubs/society/{tenantId}/notices        ← New notice published
  /hubs/society/{tenantId}/announcements  ← Emergency announcements

Unit-scoped channels (specific residential unit):
  /hubs/unit/{unitId}/gate-requests       ← Incoming gate approval request
  /hubs/unit/{unitId}/deliveries          ← Delivery arrived

User-scoped channels (individual user):
  /hubs/user/{userId}/notifications       ← Personal notification
  /hubs/user/{userId}/upload-progress     ← File upload completion
```

**Flutter SignalR client:**
```dart
// flutter_shared/lib/services/realtime_service.dart
class RealtimeService {
  late HubConnection _connection;

  Future<void> connect(String accessToken, String tenantId, String userId) async {
    _connection = HubConnectionBuilder()
      .withUrl('${Env.apiBaseUrl}/signalr-negotiate',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => accessToken,
            headers: {'X-Tenant-ID': tenantId},
          ))
      .withAutomaticReconnect([0, 2000, 5000, 10000, 30000])
      .build();

    _connection.on('GateRequestReceived', _handleGateRequest);
    _connection.on('NotificationReceived', _handleNotification);
    _connection.on('FileProcessingComplete', _handleUploadComplete);

    await _connection.start();
  }

  // Clean up when app goes to background
  Future<void> pauseConnection() async => await _connection.stop();
  Future<void> resumeConnection() async => await _connection.start();
}
```

### 7.2 Push Notification Architecture (Azure Notification Hubs)

Azure Notification Hubs provides a unified interface to FCM (Android) and APNs (iOS) with automatic retry, delivery tracking, and tag-based targeting.

```
Device registration:
  App login → register push token with Azure Notification Hub
  Hub tags: tenant:{tenantId}, unit:{unitId}, user:{userId}, role:{role}, platform:{platform}

Notification dispatch:
  Server → Hub SDK → Hub (retries + routing)
    → FCM → Android device
    → APNs → iOS device

Tag-based targeting (no per-device loops):
  "Send to all residents of society X":  tag = "tenant:society-X"
  "Send to unit 205":                    tag = "unit:unit-205-id"
  "Send to all executives of society X": tags = ["tenant:society-X", "role:executive"]
  "Send to specific user":               tag = "user:user-id"

Delivery tracking:
  Hub provides telemetry: sent, delivered, failed, skipped
  Failed → Dead-letter queue → fallback to email/WhatsApp
```

---

## PART 8 — DESIGN SYSTEM (CROSS-PLATFORM CONSISTENCY)

### 8.1 Single Source of Truth: Style Dictionary

Style Dictionary generates platform-specific token files from one JSON source:

```
design-tokens/
  tokens/
    colors.json          ← All color definitions
    typography.json      ← Font families, sizes, line heights
    spacing.json         ← Spacing scale
    radius.json          ← Border radius
    shadows.json         ← Elevation shadows
    motion.json          ← Animation durations and easings
  transforms/
    flutter.js           ← Generates dart_core/lib/design/tokens.g.dart
    css.js               ← Generates web CSS custom properties
    tailwind.js          ← Generates tailwind.config.cjs for admin portal
  build.js              ← Build script
```

**Example motion token (the missing futuristic layer from the original):**
```json
{
  "motion": {
    "duration": {
      "micro":      { "value": "100ms",  "comment": "Checkbox, switch toggle, icon swap" },
      "standard":   { "value": "200ms",  "comment": "List item appear, badge update" },
      "emphasize":  { "value": "300ms",  "comment": "Screen push, bottom sheet open" },
      "hero":       { "value": "500ms",  "comment": "Shared element transition, onboarding" }
    },
    "easing": {
      "enter":      { "value": "cubic-bezier(0.0, 0.0, 0.2, 1.0)", "comment": "Decelerate — elements entering the screen" },
      "exit":       { "value": "cubic-bezier(0.4, 0.0, 1.0, 1.0)", "comment": "Accelerate — elements leaving" },
      "standard":   { "value": "cubic-bezier(0.4, 0.0, 0.2, 1.0)", "comment": "Elements that stay on screen" },
      "spring":     { "value": "spring(1, 80, 12, 0)",             "comment": "Physics spring — interactive gestures" }
    }
  }
}
```

**Generated Dart (`tokens.g.dart`):**
```dart
// AUTO-GENERATED by Style Dictionary — do not edit manually
// Source: design-tokens/tokens/motion.json
abstract class MotionTokens {
  static const Duration micro     = Duration(milliseconds: 100);
  static const Duration standard  = Duration(milliseconds: 200);
  static const Duration emphasize = Duration(milliseconds: 300);
  static const Duration hero      = Duration(milliseconds: 500);

  static const Curve enter    = Cubic(0.0, 0.0, 0.2, 1.0);
  static const Curve exit     = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve standard = Cubic(0.4, 0.0, 0.2, 1.0);
}
```

Any designer change to `motion.json` → `npm run design-system:build` → generates tokens for all platforms simultaneously. **No platform can drift from the source of truth.**

### 8.2 Platform-Adaptive Components

Flutter's theming system allows a single widget to render with platform-appropriate conventions:

```dart
// flutter_shared/lib/widgets/app_button.dart
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // Platform-adaptive rendering:
    // iOS: rounded rect, SF-style weight, system blue accent
    // Android: rounded rect, Material You color, ripple effect
    // Desktop: tighter padding, hover state, keyboard focus ring
    // Web: cursor:pointer, tab focus outline, reduced border-radius

    return PlatformAdaptiveButton(
      label: label,
      onPressed: onPressed,
      style: _resolveStyle(theme, variant, defaultTargetPlatform),
    );
  }
}
```

### 8.3 Internationalization Architecture (Missing from original)

```dart
// dart_core/lib/l10n/
//   app_en.arb  ← English (primary)
//   app_te.arb  ← Telugu (Telangana residents)
//   app_hi.arb  ← Hindi (staff, guards)

// All UI strings are externalized:
// flutter_shared/lib/widgets/gate_approval_card.dart
Text(context.l10n.gateApprovalTitle)     // "Gate Approval Request" / "గేట్ అనుమతి అభ్యర్థన"
Text(context.l10n.approve)               // "Approve" / "అంగీకరించు" / "स्वीकृत"

// Indian number formatting:
NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount)
// → ₹5,000 in en; ₹5,000 in te (same format, different locale fallback)

// Date formatting (IST always):
DateFormat('dd MMM yyyy', 'en_IN').format(istDate)
```

---

## PART 9 — CI/CD FOR ALL PLATFORMS

### 9.1 Pipeline Architecture

```
GitHub Repository (monorepo)
  ├── .github/workflows/
  │   ├── pr-checks.yml          ← On every PR: lint, type-check, unit tests, AI review
  │   ├── cd-api.yml             ← On main merge: build Docker, push ACR, deploy AKS
  │   ├── cd-flutter-mobile.yml  ← On tag: build iOS + Android, submit to stores
  │   ├── cd-flutter-web.yml     ← On main merge: build WASM, deploy Azure Static Web Apps
  │   ├── cd-admin-portal.yml    ← On main merge: build Next.js, deploy
  │   ├── iac-plan.yml           ← On PR touching infrastructure/: terraform plan
  │   └── iac-apply.yml          ← On main merge + manual approval: terraform apply
  │
  └── CODEOWNERS
      *                           @utamacs/engineering-leads
      infrastructure/             @utamacs/platform-team @utamacs/engineering-leads
      packages/dart-core/         @utamacs/mobile-leads
      apps/api-service/           @utamacs/backend-leads
```

### 9.2 PR Checks Pipeline (`pr-checks.yml`)

```yaml
name: PR Checks
on: pull_request

jobs:
  ai-security-review:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with: { fetch-depth: 0 }

    - name: Get changed files
      id: changes
      run: |
        git diff --name-only origin/${{ github.base_ref }}..HEAD > changed_files.txt
        echo "files=$(cat changed_files.txt | tr '\n' ',')" >> $GITHUB_OUTPUT

    - name: AI Code Security Review
      env:
        ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
      run: |
        # Get the diff
        git diff origin/${{ github.base_ref }}..HEAD > pr_diff.txt

        # Send to Claude for security review
        python scripts/ai_code_review.py \
          --diff pr_diff.txt \
          --output review_output.json \
          --rules security,dpdpa,owasp,sql_injection,auth_bypass,secrets

        # Parse and post as PR comment
        python scripts/post_review_comment.py \
          --review review_output.json \
          --pr ${{ github.event.pull_request.number }}

        # Fail if HIGH or CRITICAL issues found
        python scripts/check_review_threshold.py \
          --review review_output.json \
          --max-severity MEDIUM

  sast:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: github/codeql-action/init@v3
      with: { languages: typescript, dart }
    - uses: github/codeql-action/autobuild@v3
    - uses: github/codeql-action/analyze@v3

  secret-detection:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with: { fetch-depth: 0 }
    - uses: trufflesecurity/trufflehog@main
      with:
        extra_args: --only-verified  # Only verified secrets fail the build

  dependency-audit:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: npm audit --audit-level=high
    - run: dart pub audit  # Dart dependency audit

  flutter-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with: { flutter-version: '3.22.x' }
    - run: |
        cd packages/dart-core && dart test --coverage=coverage
        cd apps/flutter-app && flutter test --coverage
        dart pub global run coverage:format_coverage --lcov --in=coverage --out=lcov.info
    - uses: codecov/codecov-action@v4
      with: { files: lcov.info, fail_ci_if_error: true, threshold: 80 }

  api-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_PASSWORD: test, POSTGRES_DB: utamacs_test }
    steps:
    - uses: actions/checkout@v4
    - run: cd apps/api-service && npm ci && npm run test:api

  design-token-check:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - run: |
        cd packages/design-tokens && npm ci && npm run build
        # Check that generated files match committed files (no manual edits to generated code)
        git diff --exit-code packages/dart-core/lib/design/tokens.g.dart \
                             apps/admin-portal/src/styles/tokens.css
```

### 9.3 AI Code Review Script

```python
# scripts/ai_code_review.py
import anthropic, json, sys, argparse

SYSTEM_PROMPT = """You are a senior security architect and enterprise software reviewer.
Review the provided code diff for:
1. Security vulnerabilities (OWASP Top 10, OWASP Mobile Top 10)
2. DPDPA 2023 compliance issues (PII handling, data residency, consent)
3. Authentication/authorization bypasses
4. SQL injection, NoSQL injection, command injection
5. Hardcoded secrets or API keys
6. Insecure direct object references
7. Missing audit logging on sensitive operations
8. Multi-tenant isolation violations (cross-tenant data access)
9. Optimistic locking missing on financial mutations
10. Offline queue incorrectly used for online-only operations

For each issue found, output JSON:
{
  "severity": "CRITICAL|HIGH|MEDIUM|LOW|INFO",
  "category": "string",
  "file": "string",
  "line": number,
  "description": "string",
  "recommendation": "string",
  "cwe": "CWE-XXX"
}

Output a JSON array of all issues. Empty array if no issues found.
Be specific and actionable. Do not hallucinate issues."""

def review_diff(diff_content: str) -> list:
    client = anthropic.Anthropic()
    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"Review this diff:\n\n```diff\n{diff_content[:50000]}\n```"
        }]
    )
    try:
        return json.loads(message.content[0].text)
    except:
        return []

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--diff', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    with open(args.diff) as f:
        diff = f.read()

    issues = review_diff(diff)
    with open(args.output, 'w') as f:
        json.dump(issues, f, indent=2)

    print(f"AI review complete: {len(issues)} issues found")
    for issue in issues:
        print(f"  [{issue['severity']}] {issue['file']}: {issue['description'][:80]}")
```

### 9.4 Flutter Mobile CD Pipeline

```yaml
name: Flutter Mobile Release
on:
  push:
    tags: ['v*.*.*']

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
    - name: Build Android App Bundle
      env:
        KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
        KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
      run: |
        echo $KEYSTORE_BASE64 | base64 --decode > keystore.jks
        cd apps/flutter-app
        flutter build appbundle --release \
          --dart-define=APP_ENV=production \
          --dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }} \
          --obfuscate --split-debug-info=debug-symbols/
    - name: Upload to Play Store (Internal Track)
      uses: r0adkll/upload-google-play@v1
      with:
        serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
        packageName: org.utamacs.portal
        releaseFiles: build/app/outputs/bundle/release/app-release.aab
        track: internal
        status: draft
    - name: Upload debug symbols to Sentry
      run: |
        sentry-cli debug-files upload --org utamacs --project flutter-app \
          apps/flutter-app/debug-symbols/

  build-ios:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
    - uses: apple-actions/import-codesign-certs@v3
      with:
        p12-file-base64: ${{ secrets.IOS_DISTRIBUTION_CERT_BASE64 }}
        p12-password: ${{ secrets.IOS_DISTRIBUTION_CERT_PASSWORD }}
    - name: Build iOS IPA
      run: |
        cd apps/flutter-app
        flutter build ipa --release \
          --dart-define=APP_ENV=production \
          --export-options-plist=ios/ExportOptions.plist
    - name: Upload to TestFlight
      uses: apple-actions/upload-testflight-build@v1
      with:
        app-path: build/ios/ipa/utamacs.ipa
        issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
        api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
        api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}
```

### 9.5 API Service CD Pipeline

```yaml
name: API Service Deploy
on:
  push:
    branches: [main]
    paths: ['apps/api-service/**', 'packages/dart-core/**']

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
    - uses: actions/checkout@v4

    - name: Login to Azure Container Registry
      uses: azure/docker-login@v1
      with:
        login-server: ${{ secrets.ACR_LOGIN_SERVER }}
        username: ${{ secrets.ACR_USERNAME }}
        password: ${{ secrets.ACR_PASSWORD }}

    - name: Build and push Docker image
      run: |
        IMAGE="${{ secrets.ACR_LOGIN_SERVER }}/api-service:${{ github.sha }}"
        docker build -f apps/api-service/Dockerfile \
          --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
          --build-arg GIT_COMMIT=${{ github.sha }} \
          -t $IMAGE .
        docker push $IMAGE

        # Also tag as latest for the environment
        docker tag $IMAGE ${{ secrets.ACR_LOGIN_SERVER }}/api-service:latest
        docker push ${{ secrets.ACR_LOGIN_SERVER }}/api-service:latest

    - name: Deploy to AKS (rolling update, zero downtime)
      uses: azure/k8s-deploy@v4
      with:
        action: deploy
        manifests: k8s/api-service/
        images: ${{ secrets.ACR_LOGIN_SERVER }}/api-service:${{ github.sha }}
        strategy: rolling
        traffic-split-method: pod

    - name: Verify deployment health
      run: |
        kubectl rollout status deployment/api-service -n production --timeout=5m
        # Run smoke tests against production
        npm run test:smoke --workspace=apps/api-service -- --env=production
```

---

## PART 10 — GOVERNANCE ARCHITECTURE (NO ESCAPE)

### 10.1 Feature Flag Governance (Critical Finding #6b)

```sql
-- Enhanced feature_flags table
ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS rollout_percentage integer DEFAULT 100 CHECK (rollout_percentage BETWEEN 0 AND 100);
ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS targeting_rules jsonb DEFAULT '{}';
ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS requires_approval boolean DEFAULT false;
ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS approval_status text CHECK (approval_status IN ('pending', 'approved', 'rejected'));
ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES profiles(id);
ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS approved_at timestamptz;
ALTER TABLE feature_flags ADD COLUMN IF NOT EXISTS platform text DEFAULT 'all' CHECK (platform IN ('all', 'web', 'flutter', 'android', 'ios', 'desktop'));

-- Every change to feature_flags is event-sourced
CREATE OR REPLACE FUNCTION audit_feature_flag_change() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO domain_events (event_type, aggregate_type, aggregate_id, payload, actor_id)
  VALUES (
    TG_OP || '_FEATURE_FLAG',
    'feature_flag',
    NEW.id::text,
    jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)),
    current_setting('app.current_user_id', true)::uuid
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER feature_flag_audit AFTER INSERT OR UPDATE ON feature_flags
  FOR EACH ROW EXECUTE FUNCTION audit_feature_flag_change();
```

**Approval workflow for production flag changes:**
```
1. Engineer proposes flag change via PR (changes feature_flags seed migration)
2. PR triggers ai-security-review (does this flag enable a security-sensitive feature?)
3. Two approvals required: engineering lead + product owner (CODEOWNERS enforces this)
4. On merge: flag is set with requires_approval=true, approval_status='pending'
5. Server-side: pending flags are NOT active until approved in the admin UI
6. Society admin approves via admin portal (second human in the loop)
7. Approval logged to domain_events + audit_logs
```

### 10.2 Remote Configuration Governance

**Firebase Remote Config** (integrated with Firebase/FCM already required for push):

```dart
// dart_core/lib/services/remote_config_service.dart
class RemoteConfigService {
  final FirebaseRemoteConfig _config;
  static const _fetchInterval = Duration(hours: 1);  // Prod; 1 min for dev

  Future<void> initialize() async {
    await _config.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: _fetchInterval,
    ));

    // Activate immediately on first launch, then refresh in background
    await _config.fetchAndActivate();
  }

  // Typed accessors — no magic strings in app code
  bool get isGateApprovalEnabled => _config.getBool('feature_gate_approval');
  int get gateApprovalWindowSeconds => _config.getInt('gate_approval_window_seconds');
  bool get isMaintenanceMode => _config.getBool('maintenance_mode');
  String get minimumAppVersion => _config.getString('minimum_app_version');
  int get offlineQueueMaxRetries => _config.getInt('offline_queue_max_retries');
}
```

**Governance for Remote Config changes:**
- All Remote Config changes committed to `config/firebase-remote-config.json` in Git
- A GitHub Action syncs Git → Firebase Remote Config on merge to main
- This means: Remote Config changes go through the same PR review process as code changes
- No one can directly edit Firebase Remote Config console in production without a Git commit

### 10.3 Multi-Tenant Governance (Critical Finding #6c)

**Tenant lifecycle state machine:**

```
PROVISIONING → TRIAL → ACTIVE → PAST_DUE → SUSPENDED → TERMINATED
                                    ↓
                              (payment failed)
                                    ↓
                          GRACE_PERIOD (7 days)
                                    ↓
                              SUSPENDED (read-only)
                                    ↓
                              DATA_ARCHIVED (30 days)
                                    ↓
                              TERMINATED (purged)
```

**System admin roles separate from tenant admins (Critical Finding #6c):**

```sql
-- System-level roles (UTAMACS platform operators)
CREATE TABLE system_roles (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  uuid NOT NULL REFERENCES profiles(id),
  role        text NOT NULL CHECK (role IN (
    'super_admin',        -- Full access to all tenants, billing, provisioning
    'support_agent',      -- Read-only access to tenant data for support
    'billing_admin',      -- Subscription management only
    'security_analyst'    -- Audit log access only
  )),
  created_at  timestamptz NOT NULL DEFAULT now()
);
-- System roles are ENTIRELY separate from tenant portal_role
-- A tenant admin (is_admin=true) has NO access to other tenants or billing
-- A super_admin has cross-tenant access — strictly controlled, audited
```

---

## PART 11 — OBSERVABILITY ARCHITECTURE

### 11.1 The Three Pillars (OpenTelemetry)

**All services are instrumented with OpenTelemetry SDK.** Telemetry flows to Azure Monitor (Application Insights) for the hosted platform:

```
Logs (structured JSON):
  Every API request logs:
  {
    "timestamp": "2026-05-11T10:30:00.000Z",
    "level": "INFO",
    "request_id": "cf-ray-abc123",
    "tenant_id_hash": "sha256(tenantId + daily_salt)",   // DPDPA: no raw tenant ID
    "user_id_hash":   "sha256(userId + daily_salt)",     // DPDPA: no raw user ID
    "device_id_hash": "sha256(deviceId + daily_salt)",
    "platform":       "flutter-android",
    "app_version":    "1.2.3",
    "endpoint":       "POST /api/v1/complaints",
    "duration_ms":    143,
    "status_code":    201,
    "db_queries":     3,
    "db_duration_ms": 45,
    "cache_hit":      false
  }

Metrics (custom business metrics):
  utamacs.gate.approval.response_time{tenant, result}    ← Gate approval latency
  utamacs.push.delivery.rate{tenant, platform, type}     ← Push notification delivery
  utamacs.complaint.resolution.time{tenant, category}    ← SLA tracking
  utamacs.offline.queue.depth{tenant, platform}          ← Offline queue health
  utamacs.api.response_time{endpoint, tenant_tier}       ← API performance by tier
  utamacs.subscription.mrr{plan}                         ← Business metric (MRR)

Traces (distributed):
  Flutter app → Cloudflare Worker → AKS API Service → PostgreSQL
  Each hop is instrumented with span start/end times
  Full trace visible in Application Insights Transaction Search
  Slow query spans automatically identified
```

### 11.2 SLO-Based Alerting (Not Raw Error Rate)

```yaml
# SLOs defined in Terraform (Azure Monitor alert rules)

# Gate Approval SLO: 99% of approvals delivered within 10 seconds
alertRules:
  - name: gate-approval-slo-burn-rate
    condition:
      query: |
        requests
        | where name == "POST /api/v1/visitors/gate-requests"
        | summarize
            total = count(),
            fast = countif(duration < 10000)
            by bin(timestamp, 5m)
        | extend slo_rate = fast * 1.0 / total
        | where slo_rate < 0.99
    severity: 1  # Critical
    frequency: 5m
    windowSize: 15m

  # API p95 SLO: 95th percentile response time < 1000ms
  - name: api-p95-latency-slo
    condition:
      query: |
        requests
        | where cloud_RoleName == "api-service"
        | summarize p95 = percentile(duration, 95) by bin(timestamp, 5m)
        | where p95 > 1000
    severity: 2  # Warning
```

### 11.3 Cost Observability (Measurable Operations Cost — Requirement #17)

**Every Azure resource is tagged:**
```hcl
# Mandatory tags on all Terraform resources
locals {
  mandatory_tags = {
    managed_by   = "terraform"
    environment  = var.environment
    project      = "utamacs"
    cost_center  = var.cost_center     # "platform", "tenant-{id}", "operations"
    service      = var.service_name    # "api", "database", "cache", "storage"
    team         = var.team_owner      # "backend", "platform", "mobile"
  }
}
```

**Azure Cost Management budget alerts:**
```json
{
  "budgets": [
    {
      "name": "production-monthly",
      "amount": 50000,              // INR per month (tune to actual)
      "timeGrain": "Monthly",
      "notifications": {
        "at_80_percent":  { "threshold": 80,  "contacts": ["platform-team@utamacs.org"] },
        "at_100_percent": { "threshold": 100, "contacts": ["engineering-lead@utamacs.org", "cto@utamacs.org"] },
        "at_120_percent": { "threshold": 120, "contacts": ["cto@utamacs.org"] }
      }
    }
  ]
}
```

**Per-tenant cost attribution:**
Azure Resource Tags allow filtering Cost Management by `cost_center=tenant-{id}`. Monthly cost report per tenant enables:
- Pricing validation (does Starter plan pricing cover infrastructure cost?)
- Tenant-specific cost anomaly detection
- Enterprise customer cost transparency reports

---

## PART 12 — USER ACCEPTANCE, ADOPTION & FEEDBACK (Requirement #21)

### 12.1 Product Analytics (PostHog, self-hosted on Azure)

```dart
// dart_core/lib/analytics/posthog_tracker.dart
class PostHogTracker implements AnalyticsTracker {
  final Posthog _posthog;

  Future<void> track(AnalyticsEvent event) async {
    // PII guard: no user-identifiable data in any event property
    await _posthog.capture(
      eventName: event.name,
      properties: {
        ...event.properties,
        // Auto-properties (anonymized):
        'platform':      defaultTargetPlatform.name,
        'app_version':   AppInfo.version,
        'tenant_hash':   _tenantHash,        // one-way hash, not raw ID
        'session_id':    _sessionId,         // rotating session ID, not user ID
      },
    );
  }
}
```

**Key funnels to measure:**

```
Funnel 1: Complaint Creation
  complaint_list_viewed → complaint_create_started → attachment_added → complaint_created
  Target: > 80% completion rate from started to submitted

Funnel 2: Gate Approval (resident response time)
  gate_request_received → notification_opened → gate_request_approved
  Target: > 90% response within 2 minutes

Funnel 3: First-Week Activation
  login → home_viewed → first_complaint_created OR first_notice_read
  Target: > 70% of new users complete activation in week 1

Funnel 4: Feature Adoption
  Module access rate by module_key (which modules are actually used?)
  Target: > 60% MAU for core modules (complaints, notices, finance)
```

### 12.2 In-App NPS & Feedback

```dart
// Triggered at the right moment — not randomly
class NPSSurveyTrigger {
  bool shouldShow(UserContext ctx) {
    return
      ctx.sessionCount >= 5 &&                  // Established user
      ctx.daysSinceLastNPS >= 90 &&             // Not surveyed recently
      ctx.lastAction == 'complaint_resolved' &&  // Moment of delight
      !ctx.isGuard;                             // Guards don't get NPS
  }
}
```

**Feedback data pipeline:**
- In-app NPS → PostHog → tagged by `plan`, `role`, `tenant_size`
- App store ratings → aggregated via App Store Connect API + Play Developer API
- Support tickets → Freshdesk / Zendesk (integrated, tags auto-applied from tenant plan)
- All three sources → Power BI dashboard → weekly review by product team

### 12.3 Session Replay (with PII masking)

PostHog session replay for the Flutter Web (WASM) portal, with mandatory masking:

```dart
// All text inputs are masked by default in session replay
// Only explicitly opted-in elements show content
Posthog.mask(widget: passwordField);
Posthog.mask(widget: aadhaarField);
Posthog.mask(widget: phoneNumberField);
// Only interaction patterns visible — not content
```

---

## PART 13 — COMPLIANCE ARCHITECTURE

### 13.1 DPDPA 2023 (India)

| Requirement | Implementation |
|---|---|
| Data residency | Azure Central India (Pune) + Cloudflare R2 apac region |
| Purpose limitation | Every personal data column has SQL comment `-- personal data: {purpose}` |
| Consent before processing | `privacy_consents` table; app blocks access until consent given |
| Data principal rights | Self-service data export (`GET /api/v1/members/me/data-export`) and deletion (`DELETE /api/v1/members/me`) |
| Breach notification | Azure Defender triggers breach workflow; 72-hour regulatory reporting |
| Cross-border transfer | GitHub doc store eliminated; all storage in India/Asia-Pacific |
| PII in logs | All logs use `user_id_hash`, never raw user IDs; daily salt rotation |
| Audit trail | `domain_events` table: immutable, append-only, captures all personal data access by executives |
| Retention | `pg_cron` job runs monthly: archive/delete data beyond retention policy |

### 13.2 IT Act 2000 / Indian Regulations

- Digital signatures on official letters (placeholder for DSC integration)
- Aadhaar-based eKYC: compliant with UIDAI guidelines (no Aadhaar storage, only last-4 display)
- Payment data: PCI-DSS not required (no card processing; Stripe handles it)
- TRAI DLT registration required before SMS/WhatsApp bulk messaging (compliance gate in feature flags)

### 13.3 SOC2 Type II Readiness (Future path)

All controls implemented now for SOC2 readiness (achievable within 12 months of launch):
- **CC6.1:** Logical access controlled via Entra ID + MFA
- **CC6.2:** Access revocation on termination (automated via HR webhook)
- **CC6.3:** Least privilege (RBAC enforced at all layers)
- **CC7.1:** Vulnerability scanning (GitHub CodeQL + Defender for Cloud) in CI
- **CC7.2:** Monitoring (OpenTelemetry → Azure Monitor)
- **CC8.1:** Change management (all changes via PR → AI review → human approval → deploy)

---

## PART 14 — REVISED ARCHITECTURE SUMMARY

### What Changes from the Original v1.0

| Decision | v1.0 (Original) | v2.0 (This Document) |
|---|---|---|
| Mobile framework | React Native + Expo managed | **Flutter (Dart) — all platforms** |
| Web portal | Astro SSR (kept) | **Flutter Web (WASM) + Next.js admin** |
| Auth provider | Supabase Auth | **Azure Entra External ID** |
| Database | Supabase PostgreSQL (single region) | **Azure PostgreSQL Flexible (zone-redundant HA)** |
| Document storage | GitHub private repo | **Cloudflare R2 (apac, S3-compatible)** |
| API layer | Vercel serverless functions | **AKS (Node.js + Fastify + GraphQL + REST)** |
| API gateway | None | **Cloudflare Workers (zero cold start)** |
| Real-time | Polling (30s intervals) | **Azure SignalR + Supabase Realtime → Azure SignalR** |
| Push notifications | Expo Push → FCM/APNs | **Azure Notification Hubs (unified FCM+APNs)** |
| QR verification | Server round-trip required | **HMAC-signed offline-verifiable passes** |
| State management | React Query + Zustand | **Riverpod (Flutter) + GoRouter** |
| Offline strategy | Last-write-wins | **Online-only for financial/security; idempotent queue for informational** |
| Certificate pinning | Leaf certificate | **Intermediate CA certificate** |
| Biometric | Optional convenience | **Mandatory step-up for sensitive operations** |
| App attestation | Optional hardening | **Required on every gate approval API call** |
| IaaC | Not specified | **Terraform + Terragrunt (all Azure + Cloudflare)** |
| CI/CD | EAS Build + GitHub Actions | **GitHub Actions + Codemagic (Flutter) + AKS Helm** |
| AI code review | Not present | **Claude (Anthropic API) on every PR** |
| i18n | Not mentioned | **en + te + hi from day 1 (Style Dictionary)** |
| Design tokens | Manual per-platform | **Style Dictionary → auto-generated for all platforms** |
| Cost observability | Not specified | **Azure Cost Management + per-tenant tagging** |
| User analytics | PostHog (mentioned) | **PostHog self-hosted + NPS + session replay (masked)** |
| Multi-tenancy | society_id FK + RLS | **Schema isolation + RLS + network isolation + Cloudflare KV** |
| Subscription billing | Not specified | **Stripe Billing + usage metering + Cloudflare KV plan cache** |
| Event sourcing | Not present | **domain_events table (immutable, append-only)** |
| Staff portal | Deferred | **Separate Flutter build target from day 1 (same codebase, separate entry point)** |
| Remote config | Firebase Remote Config (mentioned) | **Firebase RC + governed via Git (all changes via PR)** |

### Revised Timeline (Realistic, Not Optimistic)

```
Phase 0: Foundation (Months 1–2)
  - IaaC: Terraform all Azure resources + Cloudflare
  - Azure Entra External ID tenant configuration
  - AKS cluster + base services (Redis, Service Bus, Key Vault)
  - Cloudflare R2 + Workers gateway
  - CI/CD pipelines (all platforms) + AI review script
  - Design system (Style Dictionary → tokens for all platforms)
  - dart_core package structure + GraphQL schema
  - All pre-condition backend changes (Bearer auth, permissions endpoint, BFF)

Phase 1: Authentication + Core (Months 3–4)
  - Flutter: Login (email + OTP), biometric enrollment, token lifecycle
  - Flutter: Home screen (BFF aggregate), push notification registration
  - Flutter: Gate approval (HMAC-signed QR, offline verification, step-up biometric)
  - API: GraphQL complaints + notices + finance queries
  - Push: Azure Notification Hubs → gate request notifications

Phase 2: Resident Core Features (Months 5–7)
  - Flutter: Complaints (offline-queued), Notices, Finance dues, Visitor Passes, Community
  - Flutter: QR scanner (guard app entry point), offline-first guard mode
  - Flutter: Offline queue for permitted mutations + sync service
  - API: Upload pipeline (R2 pre-signed + async processing)
  - i18n: Telugu + Hindi strings for all Phase 2 screens

Phase 3: Extended Modules + Desktop (Months 8–11)
  - Flutter: Polls, Facilities, Parking, Events, Gallery, Documents
  - Flutter Desktop: macOS + Windows builds (same codebase)
  - Flutter Web (WASM): Web portal build replacing Astro portal
  - Executive modules: Vendors, HOTO, Snags, Maids, Letters
  - Multi-tenant: Provisioning API, subscription billing, plan enforcement

Phase 4: Enterprise Features + Launch (Months 12–15)
  - SSO (SAML/OIDC for Enterprise tier)
  - Analytics dashboards (PostHog + Power BI)
  - SOC2 evidence collection
  - Multi-society onboarding (Starter + Professional tiers)
  - App Store + Play Store launch
  - Staff portal separate app build
  - 30-day beta with 3 pilot societies

Total: 15 months to full enterprise launch
Team: 4 Flutter engineers, 2 backend engineers, 1 platform/SRE, 1 designer, 1 QA
```

---

*This document supersedes MOBILE_ARCHITECTURE.md v1.0. All implementation work must reference and conform to v2.0. Architecture decisions that deviate from this document require a written Architecture Decision Record (ADR) approved by the engineering lead.*
