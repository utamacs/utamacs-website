// Feature registry — canonical names for every permission-gated capability.
// `locked: true` = byelaw-mandated; admin cannot toggle via RBAC UI.
// `locked: false` = operational; admin can toggle per role in /portal/admin/permissions.

export const FEATURES = {
  // ── User Management ───────────────────────────────────────────────────────
  'users.view_directory':      { label: 'View member directory',                    locked: false },
  'users.invite_member':       { label: 'Invite new members',                       locked: false },
  'users.invite_committee':    { label: 'Invite committee members',                 locked: true  },
  'users.change_role':         { label: 'Change member roles',                      locked: true  },
  'users.deactivate':          { label: 'Deactivate members',                       locked: false },

  // ── HOTO ──────────────────────────────────────────────────────────────────
  'hoto.view':                 { label: 'View HOTO items',                          locked: true  },
  'hoto.create':               { label: 'Create/edit HOTO items',                   locked: false },
  'hoto.upload':               { label: 'Upload documents',                         locked: false },
  'hoto.comment':              { label: 'Add comments',                             locked: false },
  'hoto.advance_status':       { label: 'Advance item status',                      locked: false },
  'hoto.approve_president':    { label: 'President approval gate',                  locked: true  },
  'hoto.approve_secretary':    { label: 'Secretary approval gate',                  locked: true  },
  'hoto.bypass_required_docs': { label: 'Bypass required document gate',            locked: true  },

  // ── Snag ──────────────────────────────────────────────────────────────────
  'snag.view':                 { label: 'View snag list',                           locked: true  },
  'snag.create':               { label: 'Create/edit snags',                        locked: false },
  'snag.delete':               { label: 'Delete snags',                             locked: true  },
  'snag.verify_close':         { label: 'Mark snags as verified closed',            locked: true  },

  // ── Vendor ────────────────────────────────────────────────────────────────
  'vendor.view':               { label: 'View vendor evaluations',                  locked: true  },
  'vendor.view_quotes':        { label: 'View vendor quotes',                       locked: false },
  'vendor.vote':               { label: 'Cast vendor vote',                         locked: false },
  'vendor.open_voting':        { label: 'Open/close voting',                        locked: false },
  'vendor.final_select':       { label: 'Confirm final vendor selection',           locked: true  },

  // ── Finance ───────────────────────────────────────────────────────────────
  'finance.view':              { label: 'View financial records',                   locked: false },
  'finance.enter':             { label: 'Enter maintenance/expense records',        locked: false },
  'finance.approve_10k':       { label: 'Approve expenses ≤₹10K (§9.11a)',         locked: true  },
  'finance.approve_20k':       { label: 'Approve expenses ≤₹20K (§9.11a)',         locked: true  },
  'finance.open_board_vote':   { label: 'Open Board resolution vote ≤₹50K (§9.11b)', locked: true },
  'finance.view_member_phones':{ label: 'View member phone numbers',               locked: true  },

  // ── Notices ───────────────────────────────────────────────────────────────
  'notice.view':               { label: 'View formal notices',                      locked: false },
  'notice.send':               { label: 'Send formal notices',                      locked: false },

  // ── Admin ─────────────────────────────────────────────────────────────────
  'admin.delegation':          { label: 'Manage delegation settings',               locked: true  },
  'admin.elections':           { label: 'Run committee election update',            locked: true  },
  'admin.permissions':         { label: 'Manage feature permissions',               locked: true  },
  'admin.import':              { label: 'Bulk data import',                         locked: false },

  // ── Audit ─────────────────────────────────────────────────────────────────
  'audit.view':                { label: 'View audit log',                           locked: false },
} as const;

export type Feature = keyof typeof FEATURES;
export const ALL_FEATURES = Object.keys(FEATURES) as Feature[];
