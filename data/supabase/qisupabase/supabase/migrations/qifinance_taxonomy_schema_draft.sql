-- QiFinance taxonomy starter schema
-- Generated from Firefly transaction export: 2026_06_14_transaction_export.csv
-- Use this as a draft. Review naming and RLS before production deploy.

create schema if not exists qifinance;

create table if not exists qifinance.import_batches (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,
  source_file_name text,
  source_file_hash text,
  imported_at timestamptz not null default now(),
  row_count integer,
  notes text
);

create table if not exists qifinance.firefly_transactions_raw (
  id uuid primary key default gen_random_uuid(),
  import_batch_id uuid references qifinance.import_batches(id) on delete set null,
  raw_row jsonb not null,

  firefly_user_id text,
  firefly_group_id text,
  firefly_journal_id text,
  firefly_import_hash text,
  firefly_import_hash_v2 text,
  external_id text,

  transaction_type text,
  transaction_date timestamptz,
  amount numeric(14,2),
  currency_code text,
  description text,

  source_name text,
  source_type text,
  destination_name text,
  destination_type text,

  category_name text,
  budget_name text,
  bill_name text,
  raw_tags text,
  notes text,

  created_at timestamptz not null default now()
);

create unique index if not exists firefly_transactions_raw_import_hash_v2_uidx
on qifinance.firefly_transactions_raw (firefly_import_hash_v2)
where firefly_import_hash_v2 is not null;

create table if not exists qifinance.accounts (
  id uuid primary key default gen_random_uuid(),
  canonical_name text not null,
  normalized_key text generated always as (lower(regexp_replace(canonical_name, '[^a-zA-Z0-9]+', '-', 'g'))) stored,
  account_type text not null,
  institution_name text,
  owner_scope text,
  firefly_name text,
  firefly_account_type text,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  unique (normalized_key, account_type)
);

create table if not exists qifinance.counterparties (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  normalized_key text generated always as (lower(regexp_replace(display_name, '[^a-zA-Z0-9]+', '-', 'g'))) stored,
  counterparty_type text,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  unique (normalized_key)
);

create table if not exists qifinance.categories (
  id uuid primary key default gen_random_uuid(),
  domain_code text,
  domain text not null,
  subcategory text,
  canonical_name text not null unique,
  firefly_name text,
  parent_id uuid references qifinance.categories(id) on delete set null,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists qifinance.tags (
  id uuid primary key default gen_random_uuid(),
  tag_key text not null unique,
  display_name text not null,
  tag_type text,
  firefly_name text,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists qifinance.budgets (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category_id uuid references qifinance.categories(id) on delete set null,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists qifinance.bills (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  counterparty_id uuid references qifinance.counterparties(id) on delete set null,
  category_id uuid references qifinance.categories(id) on delete set null,
  budget_id uuid references qifinance.budgets(id) on delete set null,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists qifinance.transactions (
  id uuid primary key default gen_random_uuid(),
  source_system text not null default 'firefly',
  source_record_id text,
  import_batch_id uuid references qifinance.import_batches(id) on delete set null,

  transaction_date timestamptz not null,
  amount numeric(14,2) not null,
  currency_code text not null default 'USD',
  transaction_type text not null,
  description text not null,

  source_account_id uuid references qifinance.accounts(id) on delete set null,
  destination_account_id uuid references qifinance.accounts(id) on delete set null,
  source_counterparty_id uuid references qifinance.counterparties(id) on delete set null,
  destination_counterparty_id uuid references qifinance.counterparties(id) on delete set null,

  category_id uuid references qifinance.categories(id) on delete set null,
  budget_id uuid references qifinance.budgets(id) on delete set null,
  bill_id uuid references qifinance.bills(id) on delete set null,

  notes text,
  raw_tags text,

  firefly_journal_id text,
  firefly_group_id text,
  firefly_import_hash_v2 text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists transactions_firefly_import_hash_v2_uidx
on qifinance.transactions (firefly_import_hash_v2)
where firefly_import_hash_v2 is not null;

create table if not exists qifinance.transaction_tags (
  transaction_id uuid not null references qifinance.transactions(id) on delete cascade,
  tag_id uuid not null references qifinance.tags(id) on delete cascade,
  primary key (transaction_id, tag_id)
);

create table if not exists qifinance.coa_crosswalk (
  id uuid primary key default gen_random_uuid(),
  coa_source text not null,
  old_account_number text,
  old_full_name text not null,
  old_parent text,
  old_type text,
  old_detail_type text,

  canonical_domain_code text,
  canonical_domain text,
  canonical_code text,
  canonical_name text,
  canonical_object_type text not null,

  firefly_name text,
  firefly_object_type text,
  qifinance_target_table text,

  status text not null default 'candidate',
  tax_line text,
  notes text,
  created_at timestamptz not null default now()
);
