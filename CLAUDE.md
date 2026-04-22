# UTA MACS Website — Claude Context

## Project Overview
Static website for **UTA MACS** (Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited), a residential cooperative in Kondakal, Shankarpalle, Ranga Reddy District, Telangana. Deployed at `utamacs.org` via GitHub Pages.

## Tech Stack
- **HTML** — semantic, ARIA-annotated markup
- **Tailwind CSS v3** — utility-first with a custom design system in `tailwind.config.js`
- **Vanilla JS** — no frameworks; `src/js/main.js` handles all interactivity
- **Font Awesome** — icons via CDN kit `5a2b2f0b4f.js`
- **Google Fonts** — Inter (primary font)
- **live-server** — local dev server

## Directory Layout
```
src/
  pages/          ← HTML pages (index, about, committee, contact, downloads, events, login, notices, portal, 404)
  components/     ← Shared fragments injected via fetch: nav.html, footer.html
  css/styles.css  ← Tailwind entry with @layer base/components/utilities
  js/main.js      ← App init, theme, mobile menu, scroll effects, accessibility
docs/             ← GitHub Pages output (manually synced from src/)
dist/             ← Local build output (npm run build)
tailwind.config.js
package.json
```

## NPM Scripts
| Command | What it does |
|---------|-------------|
| `npm run dev` | `npx live-server src --port=3000` |
| `npm run build` | `cp -r src/* dist/` |
| `npm run deploy` | build → git add dist → commit → push |

## Design System (tailwind.config.js)

### Brand Colors
| Token | Hex | Use |
|-------|-----|-----|
| `primary-600` | `#1E3A8A` | CTAs, nav active, headings |
| `secondary-500` | `#10B981` | Success, highlights, secondary CTAs |
| `accent-500` | `#F59E0B` | Warnings, badges, accents |
| `background` | `#FFFFFF` | Page background |
| `section-alt` | `#F8FAFC` | Alternating section backgrounds |
| `text-primary` | `#111827` | Body text |
| `text-secondary` | `#4B5563` | Muted/supporting text |
| `border-light` | `#E5E7EB` | Subtle borders |

### Custom Font Sizes
`text-hero`, `text-hero-lg`, `text-section`, `text-section-lg`, `text-card`, `text-card-lg`, `text-body`, `text-body-lg`, `text-small`, `text-button`

### Custom Shadows
`shadow-soft`, `shadow-medium`, `shadow-large`, `shadow-glow`, `shadow-glow-secondary`

### Custom Animations
`animate-fade-in`, `animate-slide-up`, `animate-bounce-gentle`, `animate-float`, `animate-shimmer`, `animate-morph`

## Reusable CSS Classes (src/css/styles.css)
- **Layout**: `container-custom`, `section`, `section-alt`, `section-hero`
- **Buttons**: `btn-primary`, `btn-secondary`, `btn-outline`
- **Cards**: `card-premium`, `card-feature`, `card-stats`, `card-hero`
- **Navigation**: `nav-link`, `mobile-nav-link`, `mobile-menu`
- **Scroll animations**: `animate-on-scroll` (add `.animate` class via IntersectionObserver)

## Component System
Nav and footer are loaded via `fetch()` in `main.js`:
```js
loadComponent('header-placeholder', 'components/nav.html');
loadComponent('footer-placeholder', 'components/footer.html');
```
Pages from `src/pages/` reference components at `../components/nav.html`.
The root `index.html` references them at `components/nav.html`.

## Navigation / Link Conventions
- Root `index.html` links to pages as `pages/about.html`, `pages/events.html`, etc.
- Pages inside `src/pages/` link back to root as `../index.html` and to siblings as `events.html`.
- `docs/` mirrors this same structure for GitHub Pages.

## Accessibility Standards
- All icons use `aria-hidden="true"`.
- Interactive elements have explicit `aria-label`.
- Focus rings on all interactive elements.
- Mobile menu uses `role="dialog"` with `aria-modal="true"`.

## JavaScript Conventions
- Vanilla JS only — no jQuery, no frameworks.
- Module-like functions: `initializeTheme()`, `initializeMobileMenu()`, `initializeScrollEffects()`, `initializeAccessibility()`, `initializePerformance()`.
- Global `AppState` object for shared state.
- `localStorage` for theme persistence (`'light'` | `'dark'`).

## Deployment
GitHub Pages serves from the `docs/` folder on the `main` branch. After editing `src/`, copy changes into `docs/` (or run `npm run deploy`).

## What NOT to Do
- Do not add npm dependencies for things vanilla JS handles fine.
- Do not convert to a JS framework — this is intentionally static HTML.
- Do not add backend/server logic — purely static.
- Do not change the Tailwind color token names; many CSS classes depend on them.
- Do not inline large CSS blocks in HTML; extend `styles.css` instead.
