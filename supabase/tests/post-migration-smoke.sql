-- Runtime smoke assertions for the SARVEX migration on local Supabase.
-- These checks are intentionally read-only and do not create marketplace data.

DO $$
DECLARE
  required_table text;
  required_tables text[] := ARRAY[
    'customer_profiles',
    'seller_shops',
    'products',
    'cart_items',
    'orders',
    'order_items',
    'order_idempotency_keys',
    'reviews',
    'review_helpful_votes',
    'wishlist_items',
    'categories',
    'sarvex_admin_allowlist'
  ];
BEGIN
  FOREACH required_table IN ARRAY required_tables LOOP
    IF to_regclass(format('public.%I', required_table)) IS NULL THEN
      RAISE EXCEPTION 'Missing required SARVEX table: public.%', required_table;
    END IF;
  END LOOP;

  IF to_regclass('storage.objects') IS NULL OR to_regclass('storage.buckets') IS NULL THEN
    RAISE EXCEPTION 'Supabase Storage tables are unavailable';
  END IF;

  IF to_regprocedure('auth.uid()') IS NULL THEN
    RAISE EXCEPTION 'Supabase auth.uid() is unavailable';
  END IF;

  IF to_regprocedure('public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)') IS NULL THEN
    RAISE EXCEPTION 'Expected 8-argument checkout RPC is missing';
  END IF;

  IF to_regprocedure('public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)') IS NULL THEN
    RAISE EXCEPTION 'Expected 9-argument idempotent checkout RPC is missing';
  END IF;

  FOREACH required_table IN ARRAY required_tables LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = required_table
        AND c.relkind IN ('r', 'p')
        AND c.relrowsecurity
    ) THEN
      RAISE EXCEPTION 'RLS is not enabled on public.%', required_table;
    END IF;
  END LOOP;

  IF has_function_privilege('anon',
    'public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role can execute checkout RPC';
  END IF;

  IF has_function_privilege('anon', 'public.order_has_seller_item(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role can execute seller order helper';
  END IF;

  IF has_function_privilege('anon', 'public.is_order_customer(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role can execute customer order helper';
  END IF;

  IF NOT has_function_privilege('authenticated',
    'public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated role cannot execute checkout RPC';
  END IF;


  -- No known legacy permissive policy may survive the hardened migration.
  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('customer_profiles','seller_shops','products','cart_items')
      AND policyname IN (
        'customer_profiles_create_policy','customer_profiles_read_policy','customer_profiles_update_policy','customer_profiles_delete_policy',
        'seller_shops_create_policy','seller_shops_read_policy','seller_shops_update_policy','seller_shops_delete_policy',
        'products_create_policy','products_read_policy','products_update_policy','products_delete_policy',
        'cart_items_create_policy','cart_items_read_policy','cart_items_update_policy','cart_items_delete_policy'
      )
  ) THEN
    RAISE EXCEPTION 'One or more known legacy permissive policies survived migration cleanup';
  END IF;

  -- Legacy browser-facing tables must not retain powerful direct ACLs.
  -- RLS does not protect TRUNCATE; REFERENCES/TRIGGER are not client capabilities.
  FOREACH required_table IN ARRAY ARRAY[
    'customer_profiles', 'seller_shops', 'products', 'cart_items',
    'orders', 'order_items', 'order_idempotency_keys', 'reviews',
    'review_helpful_votes', 'wishlist_items', 'sarvex_admin_allowlist',
    'categories'
  ] LOOP
    IF has_table_privilege('anon', format('public.%I', required_table), 'INSERT')
       OR has_table_privilege('anon', format('public.%I', required_table), 'UPDATE')
       OR has_table_privilege('anon', format('public.%I', required_table), 'DELETE')
       OR has_table_privilege('anon', format('public.%I', required_table), 'TRUNCATE')
       OR has_table_privilege('anon', format('public.%I', required_table), 'REFERENCES')
       OR has_table_privilege('anon', format('public.%I', required_table), 'TRIGGER') THEN
      RAISE EXCEPTION 'Anonymous role retains an unsafe direct privilege on public.%', required_table;
    END IF;

    IF has_table_privilege('authenticated', format('public.%I', required_table), 'TRUNCATE')
       OR has_table_privilege('authenticated', format('public.%I', required_table), 'REFERENCES')
       OR has_table_privilege('authenticated', format('public.%I', required_table), 'TRIGGER') THEN
      RAISE EXCEPTION 'Authenticated role retains an unsafe direct privilege on public.%', required_table;
    END IF;
  END LOOP;

  -- Private supplier/dropshipping foundation: tables must exist, use RLS,
  -- and remain inaccessible to browser roles until trusted RPCs are added.
  FOREACH required_table IN ARRAY ARRAY[
    'supplier_profiles',
    'supplier_stock',
    'supplier_offers',
    'reseller_listings',
    'supplier_order_allocations',
    'supplier_fulfilment_events'
  ] LOOP
    IF to_regclass(format('public.%I', required_table)) IS NULL THEN
      RAISE EXCEPTION 'Missing private supplier foundation table: public.%', required_table;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = required_table
        AND c.relrowsecurity
    ) THEN
      RAISE EXCEPTION 'RLS is not enabled on private supplier table public.%', required_table;
    END IF;

    IF has_table_privilege('anon', format('public.%I', required_table), 'SELECT')
       OR has_table_privilege('anon', format('public.%I', required_table), 'INSERT')
       OR has_table_privilege('authenticated', format('public.%I', required_table), 'SELECT')
       OR has_table_privilege('authenticated', format('public.%I', required_table), 'INSERT')
       OR has_table_privilege('authenticated', format('public.%I', required_table), 'UPDATE')
       OR has_table_privilege('authenticated', format('public.%I', required_table), 'DELETE') THEN
      RAISE EXCEPTION 'Browser role has direct access to private supplier table public.%', required_table;
    END IF;

    IF NOT has_table_privilege('service_role', format('public.%I', required_table), 'SELECT')
       OR NOT has_table_privilege('service_role', format('public.%I', required_table), 'INSERT')
       OR NOT has_table_privilege('service_role', format('public.%I', required_table), 'UPDATE')
       OR NOT has_table_privilege('service_role', format('public.%I', required_table), 'DELETE') THEN
      RAISE EXCEPTION 'Trusted service_role lacks expected access to public.%', required_table;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.supplier_order_allocations'::regclass
      AND conname = 'supplier_order_allocations_payment_method_check'
  ) THEN
    RAISE EXCEPTION 'Supplier allocation must explicitly restrict payment methods (COD is not enabled)';
  END IF;

  IF has_table_privilege('authenticated', 'public.supplier_order_allocations', 'SELECT') THEN
    RAISE EXCEPTION 'Authenticated users must not read supplier wholesale or payout snapshots';
  END IF;


  -- Supplier/reseller RPC surface: authenticated-only, no anonymous execution.
  IF to_regprocedure('public.supplier_apply(text,text,text,text,text,text,text)') IS NULL
     OR to_regprocedure('public.supplier_save_stock(uuid,text,text,text,text,text,integer,boolean)') IS NULL
     OR to_regprocedure('public.supplier_create_offer(uuid,numeric,integer,boolean)') IS NULL
     OR to_regprocedure('public.reseller_create_listing(uuid,numeric,text,text,text)') IS NULL
     OR to_regprocedure('public.admin_review_supplier(uuid,text)') IS NULL
     OR to_regprocedure('public.admin_review_supplier_offer(uuid,text)') IS NULL
     OR to_regprocedure('public.admin_review_reseller_listing(uuid,text)') IS NULL
     OR to_regprocedure('public.get_my_supplier_workspace()') IS NULL THEN
    RAISE EXCEPTION 'One or more supplier/reseller workspace RPCs are missing';
  END IF;

  IF has_function_privilege('anon', 'public.supplier_apply(text,text,text,text,text,text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.supplier_save_stock(uuid,text,text,text,text,text,integer,boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.supplier_create_offer(uuid,numeric,integer,boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.reseller_create_listing(uuid,numeric,text,text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.admin_review_supplier(uuid,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.admin_review_supplier_offer(uuid,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.admin_review_reseller_listing(uuid,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.get_my_supplier_workspace()', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role can execute a private supplier/reseller RPC';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.supplier_apply(text,text,text,text,text,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.supplier_save_stock(uuid,text,text,text,text,text,integer,boolean)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.supplier_create_offer(uuid,numeric,integer,boolean)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.reseller_create_listing(uuid,numeric,text,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.admin_review_supplier(uuid,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.admin_review_supplier_offer(uuid,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.admin_review_reseller_listing(uuid,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.get_my_supplier_workspace()', 'EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated role is missing an intended supplier/reseller RPC grant';
  END IF;

  IF has_function_privilege('anon', 'public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role can execute checkout';
  END IF;


  IF to_regprocedure('public.browse_supplier_offers()') IS NULL
     OR to_regprocedure('public.admin_list_supplier_review_queue()') IS NULL THEN
    RAISE EXCEPTION 'Supplier offer discovery or admin review queue RPC is missing';
  END IF;
  IF has_function_privilege('anon', 'public.browse_supplier_offers()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.admin_list_supplier_review_queue()', 'EXECUTE') THEN
    RAISE EXCEPTION 'Anonymous role can execute supplier discovery/admin queue RPC';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.browse_supplier_offers()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.admin_list_supplier_review_queue()', 'EXECUTE') THEN
    RAISE EXCEPTION 'Authenticated role is missing supplier discovery/admin queue RPC grants';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets
    WHERE id = 'product-images' AND public = true
  ) THEN
    RAISE EXCEPTION 'Public product-images bucket is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets
    WHERE id = 'seller-kyc-documents' AND public = false
  ) THEN
    RAISE EXCEPTION 'Private seller-kyc-documents bucket is missing or public';
  END IF;
END
$$;

SELECT 'SARVEX migration runtime smoke checks passed' AS result;
