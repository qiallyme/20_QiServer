-- Migration: Extend semantic_profile to support file-level stubs
-- Layer: 6 semantic ingestion
-- Worker: gina-ingestion
--
-- Adds file-level semantic profile support before chunking.
-- Makes chunk_id/chunk_text optional for file-level records.
-- Adds file_path as unique conflict target for upserts.

-- Add file-level columns to semantic_profile
alter table public.semantic_profile
  add column if not exists qid text,
  add column if not exists slug text,
  add column if not exists realm text,
  add column if not exists realm_slug text,
  add column if not exists file_path text unique,
  add column if not exists mime_type text,
  add column if not exists file_ext text,
  add column if not exists content_hash text,
  add column if not exists extracted_text text,
  add column if not exists chunk_count integer default 0,
  add column if not exists embedding_status text default 'pending',  -- pending|chunked|embedded|complete
  add column if not exists meta jsonb default '{}'::jsonb,
  add column if not exists updated_at timestamptz default now();

-- Make chunk_id and chunk_text optional (for file-level stubs)
alter table public.semantic_profile
  alter column chunk_id drop not null,
  alter column chunk_text drop not null;

-- Add index for file_path lookups
create index if not exists semantic_profile_file_path_idx on public.semantic_profile(file_path) where file_path is not null;

-- Add index for embedding_status filtering
create index if not exists semantic_profile_embedding_status_idx on public.semantic_profile(embedding_status) where embedding_status is not null;

-- Add constraint: either (node_id + chunk_id) OR file_path must be present
alter table public.semantic_profile
  add constraint semantic_profile_file_or_chunk_check
  check (
    (node_id is not null and chunk_id is not null) or
    (file_path is not null)
  );

