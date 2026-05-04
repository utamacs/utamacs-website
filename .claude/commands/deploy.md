# Deploy to GitHub Pages

Syncs `src/` changes to `docs/` and pushes to GitHub Pages.

## Usage
`/deploy`

## Steps
1. Run `npm run build` (copies `src/*` to `dist/`)
2. Manually sync changed files from `src/` to `docs/` preserving the same paths:
   - `src/pages/*.html` → `docs/pages/*.html`
   - `src/components/*.html` → `docs/components/*.html` (if docs uses them)
   - `src/css/styles.css` → `docs/styles.css` (docs uses compiled CSS directly)
   - `src/js/main.js` → `docs/script.js` (docs uses this name)
3. Stage and commit: `git add docs/ && git commit -m "Deploy: <summary>"`
4. Push: `git push origin main`

## Important notes
- `docs/` is what GitHub Pages serves at `utamacs.org`
- `docs/CNAME` contains `utamacs.org` — never delete it
- `docs/styles.css` is the compiled/built CSS, not the Tailwind source
- After pushing, changes go live at https://utamacs.org within ~1 minute
- Always verify the live site after deploying
