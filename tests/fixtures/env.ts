// Centralised test credentials — sourced from env vars set in GitHub Secrets
// or a local .env.test file (never committed).
export const TEST_USERS = {
  member: {
    email: process.env.TEST_MEMBER_EMAIL ?? '',
    password: process.env.TEST_MEMBER_PASS ?? '',
    authFile: 'tests/.auth/member.json',
  },
  exec: {
    email: process.env.TEST_EXEC_EMAIL ?? '',
    password: process.env.TEST_EXEC_PASS ?? '',
    authFile: 'tests/.auth/exec.json',
  },
  admin: {
    email: process.env.TEST_ADMIN_EMAIL ?? '',
    password: process.env.TEST_ADMIN_PASS ?? '',
    authFile: 'tests/.auth/admin.json',
  },
  guard: {
    email: process.env.TEST_GUARD_EMAIL ?? '',
    password: process.env.TEST_GUARD_PASS ?? '',
    authFile: 'tests/.auth/guard.json',
  },
} as const;
