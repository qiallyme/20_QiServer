create extension if not exists pgcrypto;

create table if not exists gpt_memories (
  id uuid primary key default gen_random_uuid(),
  user_id text not null default 'main_user',
  content text not null,
  category text not null default 'other',
  importance int not null default 5 check (importance between 1 and 10),
  tags text[] not null default '{}',
  source text not null default 'conversation',
  confidence numeric not null default 1 check (confidence >= 0 and confidence <= 1),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists gpt_configs (
  id uuid primary key default gen_random_uuid(),
  user_id text not null default 'main_user',
  namespace text not null default 'default',
  key text not null,
  value jsonb not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, namespace, key)
);

create table if not exists gpt_rules (
  id uuid primary key default gen_random_uuid(),
  user_id text not null default 'main_user',
  rule text not null,
  priority int not null default 50 check (priority between 1 and 100),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists gpt_instructions (
  id uuid primary key default gen_random_uuid(),
  user_id text not null unique default 'main_user',
  instructions text,
  style text,
  boundaries text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists gpt_memories_user_id_idx on gpt_memories(user_id);
create index if not exists gpt_memories_category_idx on gpt_memories(category);
create index if not exists gpt_memories_importance_idx on gpt_memories(importance);
create index if not exists gpt_rules_user_id_idx on gpt_rules(user_id);
create index if not exists gpt_configs_user_id_idx on gpt_configs(user_id);

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_gpt_memories_updated_at on gpt_memories;
create trigger set_gpt_memories_updated_at
before update on gpt_memories
for each row
execute function set_updated_at();

drop trigger if exists set_gpt_configs_updated_at on gpt_configs;
create trigger set_gpt_configs_updated_at
before update on gpt_configs
for each row
execute function set_updated_at();

drop trigger if exists set_gpt_rules_updated_at on gpt_rules;
create trigger set_gpt_rules_updated_at
before update on gpt_rules
for each row
execute function set_updated_at();

drop trigger if exists set_gpt_instructions_updated_at on gpt_instructions;
create trigger set_gpt_instructions_updated_at
before update on gpt_instructions
for each row
execute function set_updated_at();

alter table gpt_memories enable row level security;
alter table gpt_configs enable row level security;
alter table gpt_rules enable row level security;
alter table gpt_instructions enable row level security;
