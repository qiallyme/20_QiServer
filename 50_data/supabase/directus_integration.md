# Directus Integration & Administration Guide

This guide coordinates the deployment, schema integration, and development workflow for using **Directus** as the visual administration console, CRUD interface, and instant API gateway for **QiSystem** database backends on **Supabase / PostgreSQL**.

---

## 1. Architectural Boundaries

Per [ADR-0019](file:///C:/QiLabs/_QiOS_DNA/05_Decisions/ADR-0019_directus_as_supabase_admin_and_api_layer.md):
- **Supabase/Postgres is the Absolute Source of Truth:** Directus is a non-intrusive visualization, administration, and REST/GraphQL interface that sits on top of Postgres. It does not replace the database engine.
- **Directus is NOT the Schema Owner:** Schema changes must be driven through SQL code in this repository, not clicked together in the Directus UI.
- **SQL Migrations Take Precedence:** All structural definitions, modifications, triggers, and table definitions must continue to be tracked in `sql/` and deployed via timestamped migrations in `migrations/`.

> [!CAUTION]
> **DO NOT MANAGE SCHEMAS BLINDLY IN DIRECTUS**
> Modifying or creating columns, tables, or indices within the Directus Data Studio UI changes the underlying database schema directly. If you perform a schema edit in Directus, you **must** immediately capture the resulting SQL schema definition and check it into the repository under a timestamped migration file. Failure to do so will result in drift between local repos and production instances.

---

## 2. Table and Collection Classification

All tables and collections visible to Directus must follow this classification schema:

| Category | Database Namespace / Table Names | Purpose | Directus Access Rules |
| :--- | :--- | :--- | :--- |
| **Canonical System Tables** | `qisystem.libraries`, `qisystem.records`, `qisystem.record_links`, `qisystem.tags`, `qisystem.record_tags`, `qisystem.attachments`, `qisystem.events`, `qisystem.event_links` | Reusable core relational spine representing entities and units of reality (QiBits). See [qisystem.md](file:///C:/QiLabs/20_QiSystem/50_data/supabase/qisupabase/schemas/qisystem.md). | **Read-Write.** Configure fields to match data dictionary definitions. |
| **Import / Staging Tables** | `qisystem.staging_firefly_transactions`, `qisystem.stage_flat_contacts` | Landing tables for raw third-party exports prior to validation and ingestion. | **Read-Only / Purge.** Do not update structure. |
| **Finance Taxonomy Tables** | `qifinance.accounts`, `qifinance.categories`, `qifinance.budgets_bills`, `qifinance.transaction_types` | Bookkeeping ledgers and financial classifications. | **Restricted Read-Write.** Manage tags and categories safely. |
| **Care / Medical Support** | `qicare.daily_notes`, `qicare.medication_inventory`, `qicare.vitals_logs` | Daily caregiver updates, vitals tracking, and medication inventories. | **Read-Write (Highly Restricted).** Protect sensitive health data with strict Directus user roles. |
| **Legal / Case / Evidence** | `qicase.matters`, `qicase.evidence` | Legal timeline entries and structured documents linked to active disputes. | **Read-Write.** Directus maps file fields to secure attachments. |
| **Directus System Tables** | `public.directus_*` (e.g., `directus_fields`, `directus_relations`, `directus_roles`) | Directus configuration metadata, presets, dashboards, activity history, and settings. | **System Managed.** Leave schema to Directus engine; exclude from domain git migrations. |

---

## 3. SQL & Schema Reference Matrix

Directus collections and field definitions map directly to the structured SQL initialization files in the repository. Refer to these files when setting up or reviewing collections in Directus:

1. **Core Database Setup**:
   * Refer to [sql/00_core/00.001_create_schemas.sql](file:///C:/QiLabs/20_QiSystem/50_data/supabase/qisupabase/sql/00_core/00.001_create_schemas.sql) for details on Postgres namespaces and custom schemas used by Directus.
2. **Canonical Table Structures**:
   * Refer to [sql/01_tables/01.001_libraries.sql](file:///C:/QiLabs/20_QiSystem/50_data/supabase/qisupabase/sql/01_tables/01.001_libraries.sql) through `01.008_event_links.sql` for primary key constraints, foreign key cascades, and column types.
3. **Data Integrity Triggers**:
   * Refer to [sql/01_tables/01.009_records_updated_at_trigger.sql](file:///C:/QiLabs/20_QiSystem/50_data/supabase/qisupabase/sql/01_tables/01.009_records_updated_at_trigger.sql) to understand how `updated_at` values are automatically maintained when modified by Directus or Edge functions.
4. **Data Dictionary**:
   * Refer to [schemas/data_dictionary.md](file:///C:/QiLabs/20_QiSystem/50_data/supabase/qisupabase/schemas/data_dictionary.md) for expected JSON shapes inside flexible database record columns (`qisystem.records.data`).

---

## 4. Environment Variables Setup

Ensure that Directus is configured with these environment variables to align with the Supabase local environment. Create/update your local `.env` file referencing the structure below:

```env
# Directus Server Configuration
PORT=8055
KEY=your-random-session-secret-key-placeholder
SECRET=your-random-token-signing-secret-placeholder

# Directus Database Binding (Exposed Supabase DB Port: 54322)
DB_CLIENT=pg
DB_CONNECTION_STRING=postgresql://postgres:postgres@localhost:54322/postgres

# Directus Internal System Schema Isolation
DB_META_SCHEMA=public

# Admin Initialization Credentials
ADMIN_EMAIL=admin@qisystem.local
ADMIN_PASSWORD=your-super-secure-admin-password-placeholder
```

---

## 5. NocoDB Deprecation and Migration Status

> [!NOTE]
> **NocoDB Deprecation Status: Replaced by Directus**
> NocoDB configurations are now frozen. Do not create new NocoDB configurations.
> Existing NocoDB endpoints will remain active in the local developer stack *only* until the server validation checklist is completed and the Directus connection is verified.

---

## 6. Server Validation Checklist

Follow these steps to verify your Directus installation against the Supabase database:

- [ ] **Docker Service Running:** Verify that local Docker daemon is active and Supabase services are initialized (`supabase start`).
- [ ] **Directus Connection Bind:** Confirm Directus can connect to host port `54322` and read database contents.
- [ ] **System Table Check:** Verify that Directus has generated its `public.directus_*` metadata tables in the database.
- [ ] **Schema Introspection:** Open the Directus Data Studio, navigate to Settings -> Data Model, and verify that the schemas (`qisystem`, `qicare`, `qifinance`) are introspected and listed correctly.
- [ ] **RLS Validation:** Test a restricted Directus role with a custom user account to verify it respects PostgreSQL policies.
- [ ] **Configuration Snapshot:** Generate a schema configuration backup:
  ```bash
  npx directus schema snapshot ./directus-schema-snapshot.yaml
  ```
