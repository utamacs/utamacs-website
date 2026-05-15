# Mobile Stack Decision: Native vs Cross-Platform

**Author:** Subramanyam
**Decision date:** May 2026
**Final decision:** Flutter (Dart)

---

## Context

Building a mobile app for **society / association management** covering:

- Maintenance billing
- Visitor management (QR-based gate entry)
- Vendor management
- Staff management
- Handover / takeover flows
- Residence and member management
- Notifications inbox
- Ads placement

**Team:** Solo .NET developer (no prior mobile experience).
**Backend:** TypeScript REST API, JWT auth, 200+ endpoints — already built.
**Reference app for visual/UX direction:** MyGate (warm-minimal aesthetic — cream background, yellow primary, navy text, ~16px radius cards).

---

## The journey — how the decision evolved

The conversation started somewhere very different from where it ended. Here is the path, faithfully recorded.

### Stage 1 — Premium themes for web and mobile

Initial question: which premium themes to buy for web and mobile.

Surveyed marketplaces:

- **Web:** ThemeForest, Astra Pro, Divi, GeneratePress, StudioPress, TemplateMonster, Creative Tim
- **Mobile:** Instamobile, CodeCanyon, Gluestack Market, Craft React Native, UI8, Setproduct

Key insight at this stage: theme bloat is a real risk for a small team. Lean themes beat multipurpose bundles.

### Stage 2 — Web rewrite (Astro → React)

Tangential discussion: rewriting an existing site from Astro to React (Vite + SPA), motivated by wanting more interactivity.

Covered the mental-model shift (server-first islands → fully client-rendered SPA), the loss of zero-JS-by-default performance, and the SEO implications.

### Stage 3 — React styling recommendation

Reviewed React UI ecosystems: Tailwind Plus, Untitled UI React, shadcn/ui, Mantine, MUI X, Tremor, Park UI.

Top recommendation for React web: **Tailwind Plus** ($299 personal, lifetime) paired with **shadcn/ui** for primitives.

### Stage 4 — Pivot: actually building a mobile app, not web

Sharp pivot in the conversation. The real intent was mobile, not web. Discovered the MyGate-style screenshots were the visual target. Tailwind Plus is web-only and dropped out of contention.

### Stage 5 — Native dual-codebase (iOS + Android separately)

Initial mobile direction was **native iOS + native Android separately**.

Examined the landscape:

- No equivalent of "Tailwind Plus" exists for native mobile. Ecosystem is fragmented.
- Path would be: buy Figma kit (Untitled UI, ~$129–249) → implement components in SwiftUI and Jetpack Compose separately → maintain two codebases forever.
- Realistic timeline for a solo dev new to native: 6+ months to ship, then permanent 2x maintenance burden.

### Stage 6 — Figma deep-dive

Clarified what Figma actually is (web-based design tool), how Untitled UI Figma works (PRO SOLO at $129 lifetime), and how it fits into a native workflow.

Realised that for a solo non-designer engineer, Figma adds tooling overhead that may not pay back unless someone in the team designs.

### Stage 7 — Surface the timeline reality

Timeline was clarified as **20 days**. This made native dual-codebase unambiguously infeasible.

Also clarified the feature set: QR scanning, biometric auth (Face ID, fingerprint), notifications, ads — all standard mobile features with no special hardware needs.

### Stage 8 — Cross-platform comparison

Considered three cross-platform options:

- **.NET MAUI** — leverages existing C# knowledge, but smaller ecosystem and fewer templates
- **Flutter (Dart)** — largest cross-platform ecosystem, Dart is C#-friendly
- **React Native (JavaScript/TypeScript)** — largest cross-platform community, requires React/JS familiarity

### Stage 9 — Native vs Flutter: the 40-question grilling

Forty pointed questions stress-tested the "native" choice across:

- Time and throughput
- Learning curve
- Tooling and ecosystem fragmentation
- Code reuse (zero, for pure native)
- Operational reality (CI/CD, SDK upgrades, store reviews — all doubled)
- The business reality (the apps used as reference, including MyGate, are themselves cross-platform)

The answers revealed: no specific feature requires native, the "missing limitations" fear was unfounded, and the asymmetric risk strongly favored cross-platform.

### Stage 10 — Flutter vs React Native: the final fork

Both produce real native apps for iOS and Android from one codebase. Both are excellent. The decision hinged on the solo .NET developer profile:

- **Dart is the gentlest language transition from C#** — feels like a younger cousin (classes, properties, async/await, generics, sound null safety all map cleanly)
- **One language for everything** — UI, logic, business rules all in Dart; React Native often requires dipping into native code
- **Hot reload is sharper in Flutter**
- **Pixel-perfect cross-platform consistency** (Flutter renders every pixel itself via Skia/Impeller)
- **Single cohesive framework** vs React Native's assembly of pieces

React Native would have won if the developer had a React or web background. They do not. Flutter wins on the developer-profile axis.

---

## Final decision: Flutter

### Why Flutter beats native for this project

