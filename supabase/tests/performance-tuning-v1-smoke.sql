-- Read-only assertions for SARVEX database performance tuning v1.
-- Runs only in disposable PostgreSQL CI databases, never on live Supabase.
DO $smoke$
DECLARE
  v_count integer;
BEGIN
  -- All request-stable auth.uid() calls in the targeted policies must be
  -- scalar-subquery wrapped; raw per-row forms are a regression.
  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'cart_items','customer_profiles','seller_shops',
        'order_idempotency_keys','orders','order_items',
        'reviews','review_helpful_votes','wishlist_items'
      )
      AND (
        COALESCE(qual, '') ~ 'auth[.]uid\(\)[[:space:]]*='
        OR COALESCE(with_check, '') ~ 'auth[.]uid\(\)[[:space:]]*='
        OR COALESCE(qual, '') ~ 'auth[.]uid\(\)[[:space:]]+IS'
        OR COALESCE(with_check, '') ~ 'auth[.]uid\(\)[[:space:]]+IS'
      )
  ) THEN
    RAISE EXCEPTION 'FAIL: a targeted RLS policy contains an unwrapped auth.uid() call';
  END IF;

  -- Category SELECT must remain public and singular; admin writes remain protected.
  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname='public' AND tablename='categories' AND cmd='SELECT';
  IF v_count <> 1 OR NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='categories'
      AND policyname='Public read categories' AND cmd='SELECT'
      AND qual='true'
  ) THEN
    RAISE EXCEPTION 'FAIL: public category read policy changed';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='categories'
      AND policyname='Admins insert categories' AND cmd='INSERT'
      AND with_check LIKE '%is_sarvex_admin%'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='categories'
      AND policyname='Admins update categories' AND cmd='UPDATE'
      AND qual LIKE '%is_sarvex_admin%' AND with_check LIKE '%is_sarvex_admin%'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='categories'
      AND policyname='Admins delete categories' AND cmd='DELETE'
      AND qual LIKE '%is_sarvex_admin%'
  ) THEN
    RAISE EXCEPTION 'FAIL: admin category write policies missing or unprotected';
  END IF;

  -- The ALL policy is sufficient for admin SELECT; duplicate SELECT policy is removed.
  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname='public' AND tablename='sarvex_admin_allowlist' AND cmd='SELECT';
  IF v_count <> 1 OR NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='sarvex_admin_allowlist'
      AND policyname='Only admins manage admin allowlist' AND cmd='ALL'
  ) OR EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='sarvex_admin_allowlist'
      AND policyname='Only admins view admin allowlist'
  ) THEN
    RAISE EXCEPTION 'FAIL: admin allowlist policy consolidation failed';
  END IF;

  -- Required FK indexes exist and duplicate indexes are gone.
  IF to_regclass('public.idx_order_idempotency_keys_order_id') IS NULL
     OR to_regclass('public.idx_order_items_product_id') IS NULL
     OR to_regclass('public.idx_wishlist_items_product_id') IS NULL THEN
    RAISE EXCEPTION 'FAIL: one or more foreign-key covering indexes are missing';
  END IF;

  IF to_regclass('public.cart_items_owner_id_idx') IS NOT NULL
     OR to_regclass('public.products_category_idx') IS NOT NULL
     OR to_regclass('public.products_seller_shop_id_idx') IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL: duplicate indexes remain';
  END IF;

  IF NOT has_table_privilege('anon','public.categories','SELECT')
     OR has_table_privilege('anon','public.categories','INSERT')
     OR has_table_privilege('authenticated','public.categories','INSERT') THEN
    RAISE EXCEPTION 'FAIL: category table grants changed unexpectedly';
  END IF;
END
$smoke$;

SELECT 'SARVEX database performance tuning v1: PASS' AS result;
