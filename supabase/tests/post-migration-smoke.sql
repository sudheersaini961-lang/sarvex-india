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