| Concern | Native (iOS + Android) | Flutter |
|---|---|---|
| Codebase count | 2 | 1 |
| Languages to learn | Swift + Kotlin (2 new) | Dart (1 new, C#-friendly) |
| Realistic time to ship v1 | 6+ months | 8–12 weeks |
| Maintenance burden | 2x forever | 1x |
| Hot reload | SwiftUI previews + Compose previews (separate, flaky) | Sub-second, stateful, unified |
| Design system effort | Build twice, fight drift forever | Define `AppTheme` once |
| Feature coverage for this app | Native | Equally complete via packages |
| Escape hatch when needed | N/A (already native) | Platform channels — 20 lines of Swift/Kotlin per gap |
| Industry validation | Was the norm pre-2020 | Used by BMW, Toyota, Alibaba, eBay, Google Pay, etc. |

### Why Flutter beats React Native for this developer

| Axis | Flutter | React Native |
|---|---|---|
| Language from C# background | Dart — gentle transition, very C#-like | TypeScript + JSX — bigger mental shift |
| Single-language coherence | UI + logic in Dart | JS/TS + occasional native modules |
| Rendering | Own engine (Skia/Impeller) — pixel-perfect consistency | Bridges to real native components — sometimes platform-inconsistent |
| Hot reload | Sub-second, stateful | Good (Fast Refresh) but less sharp |
| Tooling cohesion | One framework, one toolchain | Assembled (RN core + Metro + community packages + Expo) |
| Ecosystem size | Large and growing | Larger, especially household-name apps |
| Talent pool for hiring later | Smaller but growing | Larger |

### Honest tradeoffs accepted by choosing Flutter

- **App size:** ~5MB extra baseline because Flutter bundles a runtime. Irrelevant for a society app.
- **Cutting-edge platform features lag by weeks/months** (Live Activities, Dynamic Island, App Intents). None of these are in scope.
- **Heavy 3D / AR / video editing** are weaker than native. Not in scope.
- **iOS scroll feel** is very close but not 100% pixel-identical. Imperceptible to users.
- **Smaller talent pool than React Native** for future hiring.
- **Google support risk** — Google has killed projects before. Flutter has too much momentum (BMW, Toyota, Alibaba, eBay using it in production) for sudden death to be realistic, but worth acknowledging.

### What this app needs — all solved cleanly by Flutter packages

| Need | Package | Notes |
|---|---|---|
| QR code scanning | `mobile_scanner` | Official-quality, well-maintained |
| Biometric auth (Face ID, Touch ID, fingerprint) | `local_auth` | Official Flutter team package |
| Push notifications | `firebase_messaging` | Cross-platform FCM |
| Payments | `razorpay_flutter` (or chosen gateway) | First-party SDK |
| Charts | `fl_chart` (free) or `syncfusion_flutter_charts` (free community license) | Production-ready |
| Local DB | `drift` or `sqflite` | Both excellent |
| HTTP client | `dio` | Standard choice |
| State management | `riverpod` | Modern, type-safe, what most new projects use in 2026 |
| Navigation | `go_router` | Official-quality |
| Secure token storage | `flutter_secure_storage` | Keychain on iOS, EncryptedSharedPreferences on Android |
| Forms | `flutter_form_builder` | Excellent validation patterns |
| File / image upload | `image_picker` + `dio` | Standard combo |
| Ads | `google_mobile_ads` | Official AdMob package |

---

## Open items / next steps after this decision

1. **Confirm backend OpenAPI generation path.** Backend is TypeScript but framework was unclear ("not sure"). Need to check `package.json` to determine NestJS / Express / Fastify / other. OpenAPI spec → auto-generated Dart API client saves an estimated 5–7 days of manual model-class writing.
2. **Authentication clarification.** JWT is the token format and is fine to keep. "Move to OAuth" likely means adding Google + Apple social login (1 day with `google_sign_in` + `sign_in_with_apple`). Not a full OAuth server rebuild.
3. **REST stays.** GraphQL migration would be self-sabotage right before a build sprint.
4. **MVP scope discipline.** 200+ endpoints exist — realistic UI throughput for a solo dev in initial sprint is ~30 screens covering 60–80 endpoints. The rest defer to v1.1.
5. **Timeline reset.** 20 days was discussed; realistic minimum for solo dev new to Flutter is 8–12 weeks to public launch. 20 days can produce a working internal demo on Android, not a store-ready dual-platform release.
6. **Setup checklist:** Mac (already have), install Flutter SDK, install Xcode + Android Studio, run `flutter doctor`, work through official "Your first Flutter app" codelab before any project code.
7. **One-time costs:** Apple Developer Program ($99/year) + Google Play ($25 one-time) + optional Untitled UI Figma PRO SOLO ($129) + optional Prokit Flutter template ($30). Approximate total: $154–283.

---

## The principle that ultimately decided it

Two factors made the choice unambiguous:

1. **Risk asymmetry.** Worst case with Flutter if "limitations" appear: 1–2 days of platform-channel code for that specific feature. Worst case with native dual-codebase: months of duplicate work for zero user-visible benefit. Flutter's downside is small and bounded; native's is large and compounding.

2. **Developer-profile fit.** A solo developer moving from C# benefits more from one language (Dart) and one mental model than from two new platform stacks. The cost of "going native to be safe" is enormous relative to the (near-zero) probability of hitting a Flutter limitation in this app's scope.

---

## Decision

**Build with Flutter (Dart). Single codebase for both iOS and Android. Android-first internal release, iOS via TestFlight in parallel.**
