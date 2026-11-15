# First SARVEX administrator setup

This is a one-time, privileged setup step for a **new SARVEX database**. It is not performed by the public app.

## Before you start

1. Apply `supabase-production-migration.sql` to the intended Supabase project.
2. Create the intended administrator account in **Supabase Dashboard → Authentication → Users**.
3. Confirm that user's email address. Do not use an unverified account.
4. Open **Supabase Dashboard → SQL Editor** for the same project. The SQL Editor runs with database administrator privileges.

## Find the verified user's UUID

Run this read-only query, replacing the email with the exact account email:

```sql
SELECT id, email, email_confirmed_at
FROM auth.users
WHERE lower(email) = lower('admin@example.com');
```

Confirm the returned email is correct and `email_confirmed_at` is not NULL. Copy the UUID from the `id` column.

## Claim the first administrator seat

Run this once, replacing the UUID with the exact value returned above:

```sql
SELECT public.bootstrap_first_admin('00000000-0000-0000-0000-000000000000'::uuid);
```

A successful result contains `"success": true`. The function reads the email from `auth.users`; it does not trust an email supplied by the caller. It locks the allowlist before checking it, creates exactly one initial seat, and synchronizes the user's profile role when a profile row exists.

## Security notes

- The function is executable only by `service_role` or a database administrator; `anon` and `authenticated` cannot call it.
- Never put a Supabase `service_role` key in the Android app, browser, repository, or chat.
- The initial bootstrap closes permanently as soon as any row exists in `sarvex_admin_allowlist`. Subsequent administrators must be added through the trusted admin-management process, not by rerunning this first-admin step.
- Do not delete or edit the allowlist manually to retry bootstrap. Review the database state first.
- CI tests exercise the successful first claim, rejection of a second claim, role grants, PostgreSQL 15/16 compatibility, and transaction rollback using synthetic test users. Those tests do not modify a live Supabase project.
