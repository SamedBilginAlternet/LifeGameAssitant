-- 0005_cron_github_poll.sql
-- Schedules the github-poll Edge Function to run every 30 minutes.
-- Same custom GUC pattern as 0003: app.functions_url + app.cron_secret.

do $$
declare
  jobid int;
begin
  select cron.unschedule('github-poll') into jobid where exists (
    select 1 from cron.job where jobname = 'github-poll'
  );
end;
$$;

select cron.schedule(
  'github-poll',
  '*/30 * * * *',
  $$
    select net.http_post(
      url := current_setting('app.functions_url') || '/github-poll',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.cron_secret')
      ),
      body := '{}'::jsonb
    );
  $$
);
