# UTA MACS — Enterprise Mobile Architecture Assessment & Planning Document

**Version:** 1.0  
**Date:** 2026-05-10  
**Classification:** Internal — Engineering Leadership  
**Scope:** Full-stack assessment of the existing Astro portal + production-grade native mobile architecture design

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Current State Assessment](#2-current-state-assessment)
3. [Gaps & Risks](#3-gaps--risks)
4. [Recommended Architecture](#4-recommended-architecture)
5. [Shared vs Native Strategy](#5-shared-vs-native-strategy)
6. [UI/UX Strategy](#6-uiux-strategy)
7. [Backend & API Readiness](#7-backend--api-readiness)
8. [Security Strategy](#8-security-strategy)
9. [DevOps & Infrastructure](#9-devops--infrastructure)
10. [Reliability & Scalability](#10-reliability--scalability)
11. [Testing & QA Strategy](#11-testing--qa-strategy)
12. [Performance Engineering](#12-performance-engineering)
13. [Folder Structure Recommendations](#13-folder-structure-recommendations)
14. [Technical Decision Matrix](#14-technical-decision-matrix)
15. [Migration Plan](#15-migration-plan)
16. [Roadmap](#16-roadmap)
17. [Detailed Discovery Questionnaire](#17-detailed-discovery-questionnaire)
18. [Immediate Next Steps](#18-immediate-next-steps)

---

## 1. EXECUTIVE SUMMARY

### 1.1 Platform Overview

UTA MACS is a production-grade cooperative society management platform serving residents of Urban Trilla Apartments, Kondakal, Shankarpalle, Telangana. The current system is a mature, feature-rich Astro 4 hybrid portal deployed on Vercel with Supabase as its backend. After exhaustive codebase analysis, the platform comprises:

| Dimension | Scale |
|---|---|
| Portal pages | 89 SSR routes |
| API endpoints | 200+ REST endpoints |
| Database migrations | 89 (production schema) |
| User-facing modules | 28 active modules |
| Permission features | 3-layer RBAC with 100+ granular permissions |
| Notification channels | In-app + WhatsApp + SMS (feature-flagged) |
| Document store | Private GitHub repo (GitHub as CDN) |
| Compliance posture | DPDPA 2023 compliant |

### 1.2 Mobile Opportunity Assessment

The platform has excellent **web mobile readiness** (PWA manifest, responsive Tailwind layout, service worker stub) but lacks the native capabilities that a residential management platform requires for daily, mission-critical use:

- **Residents** need push notifications for gate approvals (10-minute countdown), due date reminders, complaint updates, and notice circulars — all of which currently rely on manual email/WhatsApp delivery or web polling.
- **Security guards** need a reliable, offline-capable QR/OTP scanner that works in low-connectivity compound areas without depending on a browser session.
- **Executives** need a real-time dashboard accessible without a browser — especially for HOTO sign-off workflows and vendor approval chains.
- **The gate approval flow** (10-minute countdown, real-time polling every 30s) is architecturally fragile on mobile browsers due to background tab throttling — this alone mandates native push notifications.

### 1.3 Strategic Recommendation

**Recommended Stack: React Native (Expo) + Shared API contract layer**

**Rationale (full justification in Section 5):**

The existing web portal is built almost entirely in vanilla JS + Astro (the two React components are dashboards). The business logic lives **entirely in the API layer** — 200+ well-structured REST endpoints. This means:

1. There is no React component library to migrate — the mobile apps start fresh with a native-first design system.
2. The API layer is the single source of truth and is already well-abstracted.
3. React Native gives the fastest path to both iOS and Android with a shared codebase for business logic, API clients, state management, navigation, and design tokens.
4. Expo's managed workflow eliminates the majority of native configuration overhead, which is critical for a small team.
5. When needed, Expo's bare workflow or custom native modules can handle QR scanning (camera), push notifications, biometrics, and background sync.

**This is NOT a recommendation to rebuild the web portal.** The web portal remains the primary desktop experience. The native apps are a **companion channel** optimized for mobile-first workflows.

### 1.4 Critical Risks Identified

| Risk | Severity | Detail |
|---|---|---|
| Gate approval polling on mobile | **CRITICAL** | Background JS throttling in iOS Safari kills the 30s polling loop; guards and residents will miss approvals |
| No push notification infrastructure | **HIGH** | All real-time alerts currently rely on polling or WhatsApp (external); no FCM/APNs integration exists |
| GitHub doc store latency | **HIGH** | Document commits to GitHub are synchronous and can take 2–8 seconds; mobile upload UX will suffer without queueing |
| Cookie-based auth incompatible with native | **HIGH** | Current auth uses `Set-Cookie` session cookies which don't work in React Native fetch without custom handling |
| No API versioning | **MEDIUM** | All routes are under `/api/v1/` but there is no version negotiation header or version lifecycle policy |
| 60-second Vercel function timeout | **MEDIUM** | Slow connections on mobile networks can hit this limit for large document uploads |
| No API pagination contract | **MEDIUM** | Pagination params (`page`, `limit`) exist per-route but no standardized envelope; mobile clients must adapt per-endpoint |
| Service worker is a stub | **LOW** | Basic offline detection only; no cache strategy means the app fails entirely offline |

---

## 2. CURRENT STATE ASSESSMENT

### 2.1 Architecture Audit

#### 2.1.1 Dual-Config Astro Setup

```
┌─────────────────────────────────────────────────────────┐
│                     PUBLIC WEBSITE                       │
│              astro.config.mjs → docs/                    │
│         GitHub Pages · utamacs.org · Static HTML        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                    RESIDENT PORTAL                       │
│         astro.portal.config.mjs → Vercel SSR            │
│      portal.utamacs.org · Hybrid · 200+ API Routes      │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │Astro SSR │  │React 18  │  │Vanilla JS│              │
│  │(89 pages)│  │(dashboards)│ │(all UX)  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              SUPABASE                             │   │
│  │  Auth (JWT) · PostgreSQL · RLS · Functions       │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │         GITHUB DOCS REPO (private)               │   │
│  │  All user uploads · PDF · Images · KYC docs      │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Resend  │  │ WhatsApp │  │  Upstash │              │
│  │  (email) │  │   API    │  │  (rate   │              │
│  │          │  │          │  │  limit)  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
└─────────────────────────────────────────────────────────┘
```

#### 2.1.2 Routing Architecture

**Pattern:** File-based routing via Astro. Every `.astro` file in `src/pages/portal/` becomes an SSR page. Every `.ts` file in `src/pages/api/v1/` becomes a serverless API function.

**Key observations:**
- Dynamic routes use `[id].astro` / `[id].ts` pattern
- No API gateway — Vercel routes directly to each function
- Each API route imports auth middleware independently (no centralized middleware pipeline)
- The Astro `middleware.ts` exists but only handles security headers (HSTS, CSP, X-Frame-Options)

**Mobile implication:** The API is perfectly consumable by a native mobile app. Each route is a clean REST endpoint. However, the lack of a centralized request pipeline means API behavior can be inconsistent across routes (some may miss rate limiting, some may have different error shapes).

#### 2.1.3 Authentication System — Detailed Analysis

**Current flow:**
```
Browser Login
  → POST /api/v1/auth/login
  → Supabase signInWithPassword()
  → Set-Cookie: sb-access-token + sb-refresh-token (HttpOnly)
  → resolveFromRequest() reads cookies on every SSR page
  → JWT validated server-side for every API call
```

**Mobile incompatibility:**
- `HttpOnly` cookies are inaccessible to React Native's `fetch` API
- React Native's `@react-native-async-storage/async-storage` must be used instead
- The Supabase JS client supports React Native via `AsyncStorage` adapter — this is the correct migration path
- Token refresh: current `/api/v1/auth/refresh` endpoint should be usable, but mobile needs auto-refresh interceptor

**Recommended mobile auth flow:**
```
React Native App
  → supabase-js with AsyncStorage adapter
  → signInWithPassword() or OTP (phone number)
  → Tokens stored in SecureStore (Expo) / Keychain (iOS) / EncryptedSharedPreferences (Android)
  → Auto-refresh before expiry (supabase-js handles this natively)
  → Pass Authorization: Bearer <token> header to all API calls
  → Server validates via Supabase JWT verification (existing resolveFromRequest can be adapted)
```

**Required server change:** `resolveFromRequest()` must accept both `Cookie: sb-access-token` (web) and `Authorization: Bearer <token>` (mobile) — a simple OR condition, non-breaking.

#### 2.1.4 Permission System Analysis

The 3-layer RBAC is extremely well-designed and directly translatable to mobile:

```
Layer 1: DEFAULT_ROLE_PERMISSIONS (hardcoded TypeScript Map)
Layer 2: feature_permissions table (role-level DB overrides)
Layer 3: user_feature_overrides table (user-level grants/revocations)
```

**Mobile strategy:**
- Fetch the resolved permission set once after login from a new `/api/v1/auth/me/permissions` endpoint (or extend `/api/v1/members/me`)
- Cache in SecureStore with a 15-minute TTL
- Use permission checks for UI gating (show/hide) — same semantic as current `hasFeature()`
- Server always enforces the real permissions — client-side is UX only

#### 2.1.5 State Management Assessment

**Current web portal:** Zero shared state management. Each Astro page fetches its own data in the SSR frontmatter. Client-side state is managed by vanilla JS module-scope variables (tabs, modal open state, form state).

**This is actually a strength for mobile migration:** There is no Vuex/Redux/Zustand store to migrate. Mobile gets to design state management from scratch using modern patterns (Zustand for local state + React Query for server state).

#### 2.1.6 Real-Time Systems Assessment

| System | Current Implementation | Mobile Risk |
|---|---|---|
| Gate approval countdown | JS `setInterval(10000)` polling | **CRITICAL** — iOS kills background tabs after 30s |
| Notification badge count | `setInterval(30000)` polling | **HIGH** — Battery drain; misses updates |
| Community post reactions | Page refresh required | **LOW** — Acceptable |
| Facility booking conflicts | Checked server-side on submit | **LOW** — Acceptable |
| HOTO status updates | Page refresh required | **LOW** — Acceptable |

**The gate approval system is the most urgent architectural concern.** A guard or resident who has the browser in background when a gate request comes in will miss the 10-minute window entirely on mobile. This mandates push notifications before native apps launch.

#### 2.1.7 Document Upload Architecture

The GitHub document store is architecturally sound but has mobile-specific performance characteristics:

**GitHub API upload flow:**
1. Mobile app → multipart POST to `/api/v1/{module}/{id}/upload`
2. Vercel function → reads file bytes from multipart
3. Vercel function → base64 encodes → GitHub API PUT (creates commit)
4. GitHub API → 2–8 seconds round-trip depending on file size
5. Vercel function → returns `githubPath`
6. Mobile app → receives response and updates UI

**Mobile risks:**
- Mobile networks can pause mid-upload; no retry mechanism exists
- 60-second Vercel function timeout can be hit on large files over slow connections
- No upload progress reporting (no streaming from Vercel to client)
- Resumable uploads are not supported

**Required improvements before mobile launch:**
1. Background upload queue with `expo-background-fetch`
2. Progress tracking via chunked upload or polling a job ID
3. Retry with exponential backoff on network failure

#### 2.1.8 Notification Architecture

| Channel | Status | Notes |
|---|---|---|
| In-app (DB-based) | Active | Polled every 30s; read-on-click |
| Email (Resend) | Active | Templates for complaints, dues, events |
| WhatsApp | Active (feature-flagged) | Graph API v19.0; WABA configured |
| SMS | Stub (feature-flagged) | Provider key in env, not yet wired |
| Push (FCM/APNs) | **NOT IMPLEMENTED** | Critical gap for mobile |

**Required for mobile:**
1. FCM (Firebase Cloud Messaging) for Android push notifications
2. APNs (Apple Push Notification Service) for iOS
3. Expo Notifications SDK as the unified cross-platform abstraction
4. Supabase Realtime subscription as an alternative to polling (already included in Supabase subscription)

#### 2.1.9 Feature Flag System

The current system uses a `feature_flags` table with `module_key` + `is_active` per `society_id`. The `FeatureFlagService` checks these at request time.

**Mobile integration:**
- Add `platform` column to `feature_flags` (`web`, `android`, `ios`, `all`) — allows rolling out modules separately per platform
- Fetch effective flags on app launch and cache for 15 minutes
- Override capability: server-side still enforces; client uses cached flags for UX

### 2.2 Feature Parity Matrix

| Module | Web Maturity | Mobile Priority | Mobile UX Transformation Needed |
|---|---|---|---|
| Login / Auth | ✅ Production | P0 | Biometric, OTP login option |
| Member Profile | ✅ Production | P0 | Avatar camera, profile editing |
| Complaints | ✅ Production | P0 | Photo attachment from camera, push update |
| Notices | ✅ Production | P0 | Push notification on new notice |
| Finance / Dues | ✅ Production | P0 | Payment recording, receipt download |
| Visitor Passes | ✅ Production | P0 | QR generation, NFC share (future) |
| Gate Approval | ✅ Production | **P0 CRITICAL** | Push notification replaces polling |
| Facility Booking | ✅ Production | P1 | Calendar picker, native date/time |
| Community Board | ✅ Production | P1 | Pull-to-refresh, camera images |
| Notifications | ✅ Production | P0 | Native push; unread badge on app icon |
| Parking | ✅ Production | P1 | — |
| Gallery | ✅ Production | P1 | System photo picker |
| Events | ✅ Production | P1 | Push event reminders |
| Polls / Voting | ✅ Production | P1 | Native radio/checkbox UI |
| Maids Registry | ✅ Production | P2 | Guard: quick lookup by name |
| Documents | ✅ Production | P2 | Native file picker, PDF viewer |
| Vendors | ✅ Production | P2 | Exec only |
| HOTO Tracker | ✅ Production | P2 | Exec/board only |
| Snag List | ✅ Production | P2 | Camera for snag photos |
| Water Tankers | ✅ Production | P2 | — |
| Security Patrol | ✅ Production | P1 | Guard: GPS checkpoint (future) |
| Tenant KYC | ✅ Production | P2 | Document scanner |
| Letters | ✅ Production | P3 | Exec only |
| AGM | ✅ Production | P3 | — |
| Staff Management | ✅ Production | P2 | Staff portal separate app (future) |
| Admin Tools | ✅ Production | P3 | Web-only acceptable |
| Analytics | ✅ Production | P3 | Summary widgets only on mobile |

**Priority Legend:**
- **P0** — Must have at launch (without this, the app is not useful)
- **P1** — Should have for v1.0 (feature-complete experience)
- **P2** — Nice to have for v1.0 (exec/admin workflows)
- **P3** — Deferred to v2.0 (complex, web is sufficient)

### 2.3 Technical Debt Assessment

| Debt Item | Severity | Mobile Impact | Resolution |
|---|---|---|---|
| Cookie-only auth | HIGH | Breaks native apps | Add Bearer token support to `resolveFromRequest()` |
| Polling-based real-time | HIGH | Battery drain; reliability | FCM/APNs + Supabase Realtime |
| No upload progress | MEDIUM | Poor UX on slow mobile | Background upload with progress events |
| No API pagination envelope | MEDIUM | Inconsistent client code | Standardize `{ data, count, page, limit }` response shape |
| Service worker stub | MEDIUM | App fails offline | Implement cache strategy |
| No API versioning header | MEDIUM | Breaking changes crash old app | Add `X-API-Version: 1` header acceptance |
| MIME validation (server-only) | LOW | OK — correct design | Mobile must also validate before upload |
| 30s polling in sidebar | LOW | Battery drain on web too | Replace with Supabase Realtime channel |
| JS camera (jsQR in browser) | LOW | Works in PWA; native is better | React Native Camera for QR scanning |
| No error retry in API calls | LOW | Worse on mobile networks | Add retry interceptor to API client |

### 2.4 Migration Risk Matrix

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Auth token incompatibility | High | Critical | Add Bearer token path before mobile launch |
| Gate approval push failure | High | Critical | FCM integration + server-side push triggers |
| Upload timeout on mobile | Medium | High | Background task + Vercel function segmentation |
| API shape inconsistency | Medium | Medium | Document and test all API responses |
| Offline data loss | Medium | High | Offline queue with conflict resolution |
| App store rejection | Low | High | Privacy manifest (iOS 17+), DPDPA consent screen |
| Deep link handling | Low | Medium | Universal Links (iOS) + App Links (Android) |
| Font/icon rendering | Low | Low | Bundle Inter+Poppins; use vector icons |

---

## 3. GAPS & RISKS

### 3.1 Infrastructure Gaps

#### 3.1.1 Push Notification Infrastructure — MISSING (P0)

The single most critical missing piece. Without push notifications:
- Gate approval workflows fail on mobile (users miss the 10-minute window)
- Residents don't know about new notices, due date reminders, or complaint updates
- The app becomes a pull-based experience, not a push-based one

**What's needed:**
1. Firebase project (free tier sufficient) — provides FCM for Android + relay for APNs
2. APNs certificate from Apple Developer account
3. Expo Push Notifications SDK on the client side
4. A new API endpoint: `POST /api/v1/notifications/push/register` (stores device token)
5. Server-side push dispatch integrated into existing `NotificationDispatcher`
6. A `device_push_tokens` table in Supabase

#### 3.1.2 WebSocket / Realtime — PARTIALLY AVAILABLE

Supabase includes Realtime (PostgreSQL CDC via WebSocket) as part of the subscription. It's currently unused in the portal (polling is used instead).

**Opportunity:** Replace all polling with Supabase Realtime subscriptions:
- `notification_logs` → mobile badge count update
- `visitor_gate_requests` → real-time gate approval countdown
- `complaint_status_changes` → live complaint updates

This eliminates battery-draining polling entirely.

#### 3.1.3 API Gateway — MISSING

Each Vercel serverless function is independently deployed. There is no:
- Centralized rate limiting (Upstash is per-function, not global)
- API versioning middleware
- Request correlation ID propagation
- Global timeout policy

**Mobile risk:** A misbehaving client (or bot) can hammer individual endpoints that lack rate limiting. For mobile, also consider that every app update becomes a new API consumer — version negotiation is essential.

#### 3.1.4 CDN for User-Uploaded Media — INDIRECT

The GitHub download URLs for uploaded files are pre-signed AWS S3 URLs (GitHub's CDN) with 1-hour expiry. This is fine for documents but suboptimal for images:

- Gallery photos, community post images, and event banners are served through GitHub's CDN
- These URLs expire every hour — the mobile app must re-fetch the URL before display
- No image resizing or format optimization (no WebP/AVIF conversion)

**Mobile recommendation:** Consider Cloudflare Images or Supabase Edge Functions as an image transformation proxy that adds `?w=400&format=webp` parameters to optimize images for mobile resolutions.

#### 3.1.5 Background Sync — MISSING

On mobile, users upload complaint attachments, log maid attendance, and record expenses. If the network drops mid-form, the data is lost. The web portal has no offline queue; it simply shows an error.

**Required:** A persistent offline queue (using SQLite via Expo SQLite or MMKV) that stores pending mutations and replays them when connectivity is restored.

### 3.2 Architectural Anti-Patterns Discovered

#### 3.2.1 Vanilla JS State Management at Scale

The portal uses module-scope JS variables (`let currentTab = 'dues'`, `let filteredComplaints = []`) and mutates the DOM directly. This is fine for the web (where the entire page re-renders from SSR on navigation) but completely inappropriate for mobile.

**Impact on mobile:** None — mobile starts fresh with React Native and proper state management. But it confirms that **zero business logic lives in the web UI layer** — it all lives in the API. This is actually ideal for mobile migration.

#### 3.2.2 No API Response Envelope Standard

Different endpoints return different shapes:
- Some return: `{ data: [...], count: N }` 
- Some return: `[...]` (bare array)
- Some return: `{ dues: [...], summary: {...} }`

This forces mobile clients to handle per-endpoint shapes rather than a generic list handler.

**Recommendation:** Adopt a standard envelope for all list endpoints:
```json
{
  "data": [...],
  "meta": {
    "total": 100,
    "page": 1,
    "limit": 20,
    "has_more": true
  }
}
```

This is a **non-breaking change** if done carefully (add `meta` alongside existing fields first).

#### 3.2.3 Synchronous GitHub Document Commits

The `commitDocument()` function makes a synchronous HTTP call to the GitHub API and awaits completion before returning. This means:
- Upload API route blocks for 2–8 seconds per file
- No retry on transient GitHub API failure
- No queue or async processing

**Mobile UX impact:** An 8-second API call on a mobile upload is unacceptable. Users will abandon and retry, causing duplicate commits.

**Recommendation:** Queue document commits in a Supabase table (`document_upload_queue`) and process via a background cron job. Return immediately with a pending status and push a notification when complete. This is already partially designed in the HOTO upload queue (`/api/v1/hoto/upload/[queueId]`).

#### 3.2.4 jsQR Library for Camera-Based QR Scanning

The visitor management page uses `jsQR` (a JavaScript library) to decode QR codes from a browser `<video>` stream. This works in a PWA but:
- Requires camera permission in the browser (works but clunky UX)
- Cannot scan in background
- Frame rate limited in browser
- Camera UI is not native

**Native replacement:** `expo-barcode-scanner` or `expo-camera` with QR mode — faster, more reliable, uses native camera APIs, requests permissions the native way.

### 3.3 Security Gaps for Mobile

| Gap | Risk | Mitigation |
|---|---|---|
| No certificate pinning | Medium | SSL pinning via `expo-crypto` + custom TLS config |
| Token stored in AsyncStorage (default) | High | Use `expo-secure-store` (Keychain/EncryptedSharedPreferences) |
| No jailbreak/root detection | Medium | `expo-device` checks + `react-native-root-sibling` |
| Screenshot allowed by default | Low | `expo-screen-capture` to prevent on sensitive screens |
| Clipboard with sensitive data | Low | Auto-clear clipboard after 30s for copied pass codes |
| No app integrity check | Medium | Google Play Integrity API + Apple DeviceCheck |
| MIME validation client-side | Low | Server validates; client should too for UX |

---

## 4. RECOMMENDED ARCHITECTURE

### 4.1 Architecture Decision: React Native with Expo

After evaluating all options (Flutter, Kotlin Multiplatform, React Native, Capacitor/Ionic, Pure Native), the recommendation is:

**React Native + Expo Managed Workflow → Bare Workflow for production**

**Full justification:**

| Criterion | Flutter | KMP | React Native/Expo | Capacitor | Pure Native |
|---|---|---|---|---|---|
| Time to first working app | 3–4 weeks | 8–12 weeks | 1–2 weeks | 1 week | 8–16 weeks (×2 platforms) |
| Code sharing % | 95% | 50% (logic only) | 90% | 85% (web code) | 0% |
| Team ramp-up (JS/TS team) | High (Dart) | High (Kotlin/Swift) | **Low (TypeScript)** | Low | Very High |
| Native feel on iOS | Good | Excellent | Good (with proper libs) | Mediocre | Excellent |
| Native feel on Android | Excellent | Excellent | Good | Mediocre | Excellent |
| Camera/QR | Excellent | Good | **Excellent (expo-camera)** | Good | Excellent |
| Push notifications | Excellent | Good | **Excellent (Expo Push)** | Good | Excellent |
| Biometric | Excellent | Good | **Excellent (expo-local-auth)** | Good | Excellent |
| Background tasks | Good | Excellent | Good (expo-background-fetch) | Limited | Excellent |
| App store tooling | Good | N/A | **Excellent (EAS Build)** | Manual | Manual |
| Offline/SQLite | Excellent | Good | Good (expo-sqlite) | Good | Excellent |
| Performance | **Near-native** | Native | 85–90% native | 60–75% | 100% native |
| Community/ecosystem | Growing | Small | **Largest** | Medium | Mature |

**Why not Flutter:** The team is TypeScript-first. Dart is a full context switch. The web portal codebase has zero Dart. The productivity cost of Dart ramp-up outweighs Flutter's rendering advantages for a residential society app (not a game or animation-heavy experience).

**Why not Capacitor:** It wraps the web portal in a WebView. The web portal is SSR-rendered (server-side HTML) — it doesn't work in a WebView without a server. A fully client-side rewrite in Vue/React would be needed to use Capacitor, which is as much work as React Native but with worse native feel.

**Why not KMP:** This is a pure mobile team recommendation for sharing business logic only. It requires separate UI for Android (Jetpack Compose) and iOS (SwiftUI). With a small team, maintaining two native UI codebases is unsustainable.

**Why React Native/Expo:**
- TypeScript throughout — the entire team can contribute
- Expo EAS Build eliminates Xcode/Gradle complexity for CI/CD
- Expo Push Notifications is the fastest path to FCM/APNs
- `expo-camera`, `expo-barcode-scanner`, `expo-local-authentication`, `expo-secure-store` cover all critical native features
- The API layer is already 100% mobile-ready (REST/JSON)
- EAS Update enables over-the-air JS updates (critical for bug fixes without app store review)
- Large community, well-maintained, Meta-backed

### 4.2 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                                     │
│                                                                          │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────┐  │
│  │   Android App       │  │     iOS App          │  │  Web Portal    │  │
│  │   (React Native)    │  │   (React Native)     │  │  (Astro SSR)   │  │
│  │   EAS Build         │  │   EAS Build          │  │  Vercel        │  │
│  └─────────┬───────────┘  └──────────┬───────────┘  └───────┬────────┘  │
│            │                         │                       │           │
│            └─────────────┬───────────┘                       │           │
│                          │ shared API client                 │           │
└──────────────────────────┼───────────────────────────────────┼───────────┘
                           │                                   │
┌──────────────────────────┼───────────────────────────────────┼───────────┐
│                   API GATEWAY LAYER                          │           │
│                                                              │           │
│  ┌──────────────────────────────────────────────────────┐   │           │
│  │            Vercel Edge Network                        │   │           │
│  │  ┌────────────────┐  ┌────────────────┐             │   │           │
│  │  │  Rate Limiting  │  │  Auth Middleware│             │   │           │
│  │  │  (Upstash Redis)│  │  (JWT/Bearer)  │             │   │           │
│  │  └────────────────┘  └────────────────┘             │   │           │
│  └──────────────────────────────────────────────────────┘   │           │
│                                                              │           │
│  ┌──────────────────────────────────────────────────────┐   │           │
│  │              API v1 Routes (200+)                     │←──┘           │
│  │  /auth/* /members/* /finance/* /complaints/*  ...    │               │
│  └──────────────────────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────────────────┐
│                   BACKEND SERVICES LAYER                                 │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │    Supabase     │  │   GitHub Docs   │  │  Notification   │         │
│  │  Auth · DB · RT │  │   (file store)  │  │  Dispatcher     │         │
│  │  PostgREST · RLS│  │   Private repo  │  │  FCM·APNs·WA·SMS│         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │  Resend (email) │  │  Upstash Redis  │  │  Firebase (FCM) │         │
│  │                 │  │  (rate limit)   │  │  (push gateway) │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Mobile App Architecture — Clean Architecture

Each native app (Android + iOS via React Native) follows Clean Architecture with these layers:

```
┌─────────────────────────────────────────────┐
│              PRESENTATION LAYER              │
│  Screens · Navigators · UI Components       │
│  Zustand stores (UI state)                  │
│  React Query (server state + cache)         │
└──────────────────┬──────────────────────────┘
                   │ calls
┌──────────────────▼──────────────────────────┐
│             USE CASES LAYER                  │
│  Business logic (auth, permissions,          │
│  offline queue, sync, notifications)         │
│  Defined in shared-components/               │
└──────────────────┬──────────────────────────┘
                   │ calls
┌──────────────────▼──────────────────────────┐
│            REPOSITORY LAYER                  │
│  ApiRepository (REST calls)                 │
│  LocalRepository (SQLite / MMKV)            │
│  SyncRepository (offline queue)             │
│  Defined in shared-components/              │
└──────────────────┬──────────────────────────┘
                   │ calls
┌──────────────────▼──────────────────────────┐
│           DATA SOURCES LAYER                 │
│  ApiClient (axios + interceptors)           │
│  SupabaseClient (supabase-js)               │
│  SQLiteDatabase (expo-sqlite)               │
│  SecureStorage (expo-secure-store)          │
└─────────────────────────────────────────────┘
```

### 4.4 State Management Architecture

**Server state:** React Query (TanStack Query) — handles caching, background refetch, optimistic updates, pagination, and stale-while-revalidate. This is the primary data layer for all API calls.

**Local UI state:** Zustand — lightweight, TypeScript-first, no boilerplate. Used for:
- Auth state (current user, permissions)
- Navigation state (active tab, drawer open)
- Form state (draft complaints, draft posts)
- Feature flags cache
- Offline queue length (badge indicator)

**Persistent state:** expo-secure-store for tokens; expo-sqlite for offline queue; MMKV for fast non-sensitive preferences.

**Real-time state:** Supabase Realtime channels — replaces all polling. Subscriptions mounted on app foreground, cleanly torn down on background.

```
API Data (React Query)
  ├── Complaints list → queryKey: ['complaints', filters]
  ├── Finance dues → queryKey: ['finance', 'dues', period]
  ├── Visitor passes → queryKey: ['visitor-passes', userId]
  └── Notifications → queryKey: ['notifications', page]

UI State (Zustand)
  ├── authStore: { user, permissions, isAdmin }
  ├── featureFlagStore: { flags, lastFetched }
  ├── offlineQueueStore: { pendingCount, items }
  └── notificationStore: { unreadCount }

Realtime (Supabase channels)
  ├── visitor_gate_requests → invalidate React Query cache + push UI update
  ├── notification_logs → update unread count in Zustand
  └── complaint_status → invalidate complaint detail cache
```

### 4.5 Navigation Architecture

**Library:** Expo Router (file-based routing, same mental model as Astro) — chosen over React Navigation for its:
- File-based routing maps well to the existing portal route structure
- Built-in deep linking support via Universal Links / App Links
- TypeScript-native route types
- Works seamlessly with Expo EAS

**Navigation structure:**
```
app/
├── (auth)/
│   ├── login.tsx
│   ├── forgot-password.tsx
│   └── reset-password.tsx
├── (tabs)/                          ← Bottom tab navigator (5 tabs)
│   ├── home/
│   │   └── index.tsx               ← Dashboard (member or exec)
│   ├── complaints/
│   │   ├── index.tsx               ← Complaint list
│   │   ├── new.tsx                 ← New complaint form
│   │   └── [id].tsx                ← Complaint detail + comments
│   ├── notices/
│   │   ├── index.tsx
│   │   └── [id].tsx
│   ├── finance/
│   │   └── index.tsx
│   └── more/
│       └── index.tsx               ← All other modules
├── visitors/
│   ├── index.tsx
│   ├── new-pass.tsx
│   └── pass/[token].tsx            ← QR pass view (deep link)
├── community/
│   ├── index.tsx
│   ├── [id].tsx
│   └── new.tsx
├── facilities/
│   ├── index.tsx
│   └── book.tsx
└── [module]/                       ← All P1/P2 modules
    └── index.tsx
```

**Bottom Tab Bars (role-aware):**
- **Member:** Home · Complaints · Notices · Finance · More
- **Executive:** Home · Complaints · Finance · Vendors · More
- **Security Guard:** Gate · Scan QR · Visitors · More (simplified app)

---

## 5. SHARED VS NATIVE STRATEGY

### 5.1 What Lives in `/utamacs-apps/shared-components`

The shared-components package is a TypeScript library (`@utamacs/shared`) consumed by both Android and iOS builds. It contains everything that is platform-agnostic:

#### 5.1.1 API Client Layer

```typescript
// packages/api-client/src/client.ts
// Axios instance with:
// - Base URL configuration
// - Bearer token injection (reads from SecureStore)
// - Auto token refresh on 401
// - Retry with exponential backoff (3 retries, 500/1000/2000ms)
// - Request correlation ID header (X-Request-ID)
// - API version header (X-API-Version: 1)
// - Offline detection (queue if offline)
// - Error normalization (RFC 7807 → typed errors)
```

#### 5.1.2 Repository Interfaces + Implementations

```
shared-components/
  src/
    repositories/
      auth/
        AuthRepository.ts          ← login, logout, refresh, me
        AuthRepository.types.ts
      complaints/
        ComplaintsRepository.ts
        ComplaintsRepository.types.ts
      finance/
        FinanceRepository.ts
      visitors/
        VisitorsRepository.ts
      members/
        MembersRepository.ts
      notifications/
        NotificationsRepository.ts
      ... (one per API domain)
```

#### 5.1.3 Business Logic Use Cases

```
shared-components/
  src/
    usecases/
      auth/
        LoginUseCase.ts
        LogoutUseCase.ts
        RefreshTokenUseCase.ts
      permissions/
        CheckPermissionUseCase.ts
        FetchPermissionsUseCase.ts
      offline/
        QueueMutationUseCase.ts
        ReplayOfflineQueueUseCase.ts
      notifications/
        RegisterPushTokenUseCase.ts
        HandleIncomingPushUseCase.ts
```

#### 5.1.4 Design Tokens

```typescript
// shared-components/src/design/tokens.ts
export const colors = {
  primary: { 50: '#EFF6FF', 600: '#1E3A8A' },
  secondary: { 500: '#10B981' },
  accent: { 500: '#F59E0B' },
  text: { primary: '#111827', secondary: '#4B5563' },
  background: '#FFFFFF',
  border: '#E5E7EB',
  danger: { 100: '#FEE2E2', 500: '#EF4444', 600: '#DC2626' },
} as const;

export const typography = {
  fontFamily: { display: 'Poppins-Bold', body: 'Inter-Regular', medium: 'Inter-Medium' },
  size: { xs: 11, sm: 13, base: 15, lg: 17, xl: 19, '2xl': 24, '3xl': 30 },
  lineHeight: { tight: 1.2, normal: 1.5, relaxed: 1.75 },
} as const;

export const spacing = {
  xs: 4, sm: 8, md: 12, lg: 16, xl: 20, '2xl': 24, '3xl': 32, '4xl': 48,
} as const;

export const radius = {
  sm: 6, md: 8, lg: 12, xl: 16, full: 9999,
} as const;

export const shadow = {
  soft: { shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.05, shadowRadius: 4, elevation: 2 },
  medium: { shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.1, shadowRadius: 8, elevation: 4 },
  large: { shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.15, shadowRadius: 16, elevation: 8 },
} as const;
```

#### 5.1.5 Shared Type Definitions

All Supabase database types (`database.types.ts`) are imported into shared-components and re-exported as domain types consumed by both apps.

#### 5.1.6 Analytics Contracts

```typescript
// shared-components/src/analytics/events.ts
export type AnalyticsEvent =
  | { name: 'complaint_created'; properties: { category: string; unit: string } }
  | { name: 'visitor_pass_created'; properties: { duration_hours: number } }
  | { name: 'payment_recorded'; properties: { amount: number; mode: string } }
  | { name: 'qr_scanned'; properties: { result: 'valid' | 'expired' | 'invalid' } }
  | { name: 'notification_opened'; properties: { type: string; latency_seconds: number } }
  // ... exhaustive event registry
```

#### 5.1.7 Mock Data / Test Fixtures

Shared test fixtures and factory functions for both app test suites.

### 5.2 What is Platform-Native

| Concern | Android | iOS | Rationale |
|---|---|---|---|
| Push notification handling | FCM receiver | APNs delegate | Platform APIs differ |
| Biometric auth | Fingerprint/Face (BiometricPrompt) | Face ID/Touch ID (LAContext) | APIs differ |
| File system access | Android file picker | iOS document picker | APIs differ |
| Background tasks | WorkManager | BGTaskScheduler | APIs differ |
| App shortcuts | Android Shortcuts API | Siri Shortcuts (future) | APIs differ |
| Widgets | App Widgets (future) | WidgetKit (future) | Complex, deferred |
| Barcode camera UI | CameraX | AVFoundation | Expo abstracts both |
| Notification sounds | .ogg / .mp3 | .aiff / .caf | File format differs |
| Payment integration | Google Pay (future) | Apple Pay (future) | Compliance-heavy, deferred |

In practice, **Expo abstracts almost all of the above** through its SDK. The platform-native code is the Expo native modules themselves, not code you write. The apps share 90%+ of their TypeScript code.

### 5.3 Shared vs Platform Code Split

```
shared-components/          ← 100% shared
  API client                 ← 100%
  Business logic            ← 100%
  Design tokens             ← 100%
  Type definitions          ← 100%
  Analytics contracts       ← 100%
  Offline queue logic       ← 100%
  Permission resolution     ← 100%

android-app/                ← ~10% unique
  Platform: native modules that Expo doesn't abstract (future)
  Build: EAS Android config, google-services.json
  Assets: Android-specific splash screen, adaptive icon

ios-app/                    ← ~10% unique
  Platform: native modules (future)
  Build: EAS iOS config, Info.plist, entitlements
  Assets: iOS-specific splash screen, app icons

Both apps share:
  All screens (TSX components)       ← 95%
  All navigators                     ← 95%
  All business logic hooks           ← 100%
  All API calls                      ← 100%
  All design system components       ← 95%
```

---

## 6. UI/UX STRATEGY

### 6.1 Mobile UX Transformation Principles

The web portal is a **desktop-first management system** adapted for mobile. The native apps must be **mobile-first** from the ground up. Key transformations:

#### 6.1.1 Navigation Transformation

| Web Pattern | Mobile Pattern | Rationale |
|---|---|---|
| Left sidebar (38 nav items) | Bottom tabs (5) + "More" drawer | Thumb reachability |
| Full table with pagination | Infinite scroll list | Native feel |
| Modal dialogs | Bottom sheets | Platform convention |
| Multi-step forms in modals | Dedicated screens | Breathing room on small screens |
| Drawer panels (right-side) | Native navigation push | iOS/Android convention |
| Tabs within pages | Segmented control / top tabs | Platform native |
| Inline date pickers | Native date picker sheet | Platform native |

#### 6.1.2 Information Architecture

**Resident (member) app:**
```
Home
  ├── Quick stats (dues status, unread notifications, open complaints)
  ├── Upcoming events (2 cards)
  ├── Recent notices (3 cards)
  └── Gate approval alert (if pending)

Complaints
  ├── My complaints (grouped by status)
  └── [FAB] → New complaint

Notices
  └── All notices (paginated, acknowledge inline)

Finance
  ├── Current dues (amount, due date, status)
  ├── Payment history (list)
  └── Record payment (exec gate)

More
  ├── Visitor Passes
  ├── Facilities
  ├── Community Board
  ├── Polls
  ├── Parking
  ├── Gallery
  ├── Documents
  ├── Water Tankers
  ├── Profile
  └── Settings
```

**Executive app (same app, role-aware):**
Additional items in More:
- Vendor Management
- HOTO Tracker
- Snag List
- Staff Management
- Letters
- Analytics

**Security guard (same app, simplified home):**
```
Home
  ├── Gate approval requests (real-time list, push-notified)
  └── Today's visitor log

Scan QR
  └── Camera viewfinder → scan pass → show valid/invalid

Visitors
  └── All active visitors + log entry form

More
  └── Maids directory, Deliveries, Patrol log
```

#### 6.1.3 Key UX Redesigns

**Gate Approval (Most Critical Redesign):**

Web: Resident sees amber banner → clicks to open request → approves/rejects.
**Native:** Resident receives push notification → taps → full-screen gate request card with photo of visitor (if available), unit info, and large APPROVE / REJECT buttons. Timer shows remaining seconds. Haptic feedback on approve/reject.

**Complaint Filing (Major Redesign):**

Web: Long form in modal (category, subcategory, description, attachments, priority).
**Native:** Conversational step-by-step flow:
1. Screen 1: "What's broken?" → Category grid (large icons: Electrical, Plumbing, Civil, Housekeeping, Security, Other)
2. Screen 2: "Where?" → Unit auto-filled, location free text optional
3. Screen 3: "Describe it" → Text area + attach photo from camera or gallery
4. Screen 4: Review → Submit with haptic confirmation

**Finance Dues (Simplified for Mobile):**

Web: Full table with billing periods, amounts, GST breakdown, actions.
**Native:**
- Large card at top: "₹XXXX due by DD MMM" (red if overdue, green if paid)
- Timeline below: history of payments
- Floating button: "Record payment" (exec only) or "Download receipt"

**QR Visitor Pass:**

Web: Generate and share as image or OTP code.
**Native:** Same, plus:
- Widget shortcut to show current active pass
- NFC share (future — Expo NFC)
- Haptic feedback when guard scans

### 6.2 Design System

#### 6.2.1 Component Library

Built on top of the shared tokens, using React Native's built-in primitives + `@gorhom/bottom-sheet` + `react-native-reanimated 3`.

**Core components (in shared-components/src/ui):**

```
Button           ← primary, secondary, outline, ghost, danger, loading state
Card             ← premium, feature, stats (maps to CSS card classes)
Input            ← text, number, textarea, with error state
Select           ← native picker sheet (bottom sheet on iOS, spinner on Android)
Badge            ← status badges (pending/open/resolved/overdue colors)
Avatar           ← with fallback initials, online indicator
EmptyState       ← icon + title + description + CTA
ErrorState       ← retry button + error message
LoadingState     ← skeleton shimmer (maps to shimmer animation in tailwind.config)
Toast            ← bottom-anchored, auto-dismiss, success/error/warning
BottomSheet      ← confirmation dialogs, detail panels, form sheets
ListItem         ← chevron, icon, badge, subtitle
SectionHeader    ← section title with optional action
SearchBar        ← native search input with debounce
DatePicker       ← native date picker sheet
FileUploader     ← camera, gallery, document picker with progress
QRDisplay        ← QR code rendering (react-native-qrcode-svg)
QRScanner        ← camera viewfinder with scan feedback
```

#### 6.2.2 Dark Mode

Full dark mode support using React Native's `useColorScheme()` and the design token system:
- Design tokens have light + dark values
- Token lookup resolves to correct value based on current scheme
- User preference override stored in MMKV (persists across launches)
- System default honored if no override

#### 6.2.3 Typography

Fonts bundled in the app (no CDN dependency):
- Inter: Regular (400), Medium (500), SemiBold (600), Bold (700)
- Poppins: Bold (700) for headings only

Loaded via `expo-font` at app startup. Splash screen shown until fonts are loaded.

#### 6.2.4 Accessibility

- Minimum touch target: 44×44pt (Apple HIG) / 48×48dp (Material)
- All interactive elements have `accessibilityLabel` and `accessibilityHint`
- Screen reader (VoiceOver / TalkBack) support for all lists and forms
- Dynamic Type support (iOS) — font sizes scale with system accessibility settings
- Color contrast ratio: all text meets WCAG AA (4.5:1 minimum)
- Focus management: keyboard navigation order logical
- Reduced motion: animations disabled when `AccessibilityInfo.isReduceMotionEnabled()`

#### 6.2.5 Motion System

- **Micro-interactions:** React Native Reanimated 3 worklets (runs on UI thread — no JS bridge jank)
- **Page transitions:** Expo Router's native stack transitions (slide on iOS, fade-up on Android)
- **List animations:** `react-native-reanimated` layout animations for list add/remove
- **Skeleton loading:** Animated shimmer (matches web's CSS shimmer keyframe)
- **Haptics:** `expo-haptics` — selection feedback on taps, success/error on form submit, impact on gate approve/reject
- **Performance budget:** No animation > 16ms frame time; all animations tested on low-end devices

#### 6.2.6 Gesture System

- Pull-to-refresh on all list screens
- Swipe to dismiss bottom sheets
- Swipe list item to reveal actions (archive, delete where applicable)
- Long press for context menus (copy complaint ID, share notice)
- Pinch-to-zoom in gallery viewer
- Double-tap to like community posts

---

## 7. BACKEND & API READINESS

### 7.1 API Mobile Readiness Assessment

| API Domain | Mobile Ready | Issues | Priority Fix |
|---|---|---|---|
| Auth | ⚠️ 70% | Cookie-only; no Bearer support | P0 |
| Members | ✅ 85% | DPDPA phone masking good; need `/me/permissions` | P0 |
| Complaints | ✅ 90% | Good pagination; need upload progress | P1 |
| Finance | ✅ 85% | Good; PDF receipt needs download handling | P0 |
| Visitors | ⚠️ 75% | Gate approval needs push trigger | P0 |
| Facilities | ✅ 80% | Need calendar slot availability endpoint | P1 |
| Notifications | ⚠️ 50% | No push token registration | P0 |
| Community | ✅ 85% | Good; image upload needs progress | P1 |
| Polls | ✅ 95% | Excellent for mobile | P1 |
| Documents | ✅ 80% | PDF viewer needs signed URL | P1 |
| Gallery | ✅ 80% | Image sizes need optimization | P1 |
| Maids | ✅ 80% | Good | P2 |
| Vendors | ✅ 80% | Good; exec-only | P2 |
| HOTO | ✅ 80% | Good; exec-only | P2 |
| Snags | ✅ 80% | Camera attachment good | P2 |
| Parking | ✅ 80% | Good | P1 |

### 7.2 Required API Changes Before Mobile Launch

#### 7.2.1 P0 Changes (Launch Blockers)

**1. Bearer Token Authentication**
```typescript
// Current (src/lib/permissions.ts)
export async function resolveFromRequest(request: Request, societyId: string) {
  const cookie = request.headers.get('cookie');
  // ... cookie parsing
}

// Required addition:
export async function resolveFromRequest(request: Request, societyId: string) {
  // Try Authorization header first (mobile)
  const authHeader = request.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    return resolveFromToken(token, societyId);
  }
  // Fall back to cookie (web)
  const cookie = request.headers.get('cookie');
  // ... existing cookie logic
}
```

**2. Push Token Registration**
```sql
-- New migration: device_push_tokens table
CREATE TABLE device_push_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token text NOT NULL,
  platform text NOT NULL CHECK (platform IN ('expo', 'fcm', 'apns')),
  app_version text,
  os_version text,
  device_model text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(profile_id, token)
);
```

New routes:
- `POST /api/v1/notifications/push/register` — register device token
- `DELETE /api/v1/notifications/push/deregister` — remove on logout

**3. Permissions Endpoint**
```
GET /api/v1/members/me/permissions
→ { role, portalRole, isAdmin, features: string[], committeeTitle, unitId }
```

**4. Gate Approval Push Trigger**
Modify the existing `POST /api/v1/visitors/gate-requests` handler:
- After inserting the gate request, dispatch push notification to the unit owner/resident
- Dispatch uses `NotificationDispatcher` + new `pushToProfile(profileId, notification)` method

**5. Visitor Pass Deep Link**
The `visitor_pass.pass_url` field should use a Universal Link format:
`https://portal.utamacs.org/visitors/pass/{token}` → native app handles on iOS/Android, web browser as fallback

#### 7.2.2 P1 Changes (Pre-Feature Complete)

**6. Standardized Pagination Envelope**

Add `meta` to all list responses without removing existing fields (backward compatible):
```json
{
  "data": [...],
  "count": 47,
  "meta": { "total": 47, "page": 1, "limit": 20, "has_more": true }
}
```

**7. Calendar Availability Endpoint**
```
GET /api/v1/facilities/[id]/availability?start=2026-05-01&end=2026-05-31
→ { available_slots: [{ date, start_time, end_time }], blocked: [...] }
```

**8. Image Size Optimization**
Add `?w=400&format=webp` support to signed URL generation. If using Cloudflare Images or an image proxy, this is a one-line URL transform.

**9. Upload Queue Status**
Generalize the HOTO upload queue pattern to all modules:
```
POST /api/v1/uploads/queue — enqueue a file upload job
GET /api/v1/uploads/queue/[jobId] — poll job status
```

**10. Notification Pagination + Unread Count**
```
GET /api/v1/notifications?page=1&limit=20
→ { data: [...], meta: {...}, unread_count: 5 }
```

### 7.3 Backend for Frontend (BFF) Assessment

**Should we build a BFF?** For this scale (single society, ~200 residents, ~20 executives), a full BFF layer adds maintenance overhead without clear benefit. The existing API is already well-structured for mobile consumption with minor modifications.

**Exception:** Consider a lightweight BFF aggregate for the mobile home screen:
```
GET /api/v1/mobile/home
→ {
    dues_summary: { amount, status, due_date },
    open_complaints: number,
    unread_notifications: number,
    recent_notices: [{ id, title, published_at }],
    upcoming_events: [{ id, title, starts_at }],
    pending_gate_requests: [{ id, visitor_name, requested_at }]
  }
```
This replaces 5 separate API calls on home screen load with a single request — critical for mobile startup performance.

### 7.4 API Versioning Strategy

Adopt now, before mobile launches:
1. All existing routes remain at `/api/v1/` (no disruption)
2. Add `X-API-Min-Version: 1` response header
3. Clients should send `X-App-Version: 1.0.0` and `X-Platform: ios|android|web`
4. When breaking changes are needed, create `/api/v2/` routes in parallel; deprecate v1 with a sunset header
5. Mobile apps check `X-API-Min-Version` on launch; if app version is below minimum, show "Please update" screen

### 7.5 Websocket / Realtime Strategy

Supabase Realtime (already included) provides PostgreSQL CDC via WebSocket. Enable the following channels:

```typescript
// In the mobile app, after login:
const notificationChannel = supabase
  .channel('notifications')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'notification_logs',
    filter: `profile_id=eq.${userId}`,
  }, (payload) => {
    notificationStore.incrementUnread();
    showLocalNotification(payload.new);
  })
  .subscribe();

const gateChannel = supabase
  .channel('gate-requests')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'visitor_gate_requests',
    filter: `unit_id=eq.${unitId}`,
  }, (payload) => {
    // Trigger push notification (handled server-side)
    // Also update in-app gate request list
    queryClient.invalidateQueries(['gate-requests']);
  })
  .subscribe();
```

---

## 8. SECURITY STRATEGY

### 8.1 OWASP Mobile Top 10 Mitigation

| OWASP M# | Risk | Mitigation |
|---|---|---|
| M1: Improper Credential Usage | HIGH | `expo-secure-store` for all tokens (Keychain/EncryptedSharedPreferences); never AsyncStorage for tokens |
| M2: Inadequate Supply Chain Security | MEDIUM | Dependency audit via `npm audit` in CI; Dependabot alerts; pin critical deps |
| M3: Insecure Authentication | HIGH | Biometric + OTP option; PKCE for OAuth; session revocation on logout |
| M4: Insufficient Input/Output Validation | MEDIUM | All server-side (already done); client pre-validates MIME/size before upload |
| M5: Insecure Communication | HIGH | TLS 1.3 enforced; certificate pinning for Supabase and Vercel hosts |
| M6: Inadequate Privacy Controls | HIGH | DPDPA consent screen on first launch; PII fields hidden per role; no logs to crash reporters |
| M7: Insufficient Binary Protections | MEDIUM | ProGuard/R8 (Android); bitcode disabled (iOS); no debug builds in prod |
| M8: Security Misconfiguration | MEDIUM | Environment variables via EAS secrets; no API keys in source code |
| M9: Insecure Data Storage | HIGH | SQLite encrypted (expo-sqlite with SQLCipher); no PII in analytics events |
| M10: Insufficient Cryptography | MEDIUM | Use platform crypto APIs (not JS crypto.subtle for storage); PBKDF2 for local encryption keys |

### 8.2 Authentication Hardening

```
1. Login → OTP option for phone numbers (Supabase OTP via SMS)
2. Biometric unlock (after first password login) → expo-local-authentication
3. Session pinning: if profile_id changes mid-session, force re-login
4. Inactivity timeout: 30 min background → require biometric or PIN
5. Concurrent session detection: server tracks active tokens; new login on different device shows alert
6. Logout: clear SecureStore + revoke Supabase session + deregister push token
```

### 8.3 Secure Storage Architecture

```
expo-secure-store (Keychain/EncryptedSharedPreferences):
  ├── access_token (JWT)
  ├── refresh_token
  ├── biometric_enabled (bool)
  └── device_id (generated UUID, persists across app reinstalls via IDFV)

expo-sqlite (encrypted with SQLCipher):
  ├── offline_queue (pending mutations)
  ├── notification_cache (last 50 notifications)
  └── permission_cache (with TTL timestamp)

MMKV (fast, not encrypted — non-sensitive only):
  ├── last_selected_tab
  ├── dark_mode_preference
  ├── notification_preferences
  └── feature_flags_cache
```

### 8.4 Certificate Pinning

For production builds only (not development — breaks local proxy):
```javascript
// Network security config (Android) + NSExceptionDomains (iOS)
// Pin SHA-256 of Supabase and Vercel certificate public keys
// Rotate pins with 30-day overlap window before cert expiry
// Expo's fetch doesn't support pinning natively — use react-native-ssl-pinning
```

### 8.5 Privacy & DPDPA 2023 on Mobile

**Additional mobile-specific requirements beyond web compliance:**

1. **Privacy Manifest (iOS 17+):** Required for App Store submission; declare all API types (NSPrivacyAccessedAPITypes) used: File timestamp, User defaults, Disk space, System boot time
2. **App Tracking Transparency (iOS):** Required if any cross-app tracking SDK is used (Firebase Analytics). Use `expo-tracking-transparency`.
3. **Consent on First Launch:** Show DPDPA privacy notice before any data collection. Store consent in SecureStore + sync to `privacy_consents` table.
4. **Data Minimization in Crash Reports:** Sentry/Crashlytics — redact all PII before uploading crash reports. Configure `beforeSend` to strip user identifiers.
5. **Screenshot Prevention:** On sensitive screens (member phone numbers, KYC documents, financial details), disable screenshots via `expo-screen-capture`.
6. **Clipboard Hygiene:** Auto-clear OTP/pass codes from clipboard after 60 seconds.

### 8.6 App Hardening

```
Android:
  ├── ProGuard/R8 obfuscation enabled
  ├── Root detection (SafetyNet → Play Integrity API)
  ├── Debuggable: false in release builds
  └── Network security config (clear-text disallowed in prod)

iOS:
  ├── Bitcode: disabled (Apple deprecated)
  ├── Jailbreak detection (heuristic: Cydia, writeable /private/var)
  ├── Allow arbitrary loads: NO
  └── Minimum deployment target: iOS 16 (covers 95%+ of active devices)
```

---

## 9. DEVOPS & INFRASTRUCTURE

### 9.1 CI/CD Pipeline Design

**Platform:** EAS (Expo Application Services) + GitHub Actions

```
GitHub Push / PR
  │
  ▼
GitHub Actions: CI
  ├── Install dependencies (npm ci)
  ├── TypeScript check (tsc --noEmit)
  ├── ESLint + Prettier
  ├── Unit tests (Jest/Vitest)
  ├── API contract tests
  └── Shared-components build check

Merge to main
  │
  ▼
EAS Build (Preview channel)
  ├── Android: .apk (internal testing)
  ├── iOS: Simulator build
  └── Share via EAS Update URL (OTA preview)

Tag: v*.*.* 
  │
  ▼
EAS Build (Production channel)
  ├── Android: .aab (Google Play)
  ├── iOS: .ipa (App Store Connect)
  ├── EAS Submit → automatic store submission
  └── Sentry source maps upload
```

### 9.2 Release Channels

| Channel | Audience | Build Type | Update Method |
|---|---|---|---|
| `development` | Developers | Debug + dev server | Local EAS Dev Client |
| `preview` | Internal testers | Release APK / TestFlight | EAS Update (OTA) |
| `staging` | Beta residents (10–20) | Release | EAS Update (OTA) |
| `production` | All residents | Release | EAS Update (OTA) + Store |

### 9.3 Over-the-Air Updates (EAS Update)

EAS Update allows pushing JavaScript/TypeScript changes without going through app store review. **Critical for:**
- Bug fixes (P1 issues fixed in hours, not weeks)
- Feature flag changes
- UI copy changes
- Non-native code changes (all business logic)

**Policy:**
- Native code changes (new native modules, expo SDK upgrades) → full store release
- JS-only changes → EAS Update to `preview` channel → QA → `production` channel
- Rollback: EAS Update can roll back to previous JS bundle in minutes

### 9.4 Environment Strategy

```
.env.development       ← Local dev; points to Supabase dev project
.env.preview           ← Preview/staging; same Supabase project, test data
.env.production        ← Production; hardened secrets via EAS Secrets

EAS Secrets (encrypted, not in source):
  SUPABASE_URL
  SUPABASE_ANON_KEY
  SENTRY_DSN
  FIREBASE_CONFIG (Android google-services.json)
  APNS_KEY (iOS push key)
```

### 9.5 App Signing & Key Management

```
Android:
  ├── Keystore managed by EAS (recommended) — no local keystore file
  ├── Backup keystore SHA-256 stored in password manager (not git)
  └── Google Play App Signing enabled (Google holds the upload key)

iOS:
  ├── Distribution certificate managed by EAS
  ├── Provisioning profiles auto-managed by EAS
  └── APNs key (.p8) stored in EAS Secrets only
```

### 9.6 Monitoring & Observability Stack

| Concern | Tool | Notes |
|---|---|---|
| Crash reporting | Sentry (React Native) | PII scrubbed before upload |
| Performance monitoring | Sentry Performance | Frame rate, startup time, API response time |
| Analytics | PostHog or Mixpanel | Self-hosted PostHog preferred (data residency) |
| API monitoring | Vercel Analytics | Built in; add custom metrics |
| Push notification delivery | Expo Push receipts API | Monitor delivery rates |
| Database monitoring | Supabase Dashboard | Query performance, connection pool |
| Alerting | PagerDuty (or email) | P0 alerts: crash spike, push failure |
| Log aggregation | Supabase Logs + Sentry breadcrumbs | |
| Real user monitoring | Sentry + custom `perf` events | |

### 9.7 Git Strategy

**Branching:**
- `main` — production; protected; requires PR + passing CI
- `develop` — integration branch; all feature PRs target here
- `feature/UTAMACS-{ticket}-{description}` — feature branches
- `fix/UTAMACS-{ticket}-{description}` — bug fix branches
- `release/v{major}.{minor}` — release preparation branches

**Monorepo structure (recommended):**
```
utamacs-website/              ← existing repo
  utamacs-apps/
    shared-components/        ← NPM workspace: @utamacs/shared
    android-app/              ← Expo app (Android build)
    ios-app/                  ← Expo app (iOS build)
    package.json              ← workspace root
```

Use npm/yarn workspaces or Turborepo for the monorepo. `shared-components` is a local package; no need to publish to npm.

### 9.8 Semantic Versioning

Mobile apps:
- **Major (X.0.0):** Architecture change, new native modules, major feature additions
- **Minor (0.X.0):** New screens, feature additions, API additions
- **Patch (0.0.X):** Bug fixes, copy changes (often OTA)

App Store version: same as semantic version.  
Build number: auto-incremented in EAS (never hardcoded).

---

## 10. RELIABILITY & SCALABILITY

### 10.1 Offline-First Architecture

The most important reliability investment for mobile. Residents on low-signal mobile data (or in underground parking, basements, or during network outages) must still be able to use core workflows.

**Offline capabilities by feature:**

| Feature | Offline Write | Offline Read | Conflict Resolution |
|---|---|---|---|
| File complaint | ✅ Queue → sync | ✅ Cached list | Last-write-wins (server authoritative) |
| Record payment | ✅ Queue → sync | ✅ Cached dues | Server validates; reject duplicates |
| View notices | ❌ N/A | ✅ Last-fetched | N/A |
| Scan visitor QR | ❌ Needs server verify | ✅ Pass image cached | N/A |
| Log maid attendance | ✅ Queue → sync | ✅ Cached list | Server deduplicates by date+staff |
| View member directory | ❌ N/A | ✅ Cached (60 min) | N/A |
| Community post | ✅ Queue → sync | ✅ Last-fetched | N/A |

**Offline queue implementation:**
```typescript
// shared-components/src/offline/OfflineQueue.ts
interface QueuedMutation {
  id: string;                    // local UUID
  endpoint: string;              // '/api/v1/complaints'
  method: 'POST' | 'PUT';
  body: object;
  created_at: number;            // timestamp
  retry_count: number;
  last_error?: string;
}

// Stored in expo-sqlite (survives app kills)
// Replayed by BackgroundSync task (expo-background-fetch)
// Conflict: if server returns 409, show user a "Resolve conflict" screen
```

### 10.2 Scalability Considerations

**Current scale:** ~200 residents, ~20 executives, ~5 guards. This is very small. Scalability concerns are primarily about architecture quality, not current load.

**Future scale (if platform is offered to other societies):**
- Multi-tenant: already designed (all tables have `society_id`)
- Connection pooling: Supabase uses PgBouncer; should handle 10,000+ concurrent users
- Vercel serverless: auto-scales; no bottleneck
- GitHub doc store: API rate limits (5,000 req/hr authenticated) — problematic at scale; migrate to Cloudflare R2 or AWS S3 at 50+ societies
- Upstash Redis: per-project limits; upgrade plan if needed

**Mobile-specific scale considerations:**
- FCM push: free, unlimited
- Expo Push: 1,000 notifications/month free; paid plans for production
- Supabase Realtime: connection limits per plan; ensure realtime channels are cleaned up on app background

### 10.3 High Availability Strategy

**Current HA posture:**
- Vercel: 99.99% SLA; edge network; multi-region
- Supabase: 99.9% SLA (Pro plan); single-region (Mumbai recommended for Telangana users)
- GitHub API: 99.9% SLA; but synchronous commits are a single point of failure

**Mobile HA improvements:**
- Supabase region: set to `ap-south-1` (Mumbai) for lowest latency from Hyderabad
- Implement retry logic in API client (3 retries, exponential backoff)
- Circuit breaker pattern: if 3 consecutive requests fail, switch to offline mode
- Push notification: send via both Expo Push API and direct FCM for redundancy
- Health check endpoint (`/api/v1/health`) pinged on app launch; if failed, show maintenance screen

### 10.4 SLA Targets (Recommended)

| Metric | Target | Measurement |
|---|---|---|
| API response time (p50) | < 200ms | Sentry Performance |
| API response time (p95) | < 1000ms | Sentry Performance |
| App startup time (cold) | < 2000ms | Sentry Performance |
| App startup time (warm) | < 500ms | Sentry Performance |
| Push notification delivery | > 95% within 30s | Expo Push receipts |
| Crash-free sessions | > 99.5% | Sentry |
| Offline queue success rate | > 99% | Custom metric |
| API availability | > 99.9% | Vercel + external monitor |

---

## 11. TESTING & QA STRATEGY

### 11.1 Test Pyramid

```
                    ┌─────┐
                    │ E2E │  ← 10% (Detox or Maestro)
                  ┌─┴─────┴─┐
                  │Integration│ ← 20% (API contract tests)
                ┌─┴───────────┴─┐
                │  Unit Tests   │ ← 70% (Jest + React Testing Library)
                └───────────────┘
```

### 11.2 Unit Testing

**Framework:** Jest + React Testing Library (RN)

Coverage targets:
- Repositories: 90%+ (pure TypeScript, no native deps)
- Use cases: 90%+ (pure business logic)
- UI components: 70%+ (snapshot + interaction tests)
- API client: 85%+ (mock axios)

**Key test cases:**
- Auth token refresh interceptor (token expired → refresh → retry)
- Offline queue: mutation queued, replayed on reconnection
- Permission checks: role matrix tests
- Pagination cursor: correct offset calculation
- Error normalization: RFC 7807 → typed error

### 11.3 Integration / API Contract Testing

Using the existing `tests/api/` directory pattern (Vitest):

```typescript
// test: POST /api/v1/complaints returns correct shape for mobile
it('returns complaint with required mobile fields', async () => {
  const response = await fetch('/api/v1/complaints', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${testToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ category: 'plumbing', description: 'Leak in bathroom' })
  });
  const body = await response.json();
  expect(body).toMatchObject({
    id: expect.stringMatching(UUID_RE),
    status: 'open',
    created_at: expect.any(String),
    unit: expect.objectContaining({ unit_number: expect.any(String) })
  });
});
```

Pact contract testing (if API team and mobile team are separate): Define consumer contracts that the API must satisfy. This prevents breaking changes from reaching production.

### 11.4 E2E Testing

**Framework:** Maestro (simpler than Detox, YAML-based, works with Expo)

**Critical E2E flows:**
1. Login → view home dashboard → navigate to complaints → create complaint → verify it appears in list
2. Login as guard → scan QR code → verify "VALID" screen appears
3. Login as resident → receive gate request notification → approve it → verify guard sees approval
4. Login → view finance dues → verify correct amount shown
5. Login → create visitor pass → share pass (verify QR image generated)

**Device matrix:**
- Android: Samsung Galaxy A14 (low-end, Android 13), Pixel 7 (mid-range, Android 14)
- iOS: iPhone 11 (minimum, iOS 16), iPhone 15 (latest)
- Screen sizes: 375pt (iPhone SE), 390pt (iPhone 14), 430pt (iPhone 15 Plus)

### 11.5 Performance Testing

- App startup time: measure with `react-native-startup-time`
- Memory: Android Studio Memory Profiler, Xcode Instruments
- Network: Charles Proxy / mitmproxy to validate request shapes and sizes
- Battery: Android Battery Historian for background task analysis
- Frame rate: Flipper + Systrace for 60fps verification

### 11.6 Security Testing

- OWASP MAS (Mobile Application Security) assessment annually
- Static analysis: `semgrep` for React Native security rules in CI
- Dynamic analysis: Frida-based runtime instrumentation before major releases
- Dependency audit: `npm audit` in CI; block deploys with HIGH vulnerabilities

---

## 12. PERFORMANCE ENGINEERING

### 12.1 Startup Performance

**Target:** Cold start < 2000ms on mid-range device (Pixel 6a equivalent)

**Strategy:**
1. Splash screen shown until fonts loaded + auth state resolved (avoid layout shift)
2. Fonts preloaded via `expo-font` before first render
3. Home screen data fetched in parallel (BFF aggregate endpoint)
4. React Query stale-while-revalidate: show cached data immediately, refresh in background
5. Hermes JavaScript engine (default in Expo) — faster startup than JSC
6. Tree shaking: only import needed components from shared-components
7. Defer heavy components: gallery, chart dashboards lazy-loaded on navigation

### 12.2 Memory Optimization

- FlatList with `getItemLayout` for fixed-height lists (avoids measurement overhead)
- `removeClippedSubviews={true}` on long lists
- Image caching: `expo-image` (built-in memory + disk cache, faster than `react-native-fast-image`)
- Avoid storing large blobs in Zustand or React Query cache; store only IDs and minimal metadata
- Clean up Supabase Realtime channels on app background (reduces memory and battery)

### 12.3 Network Performance

- API request deduplication (React Query prevents duplicate in-flight requests)
- Response compression: Vercel enables gzip/brotli by default
- Payload minimization: request only needed fields (already partially done via select parameters in Supabase)
- Image optimization: request mobile-appropriate dimensions (400px wide for list thumbnails, not full-resolution)
- Prefetching: prefetch complaint detail when user hovers/focuses list item (React Query `prefetchQuery`)
- Connection keep-alive: HTTP/2 multiplexing (Vercel supports this)

### 12.4 Battery Optimization

- No continuous polling in background (replace with push notifications)
- Supabase Realtime channels: subscribe only when app is foregrounded
- Background task budget: `expo-background-fetch` runs at most once per 15 minutes
- Location: only requested for security patrol feature (guard-only, explicit permission, not continuous)
- Animations: disable entirely with `AccessibilityInfo.isReduceMotionEnabled()`

### 12.5 Performance Budgets

| Metric | Budget | Alert Threshold |
|---|---|---|
| Cold start (mid-range device) | < 2000ms | > 3000ms |
| Warm start | < 500ms | > 1000ms |
| Time to interactive (home screen) | < 1500ms | > 2500ms |
| API response (95th pct) | < 1000ms | > 2000ms |
| Frame rate (animations) | 60fps | < 55fps |
| JS bundle size | < 5MB | > 8MB |
| App install size (Android) | < 50MB | > 75MB |
| App install size (iOS) | < 50MB | > 75MB |
| Crash-free rate | > 99.5% | < 99% |

### 12.6 Offline & Low Bandwidth

- API responses cached by React Query (default stale time: 5 minutes)
- Critical data (notices, dues, complaints) explicitly cached in SQLite for offline viewing
- Images cached to disk by `expo-image`
- Low-bandwidth mode: detect poor connectivity via NetInfo; switch to text-only list views
- Image lazy loading: only load images when visible in viewport (FlatList `onViewableItemsChanged`)

---

## 13. FOLDER STRUCTURE RECOMMENDATIONS

### 13.1 Monorepo Root

```
utamacs-apps/
├── package.json                    ← npm workspaces config
├── turbo.json                      ← Turborepo config (optional)
├── .eslintrc.js                    ← shared ESLint config
├── .prettierrc                     ← shared Prettier config
├── tsconfig.base.json              ← shared TypeScript base config
├── MOBILE_ARCHITECTURE.md          ← this document
│
├── shared-components/              ← @utamacs/shared
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   ├── api/
│   │   │   ├── client.ts           ← Axios instance + interceptors
│   │   │   ├── endpoints.ts        ← Centralized endpoint strings
│   │   │   └── types/             ← Request/response types per domain
│   │   ├── repositories/
│   │   │   ├── auth/
│   │   │   ├── complaints/
│   │   │   ├── finance/
│   │   │   ├── members/
│   │   │   ├── notifications/
│   │   │   ├── visitors/
│   │   │   ├── facilities/
│   │   │   ├── community/
│   │   │   ├── polls/
│   │   │   ├── parking/
│   │   │   ├── documents/
│   │   │   ├── gallery/
│   │   │   ├── vendors/
│   │   │   ├── hoto/
│   │   │   ├── snags/
│   │   │   ├── maids/
│   │   │   └── events/
│   │   ├── usecases/
│   │   │   ├── auth/
│   │   │   ├── permissions/
│   │   │   ├── offline/
│   │   │   ├── notifications/
│   │   │   └── sync/
│   │   ├── design/
│   │   │   ├── tokens.ts           ← colors, typography, spacing, radius, shadow
│   │   │   ├── icons.ts            ← icon name mapping
│   │   │   └── theme.ts            ← light + dark theme objects
│   │   ├── analytics/
│   │   │   ├── events.ts           ← typed event registry
│   │   │   └── tracker.ts          ← platform-agnostic tracker interface
│   │   ├── offline/
│   │   │   ├── OfflineQueue.ts
│   │   │   ├── SyncManager.ts
│   │   │   └── ConflictResolver.ts
│   │   ├── permissions/
│   │   │   ├── PermissionResolver.ts
│   │   │   └── types.ts
│   │   ├── types/
│   │   │   ├── database.types.ts   ← Supabase generated (symlinked or copied)
│   │   │   ├── api.types.ts        ← Shared request/response types
│   │   │   └── navigation.types.ts ← Route param types
│   │   └── utils/
│   │       ├── currency.ts         ← INR formatting (₹X,XX,XXX)
│   │       ├── date.ts             ← IST date formatting
│   │       ├── phone.ts            ← Indian phone number validation
│   │       └── validation.ts       ← UUID, email, amount validators
│   └── __tests__/
│       ├── repositories/
│       ├── usecases/
│       └── utils/
│
├── android-app/                    ← Expo app (Android-focused)
│   ├── app.json                    ← Expo config (Android section)
│   ├── package.json
│   ├── tsconfig.json
│   ├── eas.json                    ← EAS Build profiles
│   ├── app/                        ← Expo Router pages
│   │   ├── _layout.tsx             ← Root layout + auth guard
│   │   ├── (auth)/
│   │   │   ├── login.tsx
│   │   │   ├── forgot-password.tsx
│   │   │   └── reset-password.tsx
│   │   ├── (tabs)/
│   │   │   ├── _layout.tsx         ← Bottom tab navigator
│   │   │   ├── home/
│   │   │   │   └── index.tsx
│   │   │   ├── complaints/
│   │   │   │   ├── index.tsx
│   │   │   │   ├── new.tsx
│   │   │   │   └── [id].tsx
│   │   │   ├── notices/
│   │   │   │   ├── index.tsx
│   │   │   │   └── [id].tsx
│   │   │   ├── finance/
│   │   │   │   └── index.tsx
│   │   │   └── more/
│   │   │       └── index.tsx
│   │   ├── visitors/
│   │   │   ├── index.tsx
│   │   │   ├── new-pass.tsx
│   │   │   └── pass/
│   │   │       └── [token].tsx
│   │   ├── community/
│   │   │   ├── index.tsx
│   │   │   ├── new.tsx
│   │   │   └── [id].tsx
│   │   ├── facilities/
│   │   │   ├── index.tsx
│   │   │   └── book.tsx
│   │   ├── polls/
│   │   │   ├── index.tsx
│   │   │   └── [id].tsx
│   │   ├── parking/
│   │   │   └── index.tsx
│   │   ├── events/
│   │   │   ├── index.tsx
│   │   │   └── [id].tsx
│   │   ├── gallery/
│   │   │   └── index.tsx
│   │   ├── documents/
│   │   │   ├── index.tsx
│   │   │   └── [id].tsx
│   │   ├── vendors/
│   │   │   ├── index.tsx
│   │   │   └── [id].tsx
│   │   ├── hoto/
│   │   │   └── index.tsx
│   │   ├── snags/
│   │   │   ├── index.tsx
│   │   │   └── [id].tsx
│   │   ├── maids/
│   │   │   └── index.tsx
│   │   ├── profile/
│   │   │   └── index.tsx
│   │   ├── settings/
│   │   │   └── index.tsx
│   │   └── guard/
│   │       ├── gate.tsx
│   │       ├── scan.tsx
│   │       └── visitors.tsx
│   ├── components/                 ← App-specific UI components
│   │   ├── home/
│   │   ├── complaints/
│   │   ├── finance/
│   │   ├── visitors/
│   │   └── common/
│   ├── hooks/                      ← App-specific React hooks
│   │   ├── useAuth.ts
│   │   ├── usePermissions.ts
│   │   ├── usePushNotifications.ts
│   │   ├── useOfflineQueue.ts
│   │   └── useRealtime.ts
│   ├── stores/                     ← Zustand stores
│   │   ├── authStore.ts
│   │   ├── featureFlagStore.ts
│   │   ├── notificationStore.ts
│   │   └── offlineQueueStore.ts
│   ├── assets/
│   │   ├── fonts/ (Inter, Poppins)
│   │   ├── images/
│   │   └── icons/
│   └── __tests__/
│       ├── screens/
│       └── hooks/
│
└── ios-app/                        ← iOS-specific (mirrors android-app structure)
    ├── app.json                    ← Expo config (iOS section)
    ├── eas.json
    └── ... (same structure as android-app)
```

**Note:** Given 90%+ code sharing, `android-app` and `ios-app` will be nearly identical initially. Separate directories allow platform-specific native modules (Push certificates, In-app purchases, etc.) to diverge cleanly over time. Alternatively, use a single `mobile-app` directory with platform-specific config — a pragmatic choice for a small team.

### 13.2 Recommended Simplification for Small Team

Given the team size, consider a single `mobile-app` folder instead of `android-app` + `ios-app`:

```
utamacs-apps/
├── shared-components/   ← @utamacs/shared package
├── mobile-app/          ← Single Expo app (builds for both platforms)
└── MOBILE_ARCHITECTURE.md
```

Split into `android-app` + `ios-app` only when:
- Platform-specific native code diverges significantly
- Separate team members own each platform
- Different release cadences are required

---

## 14. TECHNICAL DECISION MATRIX

### 14.1 Framework Decision

| Option | Score (1–10) | Verdict |
|---|---|---|
| React Native + Expo | **9** | **RECOMMENDED** |
| Flutter | 7 | Good but Dart ramp-up cost |
| Kotlin Multiplatform | 6 | Too much native UI work |
| Capacitor + Web | 5 | SSR incompatible; WebView performance |
| React Native (bare) | 7 | More control but loses Expo tooling |
| Pure Native (Swift + Kotlin) | 4 | Prohibitive maintenance cost |

### 14.2 State Management Decision

| Option | Score | Verdict |
|---|---|---|
| React Query + Zustand | **9** | **RECOMMENDED** |
| Redux Toolkit + RTK Query | 7 | More boilerplate; overkill |
| MobX | 6 | Good but less TypeScript-friendly |
| Jotai | 7 | Good alternative to Zustand |
| Context API only | 4 | Performance issues at scale |

### 14.3 Navigation Decision

| Option | Score | Verdict |
|---|---|---|
| Expo Router | **9** | **RECOMMENDED** |
| React Navigation v6 | 8 | More control; widely used |
| React Navigation v7 | 7 | Too new; breaking changes |

### 14.4 Testing Decision

| Option | Score | Verdict |
|---|---|---|
| Jest + RTL + Maestro | **9** | **RECOMMENDED** |
| Jest + RTL + Detox | 7 | More reliable E2E but complex setup |
| Vitest + Playwright (RN) | 5 | Playwright RN is experimental |

### 14.5 Image Handling Decision

| Option | Score | Verdict |
|---|---|---|
| expo-image | **9** | **RECOMMENDED** |
| react-native-fast-image | 7 | No longer maintained |
| React Native built-in Image | 5 | No memory cache management |

### 14.6 Push Notifications Decision

| Option | Score | Verdict |
|---|---|---|
| Expo Push + Firebase | **9** | **RECOMMENDED** |
| OneSignal | 8 | Good but adds dependency |
| Direct FCM + APNs | 6 | More control; complex setup |
| AWS SNS | 5 | Overkill for this scale |

---

## 15. MIGRATION PLAN

### 15.1 Pre-Conditions (Before Writing Any Mobile Code)

These changes to the existing web portal are **non-negotiable prerequisites** for mobile launch. They are all non-breaking additions to the existing portal.

| # | Change | Who | Effort |
|---|---|---|---|
| 1 | Add Bearer token support to `resolveFromRequest()` | Portal backend | 2 hours |
| 2 | Add `device_push_tokens` table + migration | DBA | 1 hour |
| 3 | Add `POST /api/v1/notifications/push/register` route | Portal backend | 2 hours |
| 4 | Add `GET /api/v1/members/me/permissions` endpoint | Portal backend | 2 hours |
| 5 | Add `GET /api/v1/mobile/home` BFF aggregate endpoint | Portal backend | 4 hours |
| 6 | Wire gate approval events to push dispatch | Portal backend | 4 hours |
| 7 | Add `platform` column to `feature_flags` | DBA | 1 hour |
| 8 | Create Firebase project + add `google-services.json` | DevOps | 2 hours |
| 9 | Set up EAS project + configure profiles | DevOps | 4 hours |
| 10 | Set up Apple Developer account + APNs key | DevOps | 4 hours |
| 11 | Set up Sentry React Native project | DevOps | 2 hours |

**Total pre-conditions effort: ~28 hours (~1 sprint)**

### 15.2 Phase 1 — Foundation (Weeks 1–4)

**Goal:** Working app with auth, home dashboard, and push notifications.

| Deliverable | Notes |
|---|---|
| Expo project setup (EAS + Expo Router) | Monorepo, workspaces, TS config |
| shared-components package | Design tokens, API client, auth repository |
| Login screen | Email/password; biometric on second launch |
| Home screen | BFF aggregate; dues card, recent notices, open complaints |
| Push notification registration | Device token stored on login |
| Gate approval push | Server sends FCM on gate request; app shows notification |
| Notification inbox | List with unread count |
| Profile screen | View own profile, change avatar |
| EAS Build setup | CI/CD pipeline, preview channel |

### 15.3 Phase 2 — Core Resident Features (Weeks 5–10)

**Goal:** Feature-complete resident experience. App is usable for daily workflows.

| Deliverable | Notes |
|---|---|
| Complaints (list + create + detail) | Camera attachment, status tracking, comments |
| Notices (list + detail + acknowledge) | Push on new notice |
| Finance dues | Dues card, payment history, receipt download |
| Visitor passes | Create pass, QR display, share |
| Gate approval (resident side) | Approve/reject from notification or in-app |
| QR scanner (guard side) | expo-camera, pass validation, entry logging |
| Community Board | Posts, comments, reactions, images |
| Basic profile editing | Phone (DPDPA-masked), avatar upload |

### 15.4 Phase 3 — Extended Features (Weeks 11–18)

**Goal:** P1 module coverage. App reaches feature parity with web for resident workflows.

| Deliverable | Notes |
|---|---|
| Polls / Voting | Native radio/check UX |
| Facility booking | Calendar availability, booking form |
| Parking | Allocation view, transfer request |
| Events | List, detail, RSVP |
| Gallery | Albums, photos with pinch-to-zoom |
| Documents | PDF viewer, download |
| Water Tankers | Booking flow |
| Security Patrol log (guard) | Location check-in (future GPS) |
| Member directory | DPDPA-compliant contact visibility |
| Offline queue | File complaints offline, sync on reconnect |

### 15.5 Phase 4 — Executive & Admin Features (Weeks 19–26)

**Goal:** Full executive workflow coverage.

| Deliverable | Notes |
|---|---|
| Vendors & Work Orders | Exec-only |
| HOTO Tracker | Handover workflows |
| Snag List | Camera attachments |
| Maids Registry | KYC, attendance |
| Letters | Template-based letter generation |
| Analytics summary | KPI widgets only (full dashboard web-only) |
| Admin module (basic) | Feature flags, member roles |
| Tenant KYC | Document scanner |

### 15.6 Phase 5 — Polish & Launch (Weeks 27–30)

| Activity | Notes |
|---|---|
| Accessibility audit | VoiceOver + TalkBack |
| Performance profiling | Meet all budget targets |
| Security review (OWASP Mobile) | External or internal |
| Beta testing (10–20 residents) | EAS staging channel |
| App store submission | Google Play + App Store |
| Privacy manifest (iOS) | Required for App Store |
| Post-launch monitoring | Sentry + Expo Push receipts |

---

## 16. ROADMAP

```
Q3 2026 — Foundation
├── Week 1-2:  Pre-conditions (backend changes, EAS setup, Firebase)
├── Week 3-4:  Expo project scaffolding + shared-components setup
├── Week 5-6:  Auth flow (login, biometric, token management)
├── Week 7-8:  Home screen + push notification infrastructure
└── Week 9-10: Complaints + Notices MVP

Q4 2026 — Core Features
├── Week 11-12: Finance + Visitor Passes
├── Week 13-14: QR Scanner + Gate Approvals
├── Week 15-16: Community Board + Profile
├── Week 17-18: Beta release (internal + select residents)
└── Week 19-20: P1 features (Polls, Facilities, Parking, Events)

Q1 2027 — Feature Complete
├── Week 21-22: Gallery + Documents + Water Tankers
├── Week 23-24: Offline queue + Background sync
├── Week 25-26: Executive features (Vendors, HOTO, Snags)
└── Week 27-28: Performance + Accessibility + Security audit

Q2 2027 — Launch
├── Week 29:   App Store + Play Store submission
├── Week 30:   Soft launch (beta residents)
├── Week 31-32: Full launch (all residents notified via WhatsApp)
└── Post-launch: Monitor, hotfix, gather feedback

Q3 2027 — v2.0 Planning
├── Widgets (iOS WidgetKit, Android App Widgets)
├── Siri Shortcuts + Android Shortcuts
├── NFC visitor pass sharing
├── GPS checkpoint for security patrol
└── Multi-society support (if platform expansion planned)
```

### 16.1 Team Structure Recommendation

**Minimum viable team for this roadmap:**

| Role | Count | Responsibility |
|---|---|---|
| Mobile Engineer (React Native) | 2 | All app screens, native modules, EAS |
| Backend Engineer | 1 | Pre-conditions, BFF endpoint, push dispatch |
| QA Engineer | 1 (part-time) | Test strategy, Maestro E2E, device matrix |
| Designer | 1 (part-time) | Native design system, Figma specs |
| DevOps / Platform | 1 (part-time) | EAS, CI/CD, Firebase, Sentry |

If headcount is constrained to 1–2 engineers total, reduce scope to Phases 1–2 only for initial launch, and plan Phases 3–5 for 2027.

---

## 17. DETAILED DISCOVERY QUESTIONNAIRE

The following questionnaire must be answered before architecture is finalized. Unknowns in these areas could fundamentally change technical decisions.

### 17.1 Business & Product Goals

1. What is the primary business goal of the native app? (Adoption? Resident satisfaction? Operational efficiency? Revenue?)
2. Is there a target launch date? If so, is it fixed (contractual) or aspirational?
3. Will the app eventually be offered to other housing societies beyond UTAMACS? (Multi-tenancy product vs. single society tool)
4. What is the expected total user base at launch? At 1 year? At 3 years?
5. Is there a monetization model planned for the app? (Premium features? Per-society subscription?)
6. Who will own the app after launch? (In-house team? Outsourced maintenance?)
7. What is the minimum OS version support target? (iOS 15? 16? Android 12? 13?)
8. What is the minimum device support target? (Entry-level ₹8,000 phones? Mid-range only?)
9. Is there an enterprise MDM requirement? (Some housing societies manage devices centrally)
10. Will the app support multiple languages? (Telugu, Hindi, English?)

### 17.2 User Personas & Workflows

11. What percentage of current residents actively use the web portal?
12. Which module has the highest daily active usage?
13. Are security guards provided society-owned devices, or do they use personal phones?
14. What Android/iOS split is expected based on the resident demographic?
15. Are there elderly residents who may need an accessibility-first or simplified interface?
16. Is there a "family member" user type? (E.g., spouse also needs access to the same unit's data)
17. Are there resident committees that need bulk notification capabilities?
18. Do guards need a simplified "guard-only" app, or is the full app acceptable with role-based hiding?
19. Is there a case for a "visitor" facing app? (E.g., delivery personnel scanning into the society)
20. How do executives currently manage approvals — primarily on desktop or mobile?

### 17.3 Infrastructure & Scale

21. What is the current number of active residents on the web portal?
22. What is the peak concurrent session count on the portal?
23. What is the Supabase plan tier? (Free? Pro? Team?)
24. What is the current database size?
25. How many document uploads per day on average?
26. What is the average file size of uploaded documents?
27. Is the Supabase region currently set to the nearest region (Mumbai)?
28. Is there a budget for Sentry (crash reporting) and Expo EAS (builds + OTA updates)?
29. What is the budget for Firebase (push notification platform)?
30. Is Upstash Redis on a paid plan? What are the current rate limits?

### 17.4 Authentication & Security

31. Are there plans for social login? (Google, Apple Sign-In is mandatory for iOS if offered)
32. Is phone number OTP login desired? (Supabase supports this natively)
33. Should biometric authentication be mandatory, optional, or absent?
34. What is the session duration policy? (Currently session cookies — no explicit TTL found)
35. Is there a requirement for single sign-on (SSO) with any identity provider?
36. Is there a requirement for multi-factor authentication (MFA)?
37. Who manages the Apple Developer account? Is one already registered?
38. Who manages the Google Play developer account? Is one already registered?
39. Is there a device management (MDM) or app wrapping requirement for any user group?
40. What is the data residency requirement? (Must data stay in India under DPDPA?)

### 17.5 Notifications

41. Which events must trigger push notifications? (Full list: gate approval, new notice, due date reminder, complaint update, poll published, event reminder, others?)
42. What is the acceptable push notification delivery latency for gate approvals? (< 5 seconds? < 30 seconds?)
43. Should users be able to customize which notifications they receive?
44. Is WhatsApp notification delivery a hard dependency, or can push replace it?
45. Are there "Do Not Disturb" hours for certain notification types?
46. Should push notifications show message content in the preview, or just "1 new update"? (Privacy consideration)
47. Is there a requirement for notification scheduling? (E.g., due date reminders 3 days before)
48. What happens to notifications sent when the app is not installed? (SMS fallback? Email?)

### 17.6 Offline & Connectivity

49. Are there specific areas of the apartment complex with poor connectivity?
50. What is the acceptable data loss scenario? (If complaint is filed offline and sync fails after 3 retries, what happens?)
51. Should offline drafts be visible to the user as "pending" items?
52. Is QR scanning required to work without internet? (Currently requires server verification)
53. Should financial data be viewable offline?
54. Is there a maximum offline period before the app requires re-authentication?
55. Should the guard's QR scanner work fully offline? (Requires local pass cache with expiry)

### 17.7 API & Backend

56. Is there an engineering owner for the backend API who will implement pre-conditions?
57. What is the approved change process for adding new API endpoints?
58. Is there a staging Supabase project separate from production?
59. Are there any API endpoints that are intentionally web-only? (DOCX generation, PDF generation)
60. Is the GitHub Docs repo strategy permanent, or is there a plan to migrate to S3/R2?
61. How is the `ENCRYPTION_KEY` for AES-256 managed? Is it rotated? How often?
62. Is the `IP_HASH_SALT` rotation automated or manual?
63. Are there any planned backend changes in the next 90 days that could break mobile?
64. Is PostgREST (Supabase REST API) used directly anywhere, or only via the custom API?
65. Are there any Supabase Edge Functions in use or planned?

### 17.8 Analytics & Monitoring

66. Is any analytics tool currently in use on the web portal?
67. What user events must be tracked for product decisions? (Screen views? Feature usage? Error rates?)
68. Is there a requirement for funnel analysis? (E.g., complaint creation funnel)
69. Is crash reporting required? (Sentry recommended — is there a budget?)
70. What is the alerting threshold for crash spikes?
71. Is there a NOC (Network Operations Center) or on-call rotation?
72. Who receives P0 alerts? (Engineering lead? Committee secretary?)
73. Is there a SLA commitment to residents? (E.g., "App will be available 99% of the time")
74. Is there a requirement for audit logging of mobile-specific actions separate from the existing audit_logs table?
75. Are there regulatory reporting requirements for app analytics?

### 17.9 Integrations

76. Is UPI payment integration planned? (Razorpay, Cashfree, PhonePe business?)
77. Is there a requirement to integrate with the gate intercom system?
78. Is there a CCTV camera integration planned? (Live feed in app)
79. Is there a plan to integrate with smart meters (water/electricity)?
80. Is there a requirement to integrate with any government portals? (Property tax, Telangana Dharani, HMDA)
81. Will the WhatsApp Business API integration send messages from the mobile app?
82. Is there a calendar sync requirement? (Google Calendar, iCal for events and bookings)
83. Is there a requirement for Google Maps integration? (Visitor directions, compound map)
84. Are there any existing mobile-facing webhooks or webhooks that need a mobile trigger?
85. Is there a requirement for biometric document scanning? (e.g., Digilocker integration for KYC)

### 17.10 App Store & Distribution

86. Will the app be published to both Google Play and Apple App Store?
87. Will the app be listed under the society name or a developer account?
88. Should the app be geographically restricted? (India only? Hyderabad only?)
89. What is the minimum iOS version? (Apple requires supporting at least last 2–3 major versions)
90. What is the minimum Android version? (Android 8/9/10/11?)
91. Is there a plan for enterprise distribution? (Some societies prefer side-loading to avoid app store review delays)
92. Will the app handle in-app purchases? (Apple requires use of Apple IAP for digital goods)
93. Is there an existing Apple Developer Program membership ($99/year)?
94. Is there an existing Google Play developer account ($25 one-time)?
95. Is there a preference for a private app (restricted distribution) vs. public listing?

### 17.11 Compliance & Legal

96. Under DPDPA 2023, who is the "Data Fiduciary" for the mobile app? (The society? The software developer?)
97. Is there a Data Protection Officer (DPO) appointed?
98. What is the policy for resident data deletion requests received via the mobile app?
99. Are app usage analytics subject to DPDPA consent? (If tracking individual behavior, yes)
100. Is there a requirement for Terms of Service and Privacy Policy within the app?
101. Are there any pending legal disputes or investigations that could affect app features?
102. Is there a law enforcement data disclosure policy for app data?
103. Should the app include a "report a safety concern" feature with anonymous submission?
104. Is biometric data (fingerprint/face) stored? (It must NOT be — Expo LocalAuth uses platform-side biometric; no biometric data leaves the device)
105. Is there a requirement for WCAG 2.1 AA accessibility compliance?

### 17.12 Quality & Testing

106. Is there a dedicated QA resource or is testing done by engineers?
107. What physical devices are available for testing?
108. Is device cloud testing (Firebase Test Lab, BrowserStack) in budget?
109. What is the acceptable defect escape rate to production?
110. Is there a bug bounty program or responsible disclosure policy?
111. What is the process for critical bug fixes? (How quickly must a P0 bug be deployed?)
112. Is there a change advisory board (CAB) process that app releases must go through?
113. How will beta testers be selected and managed?
114. Is there a requirement for automated E2E tests before every release?
115. Is there a test environment with realistic data volume?

### 17.13 Operations & Support

116. Who will handle resident support for app issues? (Committee member? WhatsApp group?)
117. Is there a helpdesk ticketing system?
118. What is the process for reporting app bugs to the development team?
119. How will forced app updates be communicated to residents?
120. Is there a process for emergency shutdown of the app? (E.g., if a security breach is detected)
121. Who is responsible for app store review responses?
122. What is the process for handling a Play Store / App Store account suspension?
123. Is there a disaster recovery plan for Supabase data loss?
124. How often is the database backed up? Is the backup tested?
125. What is the maximum acceptable RTO (Recovery Time Objective) if the app goes down?

---

## 18. IMMEDIATE NEXT STEPS

The following actions should begin **this week**, before any mobile code is written.

### Priority 1 — This Week

1. **Answer the questionnaire** (Section 17) — identify all unknowns; resolve before architecture finalization
2. **Assign API pre-conditions owner** — a backend engineer must own the 28-hour pre-conditions sprint
3. **Create Apple Developer account** (if not existing) — takes up to 7 business days to approve
4. **Create Google Play developer account** (if not existing) — $25, immediate
5. **Create Firebase project** — free; configure FCM; download `google-services.json` + `GoogleService-Info.plist`
6. **Create Expo account** — free; create the EAS project; assign team members
7. **Create Sentry organization** — free tier; get DSN for React Native project

### Priority 2 — Next Two Weeks

8. **Implement Bearer token auth** — `resolveFromRequest()` in `src/lib/permissions.ts`
9. **Run database migration** for `device_push_tokens` table
10. **Implement push token registration endpoint** — `POST /api/v1/notifications/push/register`
11. **Implement permissions endpoint** — `GET /api/v1/members/me/permissions`
12. **Implement home BFF endpoint** — `GET /api/v1/mobile/home`
13. **Set up monorepo** — npm workspaces, `shared-components` package, TypeScript base config
14. **Design system documentation** — document all tokens in Figma before component development begins
15. **Hire / identify mobile engineers** — if no existing React Native expertise, begin hiring or training now

### Priority 3 — Month 1 End Goal

16. Working login screen on both iOS and Android simulators
17. Home screen populated from BFF endpoint
18. Push notification received on physical device for a gate approval request
19. EAS Build pipeline producing .apk and simulator builds on every PR

---

## APPENDIX A — Technology Recommendations Summary

| Decision | Recommendation | Status |
|---|---|---|
| Mobile framework | React Native + Expo | Decision |
| Navigation | Expo Router | Decision |
| Server state | TanStack Query (React Query) | Decision |
| Client state | Zustand | Decision |
| Styling | StyleSheet + design tokens (no Tailwind on mobile) | Decision |
| Animations | React Native Reanimated 3 | Decision |
| Secure storage | expo-secure-store | Decision |
| Database (local) | expo-sqlite | Decision |
| Fast storage | MMKV | Decision |
| Camera | expo-camera | Decision |
| QR scanning | expo-barcode-scanner | Decision |
| Biometric | expo-local-authentication | Decision |
| Push | Expo Push + Firebase | Decision |
| Images | expo-image | Decision |
| File picker | expo-document-picker | Decision |
| Background tasks | expo-background-fetch | Decision |
| CI/CD | EAS Build + EAS Update + GitHub Actions | Decision |
| Crash reporting | Sentry React Native | Decision |
| Analytics | PostHog (self-hosted) or Mixpanel | Pending budget |
| Real-time | Supabase Realtime channels | Decision |
| PDF viewing | react-native-pdf | Decision |
| QR code display | react-native-qrcode-svg | Decision |
| Bottom sheets | @gorhom/bottom-sheet | Decision |

---

## APPENDIX B — Dependency Risk Assessment

| Dependency | Risk Level | Mitigation |
|---|---|---|
| Expo SDK (version lock) | Medium | SDK upgrade required annually; EAS handles binary |
| Supabase (vendor lock-in) | Medium | IAuthService / IStorageService interfaces allow swap |
| GitHub Doc Store | High | Single vendor for all files; plan migration to R2 at scale |
| Vercel (serverless) | Low | API routes are framework-agnostic; can run on AWS Lambda |
| Upstash Redis | Low | Upstash is compatible with standard Redis clients |
| Firebase FCM | Low | Expo Push abstracts FCM/APNs; can swap push provider |
| Resend (email) | Low | Standard SMTP fallback available |
| react-native-reanimated | Low | Core library, well-maintained by Software Mansion |

---

*This document is the authoritative architecture reference for the UTA MACS mobile platform. Update it as decisions are finalized. All implementation work should reference and conform to this document.*
