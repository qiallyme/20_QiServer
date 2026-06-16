# Supabase Local Development & Configurations

This directory manages the Supabase database configurations, local services, environment bindings, schema documentations, and versioned migrations for **QiSystem**.

## Folder Layout

```text
50_data/supabase/
├── .env.example           # Example local environment variable configurations
├── connection-map.md      # Schema access mappings, local port mappings, and URLs
├── directus_integration.md # Directus configuration, classifications, and guides
└── qisupabase/            # Supabase Workspace Configuration
    ├── config.toml        # Local Supabase service configurations (ports, services, JWT, etc.)
    ├── functions/         # Supabase Edge Functions (TypeScript)
    ├── migrations/        # Canonical timestamped SQL migration files
    ├── policies/          # Row Level Security (RLS) policies
    ├── schemas/           # Markdown-based schema documentation and Data Dictionary
    └── sql/               # Organized, runnable SQL execution scripts for local development
```

## Essential CLI Commands

Ensure you have the [Supabase CLI](https://supabase.com/docs/guides/cli) installed and Docker running on your system.

### 1. Initialize local services
Start local Supabase services (PostgreSQL, GoTrue/Auth, Storage, Edge Functions, Studio):
```bash
supabase start
```

### 2. Stop local services
Stop and park local services without clearing database states:
```bash
supabase stop
```

### 3. Reset database state
Reset the local database, recreate schemas, and rerun migrations in `migrations/`:
```bash
supabase db reset
```

### 4. Create a new migration
Generate a new timestamped migration file under `migrations/`:
```bash
supabase migration new migration_name
```

---

## Development Promotion Workflow

To maintain a clean and reliable database architecture, follow this progressive promotion loop:

1. **Exploration & Prototyping**:
   * Write and test queries inside the Supabase Studio SQL Editor or local PostgreSQL clients.

2. **Modular SQL Organization**:
   * Once a feature's schema is verified, document and structure its creation statements inside the appropriate subdirectory under `qisupabase/sql/` (e.g. `01_tables/`, `04_rules/`, or `05_pipeline/`).
   * Follow the run order schema described in `sql/README_RUN_ORDER.md`.

3. **Staging/Production Promotion**:
   * Once SQL code under `sql/` is proven stable and static, generate a migration using `supabase migration new` and place the creation script there to declare it as a deployment checkpoint.
   * Do **not** modify old, existing migration files directly; always create a new incremental migration file for schema updates.
