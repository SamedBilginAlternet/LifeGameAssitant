-- 0008_cron_spotify_poll.sql
-- Schedules spotify-poll every 30 minutes. Same custom GUC pattern
-- as the other crons (app.functions_url + app.cron_secret).

do $$
declare
  jobid int;
begin
  select cron.unschedule('spotify-poll') into jobid where exists (
    select 1 from cron.job where jobname = 'spotify-poll'
  );
end;
$$;

select cron.schedule(
  'spotify-poll',
  '*/30 * * * *',
  $$
    select net.http_post(
      url := current_setting('app.functions_url') || '/spotify-poll',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.cron_secret')
      ),
      body := '{}'::jsonb
    );
  $$
);
