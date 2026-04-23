import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import react from '@astrojs/react';
import vercel from '@astrojs/vercel/serverless';

export default defineConfig({
  integrations: [
    tailwind({ applyBaseStyles: false }),
    react(),
  ],
  output: 'hybrid',
  adapter: vercel({
    edgeMiddleware: false,
  }),
  site: 'https://portal.utamacs.org',
  base: '/',
  vite: {
    define: {
      'process.env.PROVIDER': JSON.stringify(process.env.PROVIDER ?? 'supabase'),
    },
  },
});
