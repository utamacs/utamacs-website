# New Database Migration

Creates a correctly sequenced Supabase SQL migration file following all UTAMACS database standards.

## Usage
`/new-migration <description>`

Example: `/new-migration gallery_albums`

## What this agent does

1. Read the `supabase/migrations/` directory to find the current highest sequence number.
2. The new file is `supabase/migrations/{next_number}_{description}.sql` where `{next_number}` is padded to the same width as existing files (e.g. `055_gallery_albums.sql`).
3. Apply every rule from CLAUDE.md section 5 (Database Standards) when writing the migration.

### Template for a new table migration

```sql
-- Migration: {seq}_{description}
-- Purpose: {one-line description of what this adds}

-- ─── Table ───────────────────────────────────────────────────────────────────

CREATE TABLE {table_name} (
  -- Required on every UTAMACS table:
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,

  -- Domain columns — annotate personal data:
  -- name     text NOT NULL CHECK (length(name) BETWEEN 1 AND 255),
  -- phone    text,  -- personal data: contact for {purpose}

  -- Soft-delete support (add if records should be archivable):
  -- is_active bool NOT NULL DEFAULT true,

  -- Audit columns:
  created_by  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ─── Indexes ─────────────────────────────────────────────────────────────────

CREATE INDEX idx_{table_name}_society ON {table_name}(society_id);
-- Add additional indexes for common filter/sort columns

-- ─── Row Level Security ───────────────────────────────────────────────────────
-- MANDATORY: Every new table must have RLS enabled.

ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY;

-- READ: all authenticated members of the society can read
CREATE POLICY "society_read_{table_name}" ON {table_name}
  FOR SELECT
  USING (
    society_id IN (
      SELECT society_id FROM profiles WHERE id = auth.uid()
    )
  );

-- WRITE: executive, secretary, president, or is_admin can create/update/delete
CREATE POLICY "exec_manage_{table_name}" ON {table_name}
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
  );

-- SPECIAL POLICIES (add as needed, removing the default write policy above):
-- Member writes their own records:
-- CREATE POLICY "member_insert_{table_name}" ON {table_name}
--   FOR INSERT WITH CHECK (created_by = auth.uid());
-- CREATE POLICY "member_select_own_{table_name}" ON {table_name}
--   FOR SELECT USING (created_by = auth.uid() OR <exec check>);

-- ─── IMMUTABLE tables — add these instead of the write policy above if the
--     table is a ledger/audit record (like payments, audit_logs):
-- (no UPDATE policy)
-- (no DELETE policy)
-- Only INSERT is allowed.
```

### Template for ALTER TABLE (extending an existing table)

```sql
-- Migration: {seq}_{description}
-- Purpose: Extend {existing_table} with {feature} fields

ALTER TABLE {existing_table}
  ADD COLUMN IF NOT EXISTS {column_name} {type} {constraints},
  ADD COLUMN IF NOT EXISTS {column_name2} {type} {constraints};

-- Add index if the new column will be filtered on
CREATE INDEX IF NOT EXISTS idx_{existing_table}_{column_name}
  ON {existing_table}({column_name});
```

### Rules enforced in every migration

- `IF NOT EXISTS` on all `CREATE INDEX` and `ADD COLUMN IF NOT EXISTS` — migrations must be re-runnable
- All new tables: `id`, `society_id`, `created_at` are mandatory
- All new tables: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` immediately after CREATE TABLE
- All new tables: at minimum a SELECT policy and a write policy
- `payments`, `audit_logs`, `privacy_consents`: never add UPDATE or DELETE policies
- Personal data columns get a SQL comment: `-- personal data: {purpose}`
- Foreign keys to `auth.users(id)`: use `ON DELETE SET NULL` for optional references, `ON DELETE CASCADE` only for records owned entirely by that user
- Foreign keys to `societies(id)`: always `ON DELETE CASCADE`
- Enum-like text columns: always have a `CHECK` constraint listing allowed values
- `text` columns with user input: always have `CHECK (length(col) <= N)` or use `varchar(N)`

### After writing the file

Tell the user:
1. The exact filename created
2. Any placeholder columns they need to fill in
3. Remind them to run `npm run supabase:types` after applying the migration to regenerate TypeScript types
