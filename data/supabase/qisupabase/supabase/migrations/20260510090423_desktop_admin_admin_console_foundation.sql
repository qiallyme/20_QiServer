alter table care.medications
  add column if not exists location text,
  add column if not exists purpose text,
  add column if not exists risk_notes text,
  add column if not exists verified_source text,
  add column if not exists last_verified_at timestamptz;

alter table care.care_plans
  add column if not exists version integer not null default 1,
  add column if not exists effective_date date,
  add column if not exists mobility_notes text,
  add column if not exists breathing_notes text,
  add column if not exists medication_notes text,
  add column if not exists pain_notes text,
  add column if not exists diet_hydration_notes text,
  add column if not exists fall_risk_notes text,
  add column if not exists cognitive_behavior_notes text,
  add column if not exists caregiver_instructions text;

update care.care_plans
set status = coalesce(nullif(btrim(status), ''), 'draft');

alter table care.care_plans
  drop constraint if exists care_plans_status_check;

alter table care.care_plans
  add constraint care_plans_status_check
  check (status in ('draft', 'active', 'archived'));

create unique index if not exists idx_care_plans_one_active_per_patient
  on care.care_plans (patient_id)
  where status = 'active';

create table if not exists care.elimination_logs (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references care.patients(id) on delete cascade,
  event_type text not null,
  occurred_at timestamptz not null default now(),
  amount text,
  bowel_consistency text,
  urine_color text,
  pain_or_burning text,
  accident_or_incontinence boolean,
  assistance_needed text,
  location text,
  notes text,
  created_by text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint elimination_logs_event_type_check
    check (event_type in ('bowel_movement', 'urination', 'both', 'attempted')),
  constraint elimination_logs_amount_check
    check (amount is null or amount in ('none', 'small', 'medium', 'large')),
  constraint elimination_logs_bowel_consistency_check
    check (bowel_consistency is null or bowel_consistency in ('hard', 'formed', 'soft', 'loose', 'diarrhea', 'unknown')),
  constraint elimination_logs_urine_color_check
    check (urine_color is null or urine_color in ('clear', 'pale', 'yellow', 'dark', 'cloudy', 'blood_seen', 'unknown')),
  constraint elimination_logs_pain_or_burning_check
    check (pain_or_burning is null or pain_or_burning in ('yes', 'no', 'unknown')),
  constraint elimination_logs_assistance_needed_check
    check (assistance_needed is null or assistance_needed in ('none', 'setup', 'standby', 'hands_on', 'full_assist'))
);

