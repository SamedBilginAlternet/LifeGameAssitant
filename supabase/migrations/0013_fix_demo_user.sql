-- 0013_fix_demo_user.sql — DEPRECATED, no-op.
--
-- Originally tried to fix 0012's broken seeded user by deleting and
-- re-inserting with explicit `is_anonymous`, `is_sso_user`, etc.
-- Didn't resolve the "Database error querying schema" failure either.
--
-- See 0012's note for the full story. Both 0012 and 0013 are now
-- no-ops to keep applied-migration tracking stable; the dashboard
-- "Add user" flow is the recommended path for seeding demo users.

select 1 where false;
