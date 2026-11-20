# SARVEX Security Deployment Runbook

This runbook describes the controlled deployment of the security migrations. It is intentionally conservative: do not enable marketplace writes or checkout until every required check passes.

## Current deployment facts (verified 2026-11-20)

- Supabase project: `SARVEX` (`lgeoxxvmsssazorubsvr`), PostgreSQL 17.
- The live migration history currently contains only:
  - `20261016172410`
  - `20261119165620`
- The following repository migrations are **not yet recorded as applied** in the live project:
  - `20261120090000_sarvex_security_remediation_v3`
  - `20261120100000_sarvex_first_admin_bootstrap`
- `20261120110000_sarvex_performance_tuning_v1`
- No Supabase development branches were returned by the project API during this inspection.
- No restorable database/Auth/Storage backup has been verified.
- Marketplace writes and checkout must remain disabled.

These facts must be rechecked immediately before deployment; do not assume they remain current.

## Hard stop conditions

Do not apply either migration to production until all of the following are true:

1. A current backup exists and its restore procedure has been verified. Include database plus any required Auth and Storage recovery plan.
2. A rollback/forward-fix owner and maintenance window are identified.
3. The migration files on `main` match the versions reviewed in pull request.
4. PostgreSQL 17 isolated tests pass against the exact migration files.
5. A staging project or equivalent isolated environment has passed the application smoke tests.
6. The app remains fail-closed with marketplace writes disabled during deployment.

A successful GitHub Actions test is not a production backup and does not prove the live database is safe to migrate.

## Deployment order

Apply migrations using the Supabase migration workflow/CLI so migration history is recorded. Do not paste only part of a migration into the SQL editor.

1. Apply `20261120090000_sarvex_security_remediation_v3`.
2. Verify migration history records that exact version.
3. Run the security smoke checks and verify:
   - anon cannot read private `seller_shops` columns or rows;
   - public seller directory remains limited to approved shops and safe fields;
   - sellers can read only their own approved seller-order projection;
   - anon cannot call checkout or first-admin bootstrap;
   - trigger-only functions are not exposed as browser RPCs;
   - authenticated checkout remains available to signed-in customers only;
   - new public functions do not inherit browser-role EXECUTE grants.
4. Apply `20261120100000_sarvex_first_admin_bootstrap` only after step 3 passes.
5. Verify its migration history entry and the service-role-only ACL on `bootstrap_first_admin_for_user(uuid)`.
6. Apply `20261120110000_sarvex_performance_tuning_v1` after the security and first-admin migrations pass their checks. Verify the RLS policy rewrites, three foreign-key indexes, and removal of only the three exact duplicate indexes in the performance smoke test.
7. Deploy `supabase/functions/bootstrap-first-admin` only after setting the server-side secrets:
   - `SARVEX_FIRST_ADMIN_EMAIL` (the exact verified initial administrator email);
   - the platform-provided `SUPABASE_URL`, publishable/anon key, and `SUPABASE_SERVICE_ROLE_KEY` server secrets.
7. Never put `SUPABASE_SERVICE_ROLE_KEY` in the Android app, web bundle, repository, or client configuration.

The first-admin function is a one-time bootstrap. Verify the allowlisted email and account identity before invoking it. Do not invoke it speculatively.

## Post-migration verification

Run Supabase Security Advisor and Performance Advisor again and compare findings with the pre-deployment baseline. The performance migration specifically targets the 18 `auth_rls_initplan` warnings, three uncovered foreign-key indexes, and duplicate index pairs observed on 2026-11-20. Unused-index notices may remain or appear for newly-added indexes until real marketplace traffic exists; do not remove indexes solely because an empty/low-traffic database has not used them.

Expected residual findings may include the two intentionally limited SECURITY DEFINER views:
- `public.sellers`
- `public.seller_order_items_view`

The v3 migration intentionally retains these views to preserve the existing public seller directory and seller-only order projection. Do not change them to invoker views or broaden base-table grants without first proving the app access model still works.

Some SECURITY DEFINER helper functions are deliberately executable by browser roles because existing RLS policies call them. Their continued Advisor warnings are not automatically proof of exploitation, but each must be reviewed for safe `search_path`, caller/row authorization, and minimal returned data. Trigger-only functions and first-admin bootstrap must not be callable as browser RPCs.

Also verify:
- Health Advisor has no new findings.
- Leaked Password Protection is enabled in Supabase Auth settings.
- Public catalog returns no unapproved seller products.
- Seller KYC, bank, payout, and pickup-address fields are not exposed to public clients.
- Customer, seller, admin, order tracking, review, and COD checkout flows work in staging.
- No fake products, reviews, orders, or analytics have been inserted.

## Release gate

Only enable marketplace writes after the migration history, security checks, application smoke tests, and operational recovery plan all pass. COD checkout must remain paused if any check is failed, incomplete, or not verified.

## Evidence and status labels

Use only these labels in deployment reports:
- **PASS** — directly tested and passed.
- **FAIL** — directly tested and failed.
- **NOT VERIFIED** — evidence is unavailable.
- **BLOCKED** — cannot proceed because a prerequisite is missing.

Do not describe isolated PostgreSQL CI as a live Supabase deployment test.
