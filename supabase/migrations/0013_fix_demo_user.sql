-- 0013_fix_demo_user.sql
-- Migration 0012 missed the is_anonymous column added in mid-2024
-- Supabase Auth. Without it, GoTrue's select-user query treats the
-- seeded row as malformed and sign-in returns:
--   "Database error querying schema"
--
-- This migration removes the broken row + its identity and re-inserts
-- with every column current GoTrue inspects. Idempotent: re-running
-- just refreshes the demo user.

create extension if not exists pgcrypto;

-- Clean up the partial row from 0012 (and any identity row that came
-- with it). auth.identities has no cascade FK to auth.users on Supabase
-- managed projects, so we delete it explicitly.
delete from auth.identities
  where user_id in (
    select id from auth.users where email = 'admin@demo.local'
  );
delete from auth.users where email = 'admin@demo.local';

do $$
declare
  v_user_id  uuid := gen_random_uuid();
  v_email    text := 'admin@demo.local';
  v_password text := 'admin';
begin
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    is_super_admin,
    is_sso_user,
    is_anonymous
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    crypt(v_password, gen_salt('bf')),
    now(),
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email')
    ),
    '{}'::jsonb,
    now(),
    now(),
    false,
    false,
    false
  );

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

  raise notice 're-seeded demo user % (id %)', v_email, v_user_id;
end $$;
