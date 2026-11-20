# SARVEX first-admin and production deployment runbook

This runbook is for the project owner/operator. It is deliberately fail-closed: do not enable marketplace writes or apply production SQL until the backup and verification gates below are satisfied.

## Current deployment state

- The repository contains the security remediation migration and one-time first-admin migration.
- The first-admin Edge Function is in `supabase/functions/bootstrap-first-admin/index.ts`.
- The signed-in profile action calls that function; it does not contain a service-role key.
- The live Supabase project has not yet recorded these two migrations, and no Edge Functions are currently deployed.
- Checkout and other marketplace writes remain disabled in the app.
- The live project has no confirmed restorable backup. Therefore production migration deployment is currently BLOCKED.

## Required order

1. **Establish a restorable backup first.** Confirm that the backup can actually be restored to a separate project or environment. A dashboard status or export file alone is not proof of a tested restore.
2. **Reconcile migration history.** The live project currently records earlier migration versions that are not represented by files in this repository's `supabase/migrations/` directory. Do not run `supabase db push` blindly. Reconcile the migration history and confirm the exact pending SQL before applying anything.
3. Apply `supabase/migrations/20261120090000_sarvex_security_remediation_v3.sql` to the intended project, then verify the smoke tests and RLS/ACL behavior.
4. Apply `supabase/migrations/20261120100000_sarvex_first_admin_bootstrap.sql` only after step 3 passes.
5. Configure the Edge Function secret `SARVEX_FIRST_ADMIN_EMAIL` to the exact, verified email address that should own the first administrator seat. Do not commit this email or any secret into the repository.
6. Deploy the `bootstrap-first-admin` Edge Function. Supabase provides the server-side `SUPABASE_SERVICE_ROLE_KEY`; never copy it into Vite variables, Android assets, app settings, screenshots, or chat.
7. Sign in to SARVEX using the allowlisted account and verify its email. Open the profile and use **Verify Initial Admin Access**. The server checks the verified JWT/email and the database enforces the one-time seat under an exclusive table lock.
8. Confirm `is_sarvex_admin()` returns true for that account, false for a different account, and that the admin dashboard can read the seller approval queue without exposing bank/KYC fields.
9. Re-run the Supabase Security and Health Advisors. Review every remaining finding; do not silence a finding without understanding the affected view/function and its callers.
10. Keep `MARKETPLACE_WRITES_ENABLED` false until checkout, seller approval, product moderation, order status, storage policies, and real Android device flows have been verified end-to-end.

## Edge Function deployment reference

Use an authenticated operator environment with the Supabase CLI and the correct project ref. Example commands:

```sh
supabase secrets set SARVEX_FIRST_ADMIN_EMAIL=owner@example.com --project-ref lgeoxxvmsssazorubsvr
supabase functions deploy bootstrap-first-admin --project-ref lgeoxxvmsssazorubsvr
```

Replace the example email with the project owner's verified email. Never place a service-role key in either command or a client-side environment variable. Supabase's Edge Function runtime must have its standard server-side service-role secret available.

## Verification and rollback

- The repository CI runs the SQL smoke test against disposable PostgreSQL 15, 16, and 17 databases. This is not a production deployment test.
- Verify the exact backup restore procedure before any production migration.
- If any migration or post-deployment check fails, stop; do not enable writes. Restore only through the previously tested recovery procedure.
- Do not delete or rewrite existing seller/product rows as part of this deployment.
- Do not create sample orders, reviews, sales, or analytics to make the dashboard look populated.

## Status vocabulary

- **PASS**: directly executed and verified in the named environment.
- **NOT VERIFIED**: code/configuration exists but has not been exercised in the target environment.
- **BLOCKED**: a prerequisite (currently a restorable production backup and migration-history reconciliation) is missing.
