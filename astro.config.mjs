import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  integrations: [tailwind({ applyBaseStyles: false })],
  output: 'static',
  // Public website pages live in src/site/pages/ — completely separate from
  // the portal pages in src/pages/ so that `astro build` (static mode) never
  // sees the portal's dynamic SSR routes, which would fail without getStaticPaths.
  srcDir: './src/site',
  outDir: './docs',
  build: {
    // 404.astro → docs/404.html (not docs/404/index.html) — required for GitHub Pages
    format: 'file',
  },
  site: 'https://utamacs.org',
  base: '/',
});
