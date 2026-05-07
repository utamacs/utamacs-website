import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/api/**/*.test.ts'],
    environment: 'node',
    globals: false,
    testTimeout: 30000,  // API calls need more time
    hookTimeout: 60000,
    dotenv: true,  // loads .env.test automatically
  },
});
