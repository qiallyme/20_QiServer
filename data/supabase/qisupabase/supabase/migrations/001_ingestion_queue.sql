-- Migration: ingestion_queue table for semantic ingestion worker
-- Layer: 6 semantic ingestion
-- Worker: gina-ingestion

create table if not exists public.ingestion_queue (
  id uuid primary key default gen_random_uuid(),
  file_path text not null unique,
  slug text not null,
  qid text,
  realm text,
  realm_guess text,
  realm_slug text,
  mime_type text,
  file_ext text,
  content_hash text,
  extracted_text text,
  route_confidence numeric default 0,
  status text not null default 'pending',  -- pending|in_progress|complete|quarantined
  meta jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists ingestion_queue_status_idx on public.ingestion_queue(status);
create index if not exists ingestion_queue_created_at_idx on public.ingestion_queue(created_at);

