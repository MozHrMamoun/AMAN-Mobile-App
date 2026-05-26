-- Chat auto-delete after 14 days from the last message.
-- Run this in the Supabase SQL Editor.
--
-- What this script does:
-- 1. Ensures chats.created_at / chats.last_message_at are initialized.
-- 2. Keeps chats.last_message_at and chats.last_message_text in sync on new messages.
-- 3. Deletes chats whose latest activity is older than 14 days.
-- 4. Schedules the cleanup to run every day.

create extension if not exists pg_cron;

alter table if exists public.chats
  alter column created_at set default timezone('utc', now());

update public.chats
set created_at = coalesce(created_at, timezone('utc', now()))
where created_at is null;

with latest_message as (
  select distinct on (m.chat_id)
    m.chat_id,
    m.message_text,
    m.created_at
  from public.chat_messages m
  order by m.chat_id, m.created_at desc, m.message_id desc
)
update public.chats c
set
  last_message_text = lm.message_text,
  last_message_at = lm.created_at
from latest_message lm
where c.chat_id = lm.chat_id
  and (
    c.last_message_at is null
    or c.last_message_at <> lm.created_at
    or coalesce(c.last_message_text, '') <> coalesce(lm.message_text, '')
  );

create or replace function public.sync_chat_after_message_insert()
returns trigger
language plpgsql
as $$
begin
  update public.chats
  set
    last_message_text = new.message_text,
    last_message_at = coalesce(new.created_at, timezone('utc', now()))
  where chat_id = new.chat_id;

  return new;
end;
$$;

drop trigger if exists trg_sync_chat_after_message_insert on public.chat_messages;

create trigger trg_sync_chat_after_message_insert
after insert on public.chat_messages
for each row
execute function public.sync_chat_after_message_insert();

create or replace function public.delete_expired_chats()
returns integer
language plpgsql
as $$
declare
  deleted_count integer := 0;
begin
  delete from public.chat_messages
  where chat_id in (
    select c.chat_id
    from public.chats c
    where coalesce(c.last_message_at, c.created_at) < timezone('utc', now()) - interval '14 days'
  );

  delete from public.chats c
  where coalesce(c.last_message_at, c.created_at) < timezone('utc', now()) - interval '14 days';

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

select cron.unschedule(jobid)
from cron.job
where jobname = 'delete-expired-chats-14-days';

select cron.schedule(
  'delete-expired-chats-14-days',
  '15 3 * * *',
  $$ select public.delete_expired_chats(); $$
);

-- Optional: run once immediately after installing the cleanup.
-- select public.delete_expired_chats();
