import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : undefined,
  reporter: process.env.CI
    ? [['github'], ['junit', { outputFile: 'test-results/results.xml' }], ['html', { open: 'never' }]]
    : [['html', { open: 'on-failure' }]],
  use: {
    baseURL: process.env.PORTAL_URL ?? 'http://localhost:4321',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    // Auth setup — runs first, saves cookies per role
    {
      name: 'setup',
      testMatch: '**/auth.setup.ts',
    },

    // Member role tests — only *.member.spec.ts and shared module tests
    {
      name: 'member',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'tests/.auth/member.json',
      },
      dependencies: ['setup'],
      testIgnore: [
        '**/auth.setup.ts',
        '**/auth/login.spec.ts',      // public-only (does its own login)
        '**/auth/role-gates.spec.ts', // public-only (does its own login)
        '**/*.exec.spec.ts',
        '**/*.admin.spec.ts',
        '**/*.guard.spec.ts',
      ],
    },

    // Executive role tests — only *.exec.spec.ts
    {
      name: 'exec',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'tests/.auth/exec.json',
      },
      dependencies: ['setup'],
      testIgnore: [
        '**/auth.setup.ts',
        '**/auth/login.spec.ts',
        '**/auth/role-gates.spec.ts',
        '**/*.member.spec.ts',
        '**/*.admin.spec.ts',
        '**/*.guard.spec.ts',
      ],
    },

    // Admin role tests — only *.admin.spec.ts
    {
      name: 'admin',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'tests/.auth/admin.json',
      },
      dependencies: ['setup'],
      testIgnore: [
        '**/auth.setup.ts',
        '**/auth/login.spec.ts',
        '**/auth/role-gates.spec.ts',
        '**/*.member.spec.ts',
        '**/*.exec.spec.ts',
        '**/*.guard.spec.ts',
      ],
    },

    // Security guard role tests — only *.guard.spec.ts
    {
      name: 'guard',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'tests/.auth/guard.json',
      },
      dependencies: ['setup'],
      testIgnore: [
        '**/auth.setup.ts',
        '**/auth/login.spec.ts',
        '**/auth/role-gates.spec.ts',
        '**/*.member.spec.ts',
        '**/*.exec.spec.ts',
        '**/*.admin.spec.ts',
      ],
    },

    // Public / unauthenticated — login page + role-gates (do their own login)
    {
      name: 'public',
      use: { ...devices['Desktop Chrome'] },
      testMatch: ['**/auth/login.spec.ts', '**/auth/role-gates.spec.ts'],
    },

    // Mobile viewport (golden-path only)
    {
      name: 'mobile',
      use: {
        ...devices['iPhone 14'],
        storageState: 'tests/.auth/member.json',
      },
      dependencies: ['setup'],
      testMatch: ['**/mobile/*.spec.ts'],
    },

  ],
});
