-- Add rating column to qitarot_readings
alter table public.qitarot_readings 
  add column if not exists rating integer check (rating >= 1 and rating <= 5);
