-- 0012_seed_demo_user.sql
-- Seeds a known-credential user so a fresh clone can sign in without
-- touching the dashboard. Idempotent: skipped when admin@demo.local
-- already exists (e.g. you created it via the dashboard or via the
-- SIGN UP button on the login screen).
--
-- ⚠ DEV / SOLO CONVENIENCE ONLY
--   This puts a user with password 'admin' into auth.users on every
--   project that runs this migration. Delete or guard this file before
--   pointing the GitHub→Supabase integration at any project you don't
--   want a public-known-credential user in.

-- pgcrypto provides crypt() + gen_salt() — Supabase enables it by
-- default but the create-if-not-exists is cheap insurance.
create extension if not exists pgcrypto;

do $$
declare
  v_user_id    uuid;
  v_email      text := 'admin@demo.local';
  v_password   text := 'admin';
begin
  if exists (select 1 from auth.users where email = v_email) then
    raise notice 'demo user % already exists — skipping', v_email;
    return;
  end if;

  v_user_id := gen_random_uuid();

  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    is_sso_user
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    crypt(v_password, gen_salt('bf')),
    now(),
    now(),
    now(),
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email')
    ),
    '{}'::jsonb,
    false,
    false
  );

  -- auth.identities holds the provider-specific identity rows; without
  -- this, sign-in returns "Database error querying schema" on modern
  -- Supabase Auth versions.
  insert into auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  ) values (
    gen_random_uuid(),
    v_user_id,
    v_user_id::text,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email),
    'email',
    now(),
    now(),
    now()
  );

  raise notice 'seeded demo user % (id %)', v_email, v_user_id;
end $$;