create table if not exists care.checklist_templates (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references care.patients(id) on delete cascade,
  title text not null,
  category text,
  is_active boolean not null default true,
  version integer not null default 1,
  notes text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists care.checklist_items (
  id uuid primary key default gen_random_uuid(),
  checklist_template_id uuid not null references care.checklist_templates(id) on delete cascade,
  label text not null,
  description text,
  sort_order integer not null default 0,
  is_required boolean not null default false,
  default_status text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint checklist_items_default_status_check
    check (default_status is null or default_status in ('pending', 'done', 'skipped', 'not_needed', 'issue'))
);

create table if not exists care.care_schedule_templates (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references care.patients(id) on delete cascade,
  title text not null,
  category text not null default 'other',
  description text,
  default_time time,
  recurrence_rule text not null,
  priority text not null default 'normal',
  is_active boolean not null default true,
  checklist_template_id uuid references care.checklist_templates(id) on delete set null,
  notes text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint care_schedule_templates_category_check
    check (category in ('meds', 'hygiene', 'mobility', 'breathing', 'meals', 'inventory', 'admin', 'appointment_prep', 'bedtime', 'morning', 'other')),
  constraint care_schedule_templates_priority_check
    check (priority in ('low', 'normal', 'high', 'critical'))
);

create table if not exists care.scheduled_care_tasks (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references care.patients(id) on delete cascade,
  template_id uuid not null references care.care_schedule_templates(id) on delete cascade,
  title text not null,
  scheduled_for timestamptz not null,
  due_window_start timestamptz,
  due_window_end timestamptz,
  status text not null default 'pending',
  completed_at timestamptz,
  completed_by text,
  skip_reason text,
  notes text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint scheduled_care_tasks_status_check
    check (status in ('pending', 'in_progress', 'completed', 'skipped', 'missed', 'rescheduled'))
);

create table if not exists care.checklist_completions (
  id uuid primary key default gen_random_uuid(),
  scheduled_task_id uuid references care.scheduled_care_tasks(id) on delete cascade,
  checklist_template_id uuid not null references care.checklist_templates(id) on delete cascade,
  completed_by text,
  completed_at timestamptz,
  overall_status text not null default 'complete',
  notes text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint checklist_completions_status_check
    check (overall_status in ('complete', 'partial', 'skipped'))
);

create table if not exists care.checklist_item_completions (
  id uuid primary key default gen_random_uuid(),
  checklist_completion_id uuid not null references care.checklist_completions(id) on delete cascade,
  checklist_item_id uuid not null references care.checklist_items(id) on delete cascade,
  status text not null default 'done',
  notes text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint checklist_item_completions_status_check
    check (status in ('done', 'skipped', 'not_needed', 'issue'))
);

create index if not exists idx_elimination_logs_patient_id on care.elimination_logs(patient_id);
create index if not exists idx_elimination_logs_occurred_at on care.elimination_logs(occurred_at desc);
create index if not exists idx_checklist_templates_patient_id on care.checklist_templates(patient_id);
create index if not exists idx_care_schedule_templates_patient_id on care.care_schedule_templates(patient_id);
create index if not exists idx_scheduled_care_tasks_patient_id on care.scheduled_care_tasks(patient_id);
create index if not exists idx_scheduled_care_tasks_scheduled_for on care.scheduled_care_tasks(scheduled_for);

alter table care.elimination_logs enable row level security;
alter table care.checklist_templates enable row level security;
alter table care.checklist_items enable row level security;
alter table care.care_schedule_templates enable row level security;
alter table care.scheduled_care_tasks enable row level security;
alter table care.checklist_completions enable row level security;
alter table care.checklist_item_completions enable row level security;

grant select, insert, update on table care.elimination_logs to anon, authenticated;
grant select, insert, update on table care.checklist_templates to anon, authenticated;
grant select, insert, update on table care.checklist_items to anon, authenticated;
grant select, insert, update on table care.care_schedule_templates to anon, authenticated;
grant select, insert, update on table care.scheduled_care_tasks to anon, authenticated;
grant select, insert, update on table care.checklist_completions to anon, authenticated;
grant select, insert, update on table care.checklist_item_completions to anon, authenticated;

drop policy if exists desktop_admin_select_elimination_logs on care.elimination_logs;
create policy desktop_admin_select_elimination_logs
on care.elimination_logs
for select
to anon, authenticated
using (true);

drop policy if exists desktop_admin_insert_elimination_logs on care.elimination_logs;
create policy desktop_admin_insert_elimination_logs
on care.elimination_logs
for insert
to anon, authenticated
with check (true);

drop policy if exists desktop_admin_update_elimination_logs on care.elimination_logs;
create policy desktop_admin_update_elimination_logs
on care.elimination_logs
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists desktop_admin_select_checklist_templates on care.checklist_templates;
create policy desktop_admin_select_checklist_templates
on care.checklist_templates
for select
to anon, authenticated
using (true);

drop policy if exists desktop_admin_insert_checklist_templates on care.checklist_templates;
create policy desktop_admin_insert_checklist_templates
on care.checklist_templates
for insert
to anon, authenticated
with check (true);

drop policy if exists desktop_admin_update_checklist_templates on care.checklist_templates;
create policy desktop_admin_update_checklist_templates
on care.checklist_templates
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists desktop_admin_select_checklist_items on care.checklist_items;
create policy desktop_admin_select_checklist_items
on care.checklist_items
for select
to anon, authenticated
using (true);

drop policy if exists desktop_admin_insert_checklist_items on care.checklist_items;
create policy desktop_admin_insert_checklist_items
on care.checklist_items
for insert
to anon, authenticated
with check (true);

drop policy if exists desktop_admin_update_checklist_items on care.checklist_items;
create policy desktop_admin_update_checklist_items
on care.checklist_items
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists desktop_admin_select_care_schedule_templates on care.care_schedule_templates;
create policy desktop_admin_select_care_schedule_templates
on care.care_schedule_templates
for select
to anon, authenticated
using (true);

drop policy if exists desktop_admin_insert_care_schedule_templates on care.care_schedule_templates;
create policy desktop_admin_insert_care_schedule_templates
on care.care_schedule_templates
for insert
to anon, authenticated
with check (true);

drop policy if exists desktop_admin_update_care_schedule_templates on care.care_schedule_templates;
create policy desktop_admin_update_care_schedule_templates
on care.care_schedule_templates
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists desktop_admin_select_scheduled_care_tasks on care.scheduled_care_tasks;
create policy desktop_admin_select_scheduled_care_tasks
on care.scheduled_care_tasks
for select
to anon, authenticated
using (true);

drop policy if exists desktop_admin_insert_scheduled_care_tasks on care.scheduled_care_tasks;
create policy desktop_admin_insert_scheduled_care_tasks
on care.scheduled_care_tasks
for insert
to anon, authenticated
with check (true);

drop policy if exists desktop_admin_update_scheduled_care_tasks on care.scheduled_care_tasks;
create policy desktop_admin_update_scheduled_care_tasks
on care.scheduled_care_tasks
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists desktop_admin_select_checklist_completions on care.checklist_completions;
create policy desktop_admin_select_checklist_completions
on care.checklist_completions
for select
to anon, authenticated
using (true);

drop policy if exists desktop_admin_insert_checklist_completions on care.checklist_completions;
create policy desktop_admin_insert_checklist_completions
on care.checklist_completions
for insert
to anon, authenticated
with check (true);

drop policy if exists desktop_admin_update_checklist_completions on care.checklist_completions;
create policy desktop_admin_update_checklist_completions
on care.checklist_completions
for update
to anon, authenticated
using (true)
with check (true);

drop policy if exists desktop_admin_select_checklist_item_completions on care.checklist_item_completions;
create policy desktop_admin_select_checklist_item_completions
on care.checklist_item_completions
for select
to anon, authenticated
using (true);

drop policy if exists desktop_admin_insert_checklist_item_completions on care.checklist_item_completions;
create policy desktop_admin_insert_checklist_item_completions
on care.checklist_item_completions
for insert
to anon, authenticated
with check (true);

drop policy if exists desktop_admin_update_checklist_item_completions on care.checklist_item_completions;
create policy desktop_admin_update_checklist_item_completions
on care.checklist_item_completions
for update
to anon, authenticated
using (true)
with check (true);

drop trigger if exists update_updated_at on care.elimination_logs;
create trigger update_updated_at
before update on care.elimination_logs
for each row execute function care.update_updated_at_column();

drop trigger if exists update_updated_at on care.checklist_templates;
create trigger update_updated_at
before update on care.checklist_templates
for each row execute function care.update_updated_at_column();

drop trigger if exists update_updated_at on care.checklist_items;
create trigger update_updated_at
before update on care.checklist_items
for each row execute function care.update_updated_at_column();

drop trigger if exists update_updated_at on care.care_schedule_templates;
create trigger update_updated_at
before update on care.care_schedule_templates
for each row execute function care.update_updated_at_column();

drop trigger if exists update_updated_at on care.scheduled_care_tasks;
create trigger update_updated_at
before update on care.scheduled_care_tasks
for each row execute function care.update_updated_at_column();
