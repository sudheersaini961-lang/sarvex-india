-- Dropship checkout reservation isolation, pricing, idempotency and stock tests.
-- Synthetic fixtures only; transaction is rolled back.
BEGIN;
DO $$
DECLARE
  v_admin UUID := gen_random_uuid();
  v_supplier UUID := gen_random_uuid();
  v_reseller UUID := gen_random_uuid();
  v_customer UUID := gen_random_uuid();
  v_supplier_shop UUID := gen_random_uuid();
  v_reseller_shop UUID := gen_random_uuid();
  v_supplier_id UUID := gen_random_uuid();
  v_stock_id UUID := gen_random_uuid();
  v_offer_id UUID := gen_random_uuid();
  v_listing_id UUID := gen_random_uuid();
  v_result JSONB;
  v_reservation UUID;
  v_reserved INTEGER;
  v_blocked BOOLEAN;
  v_public JSONB;
  v_expired_count INTEGER;
  v_key TEXT := 'test-reservation-key-0001';
BEGIN
  INSERT INTO auth.users (id, email, email_confirmed_at)
  VALUES
    (v_admin, 'dropship-reservation-admin@example.invalid', NOW()),
    (v_supplier, 'dropship-reservation-supplier@example.invalid', NOW()),
    (v_reseller, 'dropship-reservation-reseller@example.invalid', NOW()),
    (v_customer, 'dropship-reservation-customer@example.invalid', NOW());

  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM public.bootstrap_first_admin(v_admin);

  INSERT INTO public.seller_shops (id, owner_id, shop_name, approval_status, owner_name, commission_rate)
  VALUES
    (v_supplier_shop, v_supplier, 'Reservation Supplier', 'pending', 'Supplier', 10),
    (v_reseller_shop, v_reseller, 'Reservation Reseller', 'pending', 'Reseller', 10);

  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  UPDATE public.seller_shops SET approval_status = 'approved'
  WHERE id IN (v_supplier_shop, v_reseller_shop);

  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  v_result := public.supplier_apply(
    'Reservation Supplier Business', 'Supplier Contact', '9876543210',
    '12 Test Market Road', 'Jaipur', 'Rajasthan', '302001'
  );
  v_supplier_id := (v_result->>'supplier_id')::UUID;

  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM public.admin_review_supplier(v_supplier_id, 'approved');

  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  v_result := public.supplier_save_stock(NULL, 'RESERVE-1', 'Reserve Test Product',
    'Test item', 'electronics', NULL, 5, true);
  v_stock_id := (v_result->>'stock_id')::UUID;
  v_result := public.supplier_create_offer(v_stock_id, 100, 1, true);
  v_offer_id := (v_result->>'offer_id')::UUID;

  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM public.admin_review_supplier_offer(v_offer_id, 'active');

  PERFORM set_config('request.jwt.claim.sub', v_reseller::text, true);
  v_result := public.reseller_create_listing(v_offer_id, 150, 'Reserve Test Retail', NULL, NULL);
  v_listing_id := (v_result->>'listing_id')::UUID;
  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM public.admin_review_reseller_listing(v_listing_id, 'active');

  PERFORM set_config('request.jwt.claim.sub', v_customer::text, true);
  v_result := public.create_dropship_checkout_reservation(
    jsonb_build_array(jsonb_build_object('listing_id', v_listing_id, 'quantity', 2)), v_key
  );
  v_reservation := (v_result->>'reservation_id')::UUID;
  IF v_result->>'status' <> 'active'
     OR v_result->>'payment_verified' <> 'false'
     OR v_result->>'order_created' <> 'false'
     OR v_result->>'cod_available' <> 'false'
     OR (v_result->>'retail_total_inr')::NUMERIC <> 300 THEN
    RAISE EXCEPTION 'Reservation response has incorrect payment/order/price state: %', v_result;
  END IF;

  SELECT reserved_quantity INTO v_reserved FROM public.supplier_stock WHERE id = v_stock_id;
  IF v_reserved <> 2 THEN RAISE EXCEPTION 'Expected 2 reserved units, got %', v_reserved; END IF;

  v_public := public.browse_public_reseller_catalogue();
  IF (v_public -> 0 ->> 'available_quantity')::INTEGER <> 3 THEN
    RAISE EXCEPTION 'Public catalogue did not subtract reserved units: %', v_public;
  END IF;

  -- Same customer/key/payload returns the original hold without reserving twice.
  v_result := public.create_dropship_checkout_reservation(
    jsonb_build_array(jsonb_build_object('listing_id', v_listing_id, 'quantity', 2)), v_key
  );
  IF (v_result->>'reservation_id')::UUID <> v_reservation OR v_result->>'replayed' <> 'true' THEN
    RAISE EXCEPTION 'Idempotent replay did not return original reservation: %', v_result;
  END IF;
  SELECT reserved_quantity INTO v_reserved FROM public.supplier_stock WHERE id = v_stock_id;
  IF v_reserved <> 2 THEN RAISE EXCEPTION 'Idempotent replay double-reserved stock'; END IF;

  v_blocked := false;
  BEGIN
    PERFORM public.create_dropship_checkout_reservation(
      jsonb_build_array(jsonb_build_object('listing_id', v_listing_id, 'quantity', 4)),
      'different-reservation-key-0002'
    );
  EXCEPTION WHEN OTHERS THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'Overselling was not blocked'; END IF;

  v_blocked := false;
  BEGIN
    PERFORM public.create_dropship_checkout_reservation(
      jsonb_build_array(jsonb_build_object('listing_id', v_listing_id, 'quantity', 1)),
      v_key
    );
  EXCEPTION WHEN OTHERS THEN v_blocked := true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'Idempotency key reuse with changed payload was not blocked'; END IF;

  IF NOT public.cancel_dropship_checkout_reservation(v_reservation) THEN
    RAISE EXCEPTION 'Customer could not cancel active reservation';
  END IF;
  SELECT reserved_quantity INTO v_reserved FROM public.supplier_stock WHERE id = v_stock_id;
  IF v_reserved <> 0 THEN RAISE EXCEPTION 'Cancellation did not release stock'; END IF;

  IF public.cancel_dropship_checkout_reservation(v_reservation) THEN
    RAISE EXCEPTION 'Released reservation was cancelled twice';
  END IF;

  -- Expiry worker releases stock held by an abandoned checkout.
  v_result := public.create_dropship_checkout_reservation(
    jsonb_build_array(jsonb_build_object('listing_id', v_listing_id, 'quantity', 1)),
    'expiry-reservation-key-0003'
  );
  v_reservation := (v_result->>'reservation_id')::UUID;
  UPDATE public.dropship_checkout_reservations
  SET expires_at = NOW() - INTERVAL '1 minute'
  WHERE id = v_reservation;
  v_expired_count := public.release_expired_dropship_reservations();
  IF v_expired_count <> 1 THEN
    RAISE EXCEPTION 'Expiry worker did not expire exactly one reservation: %', v_expired_count;
  END IF;
  SELECT reserved_quantity INTO v_reserved FROM public.supplier_stock WHERE id = v_stock_id;
  IF v_reserved <> 0 THEN RAISE EXCEPTION 'Expired reservation did not release stock'; END IF;
  IF (SELECT status FROM public.dropship_checkout_reservations WHERE id = v_reservation) <> 'expired' THEN
    RAISE EXCEPTION 'Expired reservation status was not recorded';
  END IF;
END
$$;
ROLLBACK;
