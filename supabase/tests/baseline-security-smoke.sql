-- Security/runtime assertions for the current main-branch baseline migration.
-- Runs only against the disposable PostgreSQL service container.

DO $smoke$
DECLARE
  v_table text;
  v_test_user_id uuid := gen_random_uuid();
  v_profile_role text;
  v_profile_name text;
  v_required_tables text[] := ARRAY[
    'customer_profiles',
    'seller_shops',
    'products',
    'cart_items',
    'orders',
    'order_idempotency_keys',
    'order_items',
    'reviews',
    'review_helpful_votes',
    'wishlist_items',
    'categories',
    'sarvex_admin_allowlist'
  ];
BEGIN
  FOREACH v_table IN ARRAY v_required_tables LOOP
    IF to_regclass(format('public.%I', v_table)) IS NULL THEN
      RAISE EXCEPTION 'Missing required SARVEX table: public.%', v_table;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = v_table
        AND c.relkind IN ('r', 'p')
        AND c.relrowsecurity
    ) THEN
      RAISE EXCEPTION 'RLS is not enabled on public.%', v_table;
    END IF;

    IF has_table_privilege('anon', format('public.%I', v_table), 'INSERT')
       OR has_table_privilege('anon', format('public.%I', v_table), 'UPDATE')
       OR has_table_privilege('anon', format('public.%I', v_table), 'DELETE')
       OR has_table_privilege('anon', format('public.%I', v_table), 'TRUNCATE')
       OR has_table_privilege('anon', format('public.%I', v_table), 'REFERENCES')
       OR has_table_privilege('anon', format('public.%I', v_table), 'TRIGGER') THEN
      RAISE EXCEPTION 'anon has unsafe direct privileges on public.%', v_table;
    END IF;

    IF has_table_privilege('authenticated', format('public.%I', v_table), 'TRUNCATE')
       OR has_table_privilege('authenticated', format('public.%I', v_table), 'REFERENCES')
       OR has_table_privilege('authenticated', format('public.%I', v_table), 'TRIGGER') THEN
      RAISE EXCEPTION 'authenticated has unsafe structural privileges on public.%', v_table;
    END IF;
  END LOOP;

  IF to_regprocedure('auth.uid()') IS NULL THEN
    RAISE EXCEPTION 'auth.uid() compatibility function is missing';
  END IF;

  IF to_regprocedure('public.bootstrap_first_admin()') IS NULL THEN
    RAISE EXCEPTION 'Trusted first-admin bootstrap function is missing';
  END IF;

  IF has_function_privilege('anon', 'public.bootstrap_first_admin()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.bootstrap_first_admin()', 'EXECUTE') THEN
    RAISE EXCEPTION 'Browser roles must not execute first-admin bootstrap';
  END IF;

  IF NOT has_function_privilege('service_role', 'public.bootstrap_first_admin()', 'EXECUTE') THEN
    RAISE EXCEPTION 'service_role must retain the intended first-admin bootstrap grant';
  END IF;

  IF to_regprocedure('public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)') IS NULL
     OR to_regprocedure('public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)') IS NULL THEN
    RAISE EXCEPTION 'Expected checkout RPC signatures are missing';
  END IF;

  IF has_function_privilege('anon', 'public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute checkout RPCs';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('customer_profiles', 'seller_shops', 'products', 'cart_items')
      AND policyname IN (
        'customer_profiles_create_policy', 'customer_profiles_read_policy',
        'customer_profiles_update_policy', 'customer_profiles_delete_policy',
        'seller_shops_create_policy', 'seller_shops_read_policy',
        'seller_shops_update_policy', 'seller_shops_delete_policy',
        'products_create_policy', 'products_read_policy',
        'products_update_policy', 'products_delete_policy',
        'cart_items_create_policy', 'cart_items_read_policy',
        'cart_items_update_policy', 'cart_items_delete_policy'
      )
  ) THEN
    RAISE EXCEPTION 'Known legacy permissive policies remain on core marketplace tables';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'product-images' AND public = true) THEN
    RAISE EXCEPTION 'Expected public product-images bucket is missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'seller-kyc-documents' AND public = false) THEN
    RAISE EXCEPTION 'Expected private seller-kyc-documents bucket is missing or public';
  END IF;

  IF to_regprocedure('public.handle_new_sarvex_user()') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM pg_trigger
       WHERE tgrelid = 'auth.users'::regclass
         AND tgname = 'on_auth_user_created_sarvex'
         AND NOT tgisinternal
         AND tgenabled <> 'D'
     ) THEN
    RAISE EXCEPTION 'Secure Auth signup profile-provisioning trigger is missing or disabled';
  END IF;

  -- Verify real Auth INSERT provisioning and reject privilege escalation from user metadata.
  INSERT INTO auth.users (id, email, email_confirmed_at, raw_user_meta_data)
  VALUES (
    v_test_user_id,
    'sarvex-signup-smoke-' || v_test_user_id::text || '@example.invalid',
    now(),
    jsonb_build_object('full_name', 'SARVEX Signup Smoke', 'account_role', 'admin', 'phone', '9999999999')
  );

  SELECT account_role, display_name
  INTO v_profile_role, v_profile_name
  FROM public.customer_profiles
  WHERE owner_id = v_test_user_id;

  IF v_profile_role IS DISTINCT FROM 'customer'
     OR v_profile_name IS DISTINCT FROM 'SARVEX Signup Smoke' THEN
    RAISE EXCEPTION 'Auth signup provisioning failed or accepted untrusted role metadata (role: %, name: %)',
      v_profile_role, v_profile_name;
  END IF;

  DELETE FROM public.customer_profiles WHERE owner_id = v_test_user_id;
  DELETE FROM auth.users WHERE id = v_test_user_id;
END
$smoke$;

SELECT 'SARVEX baseline security smoke checks passed' AS result;
