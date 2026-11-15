-- Transactional tests for the trusted first-admin bootstrap.
-- Synthetic auth users and allowlist rows are rolled back; no live data is touched.
BEGIN;

DO $$
DECLARE
  v_first_user UUID := gen_random_uuid();
  v_second_user UUID := gen_random_uuid();
  v_result JSONB;
  v_admin_count INTEGER;
  v_blocked BOOLEAN := false;
BEGIN
  IF has_function_privilege('anon', 'public.bootstrap_first_admin(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute bootstrap_first_admin';
  END IF;
  IF has_function_privilege('authenticated', 'public.bootstrap_first_admin(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated must not execute bootstrap_first_admin';
  END IF;
  IF NOT has_function_privilege('service_role', 'public.bootstrap_first_admin(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'service_role must execute bootstrap_first_admin';
  END IF;

  INSERT INTO auth.users (id, email, email_confirmed_at)
  VALUES
    (v_first_user, 'sarvex-bootstrap-test@example.invalid', now()),
    (v_second_user, 'sarvex-bootstrap-second@example.invalid', now());

  -- No auth.uid() is set: the privileged SQL-editor bootstrap must still work
  -- when given the explicit target user UUID.
  PERFORM set_config('request.jwt.claim.sub', '', true);
  v_result := public.bootstrap_first_admin(v_first_user);

  IF COALESCE((v_result ->> 'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'First-admin bootstrap did not succeed: %', v_result;
  END IF;

  SELECT count(*) INTO v_admin_count
  FROM public.sarvex_admin_allowlist
  WHERE user_id = v_first_user
    AND lower(trim(email)) = 'sarvex-bootstrap-test@example.invalid';

  IF v_admin_count <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one bound first-admin seat, found %', v_admin_count;
  END IF;

  BEGIN
    PERFORM public.bootstrap_first_admin(v_second_user);
  EXCEPTION WHEN insufficient_privilege THEN
    v_blocked := true;
  END;

  IF NOT v_blocked THEN
    RAISE EXCEPTION 'A second first-admin bootstrap unexpectedly succeeded';
  END IF;
END
$$;

ROLLBACK;
