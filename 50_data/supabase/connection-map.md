# Supabase Connection Map

This connection map coordinates endpoints, port numbers, database URLs, and schema classifications for the local development environment.

## Service Endpoint & Port Configuration

Based on `qisupabase/config.toml` and Directus deployment scripts, local services are mapped to the following ports:

| Service               | External Endpoint / URL                 | Port   | Notes / Purpose                               |
| --------------------- | --------------------------------------- | ------ | --------------------------------------------- |
| **API Gateway**       | `http://localhost:54321`                | `54321`| Exposed REST and GraphQL (PostgREST) API      |
| **PostgreSQL DB**     | `postgresql://postgres:postgres@...`    | `54322`| Native database link (user: `postgres`)       |
| **Supabase Studio**   | `http://localhost:54323`                | `54323`| Visual administration console dashboard       |
| **Inbucket (Email)**  | `http://localhost:54324`                | `54324`| Local SMTP web UI console for email testing   |
| **Directus (API/UI)** | `http://localhost:8055`                 | `8055` | Primary admin, API, and visual data management layer (Postgres mapping) |
| **NocoDB (UI)**       | `http://localhost:8080` (Deprecated)    | `8080` | Deprecated alpha spreadsheet UI layer (scheduled for decommissioning) |
| **Shadow Database**   | `localhost`                             | `54320`| Used internally by CLI for generating diffs   |
| **DB Connection Pool**| `localhost`                             | `54329`| Transaction/session level connection pooling  |
| **Analytics Engine**  | `localhost`                             | `54327`| Event capturing and log analytics backend     |
| **Deno Inspector**    | `localhost`                             | `8083` | Attach debugger to Edge Runtime Functions     |

---

## Connection Strings

Configure local apps, packages (`packages/database`), and services using these URLs.

### Direct Database Connection
```connection_string
postgresql://postgres:postgres@localhost:54322/postgres
```

### Local API Endpoint (for Supabase Client SDK)
```connection_string
SUPABASE_URL=http://localhost:54321
```

---

## Database Schema Access Matrix

Applications connecting to the database should access schemas based on the following classification rules:

### 1. Exposed Client APIs (Exposed in REST/GraphQL Search Path)
* **`public`**: Default schema. Avoid adding QiSystem domain tables here. Used primarily for platform mappings.
* **`graphql_public`**: public GraphQL access interface.

### 2. QiSystem Domain Schemas (Internal/Strict Boundaries)
* **`qisystem`**: Main active schema for dynamic data (libraries, records, rules, events, attachments). Access is controlled via Row-Level Security (RLS) rules and validated via triggers.
* **`qifinance`**: Reserved namespace for strict double-entry ledger bookkeeping, accounts, and payments.
* **`qicare`**: Reserved namespace for patient logs, medical/vitals records, appointments, and care coordination.

### 3. Platform Internal Infrastructure
* **`auth`**: Supabase managed auth endpoints. Connects to `qisystem` and `qicare` via automated Postgres triggers on user creation.
* **`extensions`**: Reserved namespace where Postgres extensions (e.g. pgvector, uuid-ossp) are activated. Do not place tables here.
