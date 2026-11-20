-- One-time, server-only first administrator bootstrap.
-- The Edge Function verifies the caller JWT and configured allowlisted email.
-- This RPC accepts only service_role and independently verifies auth.users.
BEGIN;

DO $preflight$
BEGIN
  IF to_regclass('public.sarvex_admin_allowlist') IS NULL
     OR to_regclass('public.customer_profiles') IS NULL
     OR to_regclass('auth.users') IS NULL THEN
    RAISE EXCEPTION 'First-admin bootstrap preflight failed: required table missing';
  END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION public.bootstrap_first_admin_for_user(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_email text;
  v_confirmed_at timestamptz;
  v_admin_count integer;
  v_existing_user uuid;
BEGIN
  IF current_setting('request.jwt.claim.role', true) IS DISTINCT FROM 'service_role'
     AND session_user NOT IN ('postgres', 'supabase_admin') THEN
    RAISE EXCEPTION 'Forbidden: service_role is required'
      USING ERRCODE = '42501';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'A verified user id is required'
      USING ERRCODE = '22023';
  END IF;

  SELECT lower(trim(email)), email_confirmed_at
    INTO v_email, v_confirmed_at
  FROM auth.users
  WHERE id = p_user_id;

  IF v_email IS NULL OR v_confirmed_at IS NULL THEN
    RAISE EXCEPTION 'The selected account must have a verified email'
      USING ERRCODE = '42501';
  END IF;

  LOCK TABLE public.sarvex_admin_allowlist IN EXCLUSIVE MODE;

  SELECT user_id INTO v_existing_user
  FROM public.sarvex_admin_allowlist
  WHERE user_id = p_user_id
    AND lower(trim(email)) = v_email
  LIMIT 1;

  IF v_existing_user IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_admin', true,
      'message', 'This account already holds the initial administrator seat.'
    );
  END IF;

  SELECT count(*) INTO v_admin_count
  FROM public.sarvex_admin_allowlist;

  IF v_admin_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'already_admin', false,
      'error', 'First administrator setup is permanently closed because an administrator seat already exists.'
    );
  END IF;

  INSERT INTO public.sarvex_admin_allowlist (id, user_id, email, created_at)
  VALUES (gen_random_uuid(), p_user_id, v_email, now());

  UPDATE public.customer_profiles
  SET account_role = 'admin'
  WHERE owner_id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'already_admin', false,
    'message', 'The first SARVEX administrator seat was assigned.'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.bootstrap_first_admin_for_user(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin_for_user(uuid)
  TO service_role;

COMMIT;
