-- Assertions after upgrading the reproduced legacy starter schema.
DO $legacy_smoke$
DECLARE
  v_count bigint;
BEGIN
  SELECT count(*) INTO v_count FROM public.customer_profiles
  WHERE owner_id = '20000000-0000-4000-8000-000000000001'
    AND display_name = 'Preserved SARVEX Customer';
  IF v_count <> 1 THEN RAISE EXCEPTION 'Legacy customer profile was not preserved'; END IF;

  SELECT count(*) INTO v_count FROM public.seller_shops
  WHERE id = '30000000-0000-4000-8000-000000000001'
    AND approval_status = 'pending';
  IF v_count <> 1 THEN RAISE EXCEPTION 'Legacy pending seller was not preserved'; END IF;

  SELECT count(*) INTO v_count FROM public.products
  WHERE id IN (
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000004'
  );
  IF v_count <> 4 THEN RAISE EXCEPTION 'Legacy product rows were not preserved: %', v_count; END IF;

  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public'
      AND policyname IN (
        'customer_profiles_create_policy','customer_profiles_delete_policy',
        'customer_profiles_read_policy','customer_profiles_update_policy',
        'seller_shops_create_policy','seller_shops_delete_policy',
        'seller_shops_read_policy','seller_shops_update_policy',
        'products_create_policy','products_delete_policy',
        'products_read_policy','products_update_policy',
        'cart_items_create_policy','cart_items_delete_policy',
        'cart_items_read_policy','cart_items_update_policy'
      )
  ) THEN
    RAISE EXCEPTION 'Insecure legacy policies remain after migration';
  END IF;

  IF has_table_privilege('anon','public.customer_profiles','INSERT')
     OR has_table_privilege('anon','public.seller_shops','UPDATE')
     OR has_table_privilege('anon','public.products','DELETE')
     OR has_table_privilege('anon','public.cart_items','INSERT') THEN
    RAISE EXCEPTION 'anon retains direct marketplace write privileges after migration';
  END IF;

  -- New objects created later by the migration owner must not inherit public-client
  -- table/sequence privileges or PUBLIC/anon/authenticated function EXECUTE.
  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) a
    WHERE d.defaclrole = 'postgres'::regrole
      AND d.defaclnamespace = 'public'::regnamespace
      AND (
        (d.defaclobjtype = 'r' AND a.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole))
        OR (d.defaclobjtype = 'S' AND a.grantee IN ('anon'::regrole, 'authenticated'::regrole))
        OR (d.defaclobjtype = 'f' AND a.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole))
      )
  ) THEN
    RAISE EXCEPTION 'Public-client default privileges remain for future public objects';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname='set_updated_at'
      AND p.proconfig @> ARRAY['search_path=pg_catalog, public, pg_temp']
  ) THEN
    RAISE EXCEPTION 'set_updated_at search_path was not hardened (or the function is absent)';
  END IF;
END
$legacy_smoke$;

SELECT 'SARVEX legacy data preservation and RLS hardening checks passed' AS result;
