-- 0011_cron_weekly_summary.sql
-- Schedules weekly-summary to run every hour on Sundays. Same per-user
-- timezone math the daily cron uses (see 0003), so a single schedule
-- handles every user wherever they are.
--
-- Fires at :30 of each hour on Sundays — that's 20 minutes before the
-- daily 23:50 cron lands, leaving a comfortable gap if a user's
-- synthesis runs long.

create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$
declare
  jobid int;
begin
  select cron.unschedule('weekly-summary') into jobid where exists (
    select 1 from cron.job where jobname = 'weekly-summary'
  );
end;
$$;

select cron.schedule(
  'weekly-summary',
  '30 * * * 0',
  $$
    select net.http_post(
      url := current_setting('app.functions_url') || '/weekly-summary',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.cron_secret')
      ),
      body := jsonb_build_object('mode', 'cron')
    );
  $$
);
