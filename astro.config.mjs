import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  integrations: [tailwind({ applyBaseStyles: false })],
  output: 'static',
  outDir: './docs',
  build: {
    // 404.astro → docs/404.html (not docs/404/index.html) — required for GitHub Pages
    format: 'file',
  },
  site: 'https://utamacs.org',
  base: '/',
});
