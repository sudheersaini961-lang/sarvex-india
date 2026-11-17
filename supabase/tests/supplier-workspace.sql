-- End-to-end supplier/reseller workspace RPC tests.
-- All synthetic users, shops, and supplier records are rolled back.
BEGIN;

DO $$
DECLARE
  v_admin UUID := gen_random_uuid();
  v_supplier UUID := gen_random_uuid();
  v_reseller UUID := gen_random_uuid();
  v_supplier_shop UUID := gen_random_uuid();
  v_reseller_shop UUID := gen_random_uuid();
  v_supplier_id UUID;
  v_stock_id UUID;
  v_offer_id UUID;
  v_non_dispatch_offer_id UUID;
  v_listing_id UUID;
  v_result JSONB;
  v_blocked BOOLEAN;
BEGIN
  INSERT INTO auth.users (id, email, email_confirmed_at)
  VALUES
    (v_admin, 'supplier-workspace-admin@example.invalid', now()),
    (v_supplier, 'supplier-workspace-supplier@example.invalid', now()),
    (v_reseller, 'supplier-workspace-reseller@example.invalid', now());

  -- Bootstrap must run as a direct database-admin session, not with an HTTP client JWT role.
  RESET request.jwt.claims;
  RESET request.jwt.claim.sub;
  RESET request.jwt.claim.role;
  PERFORM public.bootstrap_first_admin(v_admin);

  -- The seller-shop protection trigger assigns owner_id from auth.uid().
  -- Create each fixture under its own authenticated identity rather than
  -- inserting both rows with an empty or shared JWT subject.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  INSERT INTO public.seller_shops (id, owner_id, shop_name, approval_status, owner_name)
  VALUES (v_supplier_shop, v_supplier, 'Synthetic Supplier Shop', 'pending', 'Supplier Test');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_reseller::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_reseller::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  INSERT INTO public.seller_shops (id, owner_id, shop_name, approval_status, owner_name)
  VALUES (v_reseller_shop, v_reseller, 'Synthetic Reseller Shop', 'pending', 'Reseller Test');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  UPDATE public.seller_shops
  SET approval_status = 'approved'
  WHERE id IN (v_supplier_shop, v_reseller_shop);

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.supplier_apply(
    'Synthetic Supplier Business', 'Supplier Contact', '9876543210',
    '12 Test Market Road', 'Jaipur', 'Rajasthan', '302001'
  );
  v_supplier_id := (v_result ->> 'supplier_id')::uuid;
  IF v_result ->> 'approval_status' <> 'pending' OR v_supplier_id IS NULL THEN
    RAISE EXCEPTION 'Supplier application did not enter pending review';
  END IF;

  v_blocked := false;
  BEGIN
    PERFORM public.supplier_save_stock(NULL, 'SKU-1', 'Test Product', NULL,
      'electronics', NULL, 20, true);
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'Pending supplier unexpectedly saved stock'; END IF;

  -- A normal authenticated seller must not read the admin queue or approve suppliers.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_blocked := false;
  BEGIN
    PERFORM public.admin_list_supplier_review_queue();
  EXCEPTION WHEN raise_exception THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Non-admin supplier unexpectedly accessed the admin review queue';
  END IF;

  v_blocked := false;
  BEGIN
    PERFORM public.admin_review_supplier(v_supplier_id, 'approved');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Non-admin supplier approved a supplier application';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.admin_list_supplier_review_queue();
  IF jsonb_array_length(v_result -> 'suppliers') <> 1
     OR v_result -> 'suppliers' -> 0 ->> 'id' <> v_supplier_id::text THEN
    RAISE EXCEPTION 'Admin review queue did not return the pending supplier';
  END IF;
  PERFORM public.admin_review_supplier(v_supplier_id, 'approved');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.supplier_save_stock(NULL, 'SKU-1', 'Test Product',
    'Supplier-owned test item', 'electronics', 'https://example.invalid/item.jpg', 20, true);
  v_stock_id := (v_result ->> 'stock_id')::uuid;
  IF v_stock_id IS NULL THEN RAISE EXCEPTION 'Supplier stock insert failed'; END IF;

  v_result := public.supplier_create_offer(v_stock_id, 100.00, 1, true);
  v_offer_id := (v_result ->> 'offer_id')::uuid;
  IF v_offer_id IS NULL OR v_result ->> 'offer_status' <> 'pending' THEN
    RAISE EXCEPTION 'Supplier offer did not enter pending review';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM public.admin_review_supplier_offer(v_offer_id, 'active');

  -- An active wholesale offer without supplier-direct dispatch must not be
  -- selectable for a reseller-to-customer fulfilment listing.
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.supplier_create_offer(v_stock_id, 90.00, 1, false);
  v_non_dispatch_offer_id := (v_result ->> 'offer_id')::uuid;
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM public.admin_review_supplier_offer(v_non_dispatch_offer_id, 'active');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_reseller::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_reseller::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_blocked := false;
  BEGIN
    PERFORM public.reseller_create_listing(
      v_non_dispatch_offer_id, 140.00, 'Should Not List', NULL, NULL
    );
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Reseller listing accepted an offer without direct-to-customer dispatch';
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_reseller::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_reseller::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.browse_supplier_offers();
  IF jsonb_array_length(v_result) <> 1
     OR v_result -> 0 ->> 'offer_id' <> v_offer_id::text THEN
    RAISE EXCEPTION 'Approved reseller could not discover the active supplier offer';
  END IF;

  v_result := public.reseller_create_listing(
    v_offer_id, 150.00, 'Reseller Public Test Product', 'Public description', NULL
  );
  v_listing_id := (v_result ->> 'listing_id')::uuid;
  IF v_listing_id IS NULL OR v_result ->> 'listing_status' <> 'pending' THEN
    RAISE EXCEPTION 'Reseller listing did not enter pending review';
  END IF;

  v_blocked := false;
  BEGIN
    PERFORM public.supplier_save_stock(v_stock_id, 'SKU-HACK', 'Tampered Product',
      NULL, 'electronics', NULL, 999, true);
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'Reseller modified another supplier stock'; END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  UPDATE public.seller_shops SET approval_status = 'pending' WHERE id = v_supplier_shop;
  v_blocked := false;
  BEGIN
    PERFORM public.admin_review_reseller_listing(v_listing_id, 'active');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Admin approved a reseller listing while its supplier shop was not approved';
  END IF;
  UPDATE public.seller_shops SET approval_status = 'approved' WHERE id = v_supplier_shop;
  PERFORM public.admin_review_reseller_listing(v_listing_id, 'active');

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_supplier::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.get_my_supplier_workspace();
  IF jsonb_array_length(v_result -> 'stock') <> 1
     OR jsonb_array_length(v_result -> 'supplier_offers') <> 2
     OR jsonb_array_length(v_result -> 'reseller_listings') <> 0 THEN
    RAISE EXCEPTION 'Supplier workspace owner isolation failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_reseller::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_reseller::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_result := public.get_my_supplier_workspace();
  IF v_result -> 'supplier_profile' IS DISTINCT FROM 'null'::jsonb
     OR jsonb_array_length(v_result -> 'stock') <> 0
     OR jsonb_array_length(v_result -> 'reseller_listings') <> 1
     OR (v_result -> 'reseller_listings' -> 0) ? 'dispatch_address' THEN
    RAISE EXCEPTION 'Reseller workspace isolation/privacy failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  v_blocked := false;
  BEGIN
    PERFORM public.browse_supplier_offers();
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Admin test user without an approved seller shop unexpectedly browsed wholesale offers';
  END IF;
END
$$;

ROLLBACK;
