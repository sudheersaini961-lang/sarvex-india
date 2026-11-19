#!/usr/bin/env bash
set -euo pipefail

expect_policy_rejection() {
  local label="$1"
  shift
  local log_file
  log_file="$(mktemp)"

  if "$@" >"$log_file" 2>&1; then
    cat "$log_file"
    rm -f "$log_file"
    echo "FAIL: migration accepted the ${label} probe"
    exit 1
  fi

  if ! grep -Fq "SARVEX SECURITY VIOLATION: Unrecognized or mismatched PERMISSIVE policy" "$log_file"; then
    cat "$log_file"
    rm -f "$log_file"
    echo "FAIL: migration failed for an unexpected reason during ${label} probe"
    exit 1
  fi

  rm -f "$log_file"
  echo "PASS: migration rejected ${label} probe"
}

# An unrecognized permissive policy must fail closed rather than be silently retained.
psql -v ON_ERROR_STOP=1 <<'SQL'
CREATE POLICY "sarvex_ci_unrecognized_permissive_probe"
  ON public.products FOR SELECT TO anon
  USING (true);
SQL

expect_policy_rejection "unknown permissive RLS policy" \
  psql -v ON_ERROR_STOP=1 -f supabase-production-migration.sql

psql -v ON_ERROR_STOP=1 -c 'DROP POLICY "sarvex_ci_unrecognized_permissive_probe" ON public.products;'

# The named KYC UPDATE policy must retain the approved-seller exclusion in BOTH
# USING and WITH CHECK. A weakened definition must be rejected.
psql -v ON_ERROR_STOP=1 <<'SQL'
DROP POLICY "Sellers update own KYC documents" ON storage.objects;
CREATE POLICY "Sellers update own KYC documents"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'seller-kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'seller-kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
SQL

expect_policy_rejection "weakened seller KYC UPDATE policy" \
  psql -v ON_ERROR_STOP=1 -f supabase-production-migration.sql

# Remove the deliberately weakened test policy. Reapplying the migration must
# recreate the approved KYC policy and leave the database passing baseline checks.
psql -v ON_ERROR_STOP=1 -c 'DROP POLICY "Sellers update own KYC documents" ON storage.objects;'
psql -v ON_ERROR_STOP=1 -f supabase-production-migration.sql
psql -v ON_ERROR_STOP=1 -f supabase/tests/baseline-security-smoke.sql
