-- Wish and notification lifecycle helpers.
-- Run this in the Supabase SQL Editor.
--
-- What this script does:
-- 1. Adds lifecycle fields to wished_property.
-- 2. Keeps new wishes active by default.
-- 3. Auto-archives matched wishes after 14 days.
-- 4. Auto-deletes read notifications after 14 days.

create extension if not exists pg_cron;

alter table if exists public.wished_property
add column if not exists is_active boolean not null default true;

alter table if exists public.wished_property
add column if not exists matched_at timestamptz;

create or replace function public.archive_old_matched_wishes()
returns integer
language plpgsql
as $$
declare
  archived_count integer := 0;
begin
  update public.wished_property
  set is_active = false
  where is_active = true
    and matched_at is not null
    and matched_at < timezone('utc', now()) - interval '14 days';

  get diagnostics archived_count = row_count;
  return archived_count;
end;
$$;

create or replace function public.delete_old_read_notifications()
returns integer
language plpgsql
as $$
declare
  deleted_count integer := 0;
begin
  delete from public.notifications
  where read_at is not null
    and read_at < timezone('utc', now()) - interval '14 days';

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

select cron.unschedule(jobid)
from cron.job
where jobname in (
  'archive-old-matched-wishes',
  'delete-old-read-notifications'
);

select cron.schedule(
  'archive-old-matched-wishes',
  '25 3 * * *',
  $$ select public.archive_old_matched_wishes(); $$
);

select cron.schedule(
  'delete-old-read-notifications',
  '35 3 * * *',
  $$ select public.delete_old_read_notifications(); $$
);

-- Optional manual runs:
-- select public.archive_old_matched_wishes();
-- select public.delete_old_read_notifications();
