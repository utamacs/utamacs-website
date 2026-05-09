import { defineConfig, passthroughImageService } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import react from '@astrojs/react';
import vercel from '@astrojs/vercel/serverless';

export default defineConfig({
  integrations: [
    tailwind({ applyBaseStyles: false }),
    react(),
  ],
  image: {
    // Portal uses CSS icons/Tailwind — no Astro <Image> components.
    // Passthrough avoids the sharp native-binary requirement at build time.
    service: passthroughImageService(),
  },
  output: 'hybrid',
  adapter: vercel({
    edgeMiddleware: false,
    maxDuration: 60,
  }),
  site: 'https://portal.utamacs.org',
  base: '/',
  vite: {
    define: {
      'process.env.PROVIDER': JSON.stringify(process.env.PROVIDER ?? 'supabase'),
    },
  },
});
