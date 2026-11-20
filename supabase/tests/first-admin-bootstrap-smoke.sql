-- Isolated PostgreSQL tests for one-time first-admin bootstrap.
DO $test$
DECLARE
  v_first uuid := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  v_second uuid := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  v_result jsonb;
BEGIN
  INSERT INTO auth.users (id, email, email_confirmed_at)
  VALUES
    (v_first, 'owner@example.invalid', now()),
    (v_second, 'other@example.invalid', now())
  ON CONFLICT (id) DO NOTHING;

  SET LOCAL request.jwt.claim.role = 'service_role';
  SET LOCAL request.jwt.claims = '{"role":"service_role"}';

  v_result := public.bootstrap_first_admin_for_user(v_first);
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE
     OR COALESCE((v_result->>'already_admin')::boolean, true) IS NOT FALSE THEN
    RAISE EXCEPTION 'FAIL: first verified account did not receive the initial admin seat: %', v_result;
  END IF;

  v_result := public.bootstrap_first_admin_for_user(v_first);
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE
     OR COALESCE((v_result->>'already_admin')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'FAIL: repeated bootstrap for the same account was not idempotent: %', v_result;
  END IF;

  v_result := public.bootstrap_first_admin_for_user(v_second);
  IF COALESCE((v_result->>'success')::boolean, true) IS NOT FALSE THEN
    RAISE EXCEPTION 'FAIL: a second account was able to claim another initial admin seat: %', v_result;
  END IF;

  IF (SELECT count(*) FROM public.sarvex_admin_allowlist) <> 1
     OR NOT EXISTS (
       SELECT 1 FROM public.sarvex_admin_allowlist
       WHERE user_id = v_first AND lower(email) = 'owner@example.invalid'
     ) THEN
    RAISE EXCEPTION 'FAIL: first-admin allowlist invariant is incorrect';
  END IF;
END
$test$;

DO $acl$
BEGIN
  IF has_function_privilege('anon','public.bootstrap_first_admin_for_user(uuid)','EXECUTE')
     OR has_function_privilege('authenticated','public.bootstrap_first_admin_for_user(uuid)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.bootstrap_first_admin_for_user(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: first-admin RPC must be service_role-only';
  END IF;
END
$acl$;

SELECT 'SARVEX first-admin bootstrap tests: PASS' AS result;
