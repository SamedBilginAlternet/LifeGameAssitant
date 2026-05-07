-- 0003_cron_daily_summary.sql
-- Schedules the daily-summary Edge Function to run every hour at :50.
--
-- Why hourly and not just 23:50 UTC?
--   The function does per-user timezone math itself — it summarizes
--   only those users whose local summary_time has just crossed. Running
--   hourly means a user in Asia/Tokyo gets summarized at their 23:50
--   local, and a user in America/Los_Angeles gets summarized at theirs,
--   without us having to schedule 24 separate crons.
--
-- Required extensions (enable in the Supabase dashboard before running):
--   - pg_cron
--   - pg_net  (for net.http_post)
--
-- Required custom GUCs (set via dashboard → Database → Custom Postgres
-- Config, OR psql `alter database postgres set ...`):
--   - app.functions_url     e.g. 'https://<project>.functions.supabase.co'
--   - app.cron_secret       a long random string also stored in the
--                            Edge Function's CRON_SECRET env var; the
--                            function rejects calls without it.
--
-- Idempotent — re-running unschedules and reschedules.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Unschedule any previous version before re-creating, so re-running
-- this migration during dev doesn't accumulate duplicate jobs.
do $$
declare
  jobid int;
begin
  select cron.unschedule('daily-summary') into jobid where exists (
    select 1 from cron.job where jobname = 'daily-summary'
  );
end;
$$;

select cron.schedule(
  'daily-summary',
  '50 * * * *',
  $$
    select net.http_post(
      url := current_setting('app.functions_url') || '/daily-summary',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.cron_secret')
      ),
      body := jsonb_build_object('mode', 'cron')
    );
  $$
);
