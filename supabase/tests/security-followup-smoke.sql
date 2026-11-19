-- Verifies the additive live-security follow-up without changing user data.
DO $$
DECLARE
  v_name text;
  v_oid regprocedure;
  v_view_options text[];
BEGIN
  SELECT reloptions INTO v_view_options
  FROM pg_class WHERE oid = 'public.sellers'::regclass;
  IF NOT ('security_invoker=true' = ANY(COALESCE(v_view_options, ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'FAIL: public.sellers is not security_invoker';
  END IF;

  SELECT reloptions INTO v_view_options
  FROM pg_class WHERE oid = 'public.seller_order_items_view'::regclass;
  IF NOT ('security_invoker=true' = ANY(COALESCE(v_view_options, ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'FAIL: public.seller_order_items_view is not security_invoker';
  END IF;

  IF has_column_privilege('anon','public.seller_shops','shop_name','SELECT') IS NOT TRUE
     OR has_column_privilege('anon','public.seller_shops','bank_account','SELECT') IS TRUE
     OR has_column_privilege('anon','public.seller_shops','ifsc_code','SELECT') IS TRUE THEN
    RAISE EXCEPTION 'FAIL: anonymous seller column privileges are not least-privilege';
  END IF;

  IF has_function_privilege('anon','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)','EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: anon can execute COD checkout';
  END IF;
  IF NOT has_function_privilege('authenticated','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)','EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: authenticated cannot execute COD checkout';
  END IF;

  FOREACH v_name IN ARRAY ARRAY[
    'handle_new_sarvex_user()',
    'protect_customer_account_role()',
    'protect_seller_shop_status()',
    'protect_product_fields()',
    'protect_order_item_fields()',
    'protect_and_verify_review()',
    'sync_parent_order_status()',
    'sync_product_review_stats()',
    'sync_review_helpful_count()'
  ] LOOP
    v_oid := to_regprocedure('public.' || v_name);
    IF v_oid IS NULL THEN
      RAISE EXCEPTION 'FAIL: expected trigger function missing: %', v_name;
    END IF;
    IF has_function_privilege('anon',v_oid,'EXECUTE')
       OR has_function_privilege('authenticated',v_oid,'EXECUTE') THEN
      RAISE EXCEPTION 'FAIL: browser role can execute trigger-only function %', v_name;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='seller_shops'
      AND policyname='Public can view approved seller shops' AND roles @> ARRAY['public']::name[]
  ) THEN
    RAISE EXCEPTION 'FAIL: public approved-seller RLS policy missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='orders'
      AND policyname='Sellers can view orders for their own items'
  ) THEN
    RAISE EXCEPTION 'FAIL: seller order RLS policy missing';
  END IF;
END
$$;

SELECT 'SARVEX additive security follow-up: PASS' AS result;
