import { defineConfig } from 'vitest/config';
import { loadEnv } from 'vite';
import { resolve } from 'path';

export default defineConfig(({ mode }) => {
  // Load .env.test (or .env) from the project root so test credentials are available
  const env = loadEnv(mode ?? 'test', resolve(process.cwd()), '');

  return {
    test: {
      include: ['tests/api/**/*.test.ts'],
      environment: 'node',
      globals: false,
      testTimeout: 30000,  // API calls need more time
      hookTimeout: 60000,
      env,  // inject all loaded vars into process.env for test files
    },
  };
});
