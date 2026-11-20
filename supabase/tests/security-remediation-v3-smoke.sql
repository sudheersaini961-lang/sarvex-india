-- Read-only assertions for SARVEX security remediation draft v3.
-- Runs only in the disposable PostgreSQL CI service, never on live Supabase.
DO $smoke$
DECLARE
  v_options text[];
  v_viewdef text;
  v_sig regprocedure;
  v_name text;
  v_expected text[] := ARRAY[
    'is_sarvex_admin()',
    'is_seller_shop_owner(uuid)',
    'is_approved_seller_shop(uuid)',
    'claim_sarvex_admin_seat()',
    'has_verified_purchase(uuid,uuid)',
    'order_has_seller_item(uuid)',
    'is_order_customer(uuid)',
    'place_sarvex_order(text,text,text,text,text,text,text,jsonb)',
    'place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)',
    'vote_review_helpful(uuid)',
    'handle_new_sarvex_user()',
    'protect_customer_account_role()',
    'protect_seller_shop_status()',
    'protect_product_fields()',
    'protect_order_item_fields()',
    'protect_and_verify_review()',
    'sync_parent_order_status()',
    'sync_product_review_stats()',
    'sync_review_helpful_count()',
    'bootstrap_first_admin()'
  ];
BEGIN
  SELECT reloptions INTO v_options
  FROM pg_class WHERE oid='public.sellers'::regclass;
  IF NOT (COALESCE(v_options, ARRAY[]::text[]) @> ARRAY['security_barrier=true'])
     OR NOT (COALESCE(v_options, ARRAY[]::text[]) @> ARRAY['security_invoker=false']) THEN
    RAISE EXCEPTION 'FAIL: public.sellers must remain a security-barrier, limited definer view';
  END IF;

  SELECT reloptions INTO v_options
  FROM pg_class WHERE oid='public.seller_order_items_view'::regclass;
  IF NOT (COALESCE(v_options, ARRAY[]::text[]) @> ARRAY['security_barrier=true'])
     OR NOT (COALESCE(v_options, ARRAY[]::text[]) @> ARRAY['security_invoker=false']) THEN
    RAISE EXCEPTION 'FAIL: seller_order_items_view must remain a security-barrier, limited definer view';
  END IF;

  SELECT lower(pg_get_viewdef('public.sellers'::regclass, true)) INTO v_viewdef;
  IF position('approval_status' IN v_viewdef)=0
     OR position('approved' IN v_viewdef)=0
     OR position('bank_account' IN v_viewdef)>0
     OR position('ifsc_code' IN v_viewdef)>0
     OR position('upi_id' IN v_viewdef)>0 THEN
    RAISE EXCEPTION 'FAIL: public seller directory view is not the expected limited projection';
  END IF;

  SELECT lower(pg_get_viewdef('public.seller_order_items_view'::regclass, true)) INTO v_viewdef;
  IF position('s.owner_id = auth.uid()' IN v_viewdef)=0
     OR position('s.approval_status' IN v_viewdef)=0
     OR position('is_sarvex_admin()' IN v_viewdef)=0 THEN
    RAISE EXCEPTION 'FAIL: seller order view does not retain seller-owner/admin row filter';
  END IF;

  IF NOT has_table_privilege('anon','public.sellers','SELECT')
     OR has_table_privilege('anon','public.seller_shops','SELECT')
     OR has_table_privilege('anon','public.seller_order_items_view','SELECT')
     OR NOT has_table_privilege('authenticated','public.seller_order_items_view','SELECT') THEN
    RAISE EXCEPTION 'FAIL: public/authenticated view access grants are incorrect';
  END IF;

  IF has_column_privilege('anon','public.seller_shops','bank_account','SELECT')
     OR has_column_privilege('anon','public.seller_shops','ifsc_code','SELECT')
     OR has_column_privilege('anon','public.seller_shops','upi_id','SELECT')
     OR has_column_privilege('anon','public.seller_shops','phone','SELECT')
     OR has_column_privilege('anon','public.seller_shops','email','SELECT')
     OR has_column_privilege('anon','public.seller_shops','pickup_address','SELECT')
     OR has_column_privilege('anon','public.seller_shops','shop_name','SELECT') THEN
    RAISE EXCEPTION 'FAIL: anon retains direct seller_shops column access';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='seller_shops'
      AND policyname='Public can view approved seller shops'
  ) THEN
    RAISE EXCEPTION 'FAIL: legacy public seller_shops policy still exists';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='orders'
      AND policyname='Sellers can view orders containing their items'
  ) THEN
    RAISE EXCEPTION 'FAIL: broad seller SELECT policy on orders must not be added';
  END IF;

  FOREACH v_name IN ARRAY v_expected LOOP
    v_sig := to_regprocedure('public.' || v_name);
    IF v_sig IS NULL THEN
      RAISE EXCEPTION 'FAIL: expected function signature missing: %', v_name;
    END IF;
  END LOOP;

  IF has_function_privilege('anon','public.bootstrap_first_admin()','EXECUTE')
     OR has_function_privilege('authenticated','public.bootstrap_first_admin()','EXECUTE')
     OR NOT has_function_privilege('service_role','public.bootstrap_first_admin()','EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: first-admin bootstrap grants are incorrect';
  END IF;

  IF has_function_privilege('anon','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)','EXECUTE')
     OR has_function_privilege('anon','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)','EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: checkout RPC grants are incorrect';
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
    v_sig := to_regprocedure('public.' || v_name);
    IF has_function_privilege('anon',v_sig,'EXECUTE')
       OR has_function_privilege('authenticated',v_sig,'EXECUTE') THEN
      RAISE EXCEPTION 'FAIL: trigger-only function exposed to browser role: %', v_name;
    END IF;
  END LOOP;
END
$smoke$;

SELECT 'SARVEX security remediation draft v3: PASS' AS result;
