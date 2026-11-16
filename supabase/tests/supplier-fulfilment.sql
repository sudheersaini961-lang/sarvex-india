-- Supplier acceptance and manual dispatch state/ownership/privacy tests.
-- Uses synthetic rows only; the entire transaction is rolled back.
BEGIN;

DO $$
DECLARE
  v_admin UUID := gen_random_uuid();
  v_supplier UUID := gen_random_uuid();
  v_other UUID := gen_random_uuid();
  v_supplier_shop UUID := gen_random_uuid();
  v_other_shop UUID := gen_random_uuid();
  v_supplier_id UUID := gen_random_uuid();
  v_other_supplier_id UUID := gen_random_uuid();
  v_stock_id UUID := gen_random_uuid();
  v_offer_id UUID := gen_random_uuid();
  v_order_id UUID := gen_random_uuid();
  v_order_item_id UUID := gen_random_uuid();
  v_allocation_id UUID := gen_random_uuid();
  v_result JSONB;
  v_blocked BOOLEAN;
  v_event_count INTEGER;
BEGIN
  INSERT INTO auth.users (id, email, email_confirmed_at)
  VALUES
    (v_admin, 'supplier-fulfilment-admin@example.invalid', NOW()),
    (v_supplier, 'supplier-fulfilment-owner@example.invalid', NOW()),
    (v_other, 'supplier-fulfilment-other@example.invalid', NOW());

  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM public.bootstrap_first_admin(v_admin);

  INSERT INTO public.seller_shops (id, owner_id, shop_name, approval_status, owner_name)
  VALUES
    (v_supplier_shop, v_supplier, 'Fulfilment Supplier Shop', 'pending', 'Supplier'),
    (v_other_shop, v_other, 'Other Supplier Shop', 'pending', 'Other');

  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  UPDATE public.seller_shops SET approval_status = 'approved'
  WHERE id IN (v_supplier_shop, v_other_shop);

  INSERT INTO public.supplier_profiles (
    id, seller_shop_id, approval_status, business_name, approved_by, approved_at
  ) VALUES
    (v_supplier_id, v_supplier_shop, 'approved', 'Fulfilment Supplier', v_admin, NOW()),
    (v_other_supplier_id, v_other_shop, 'approved', 'Other Supplier', v_admin, NOW());

  INSERT INTO public.supplier_stock (
    id, supplier_id, product_name, category, available_quantity, active
  ) VALUES (v_stock_id, v_supplier_id, 'Test Dispatch Item', 'electronics', 5, true);

  INSERT INTO public.supplier_offers (
    id, supplier_id, supplier_stock_id, wholesale_price_inr,
    minimum_order_quantity, direct_to_customer_dispatch, offer_status
  ) VALUES (v_offer_id, v_supplier_id, v_stock_id, 100, 1, true, 'active');

  INSERT INTO public.orders (
    id, order_code, customer_id, customer_name, customer_phone,
    shipping_address, city, state, pincode, total_amount, payment_method, status
  ) VALUES (
    v_order_id, 'SRX-FULFILMENT-TEST', v_other, 'Synthetic Customer',
    '9876543210', '42 Test Road', 'Jaipur', 'Rajasthan', '302001',
    150, 'upi', 'confirmed'
  );

  INSERT INTO public.order_items (
    id, order_id, product_name, price_inr, quantity, item_status
  ) VALUES (
    v_order_item_id, v_order_id, 'Test Dispatch Item', 150, 1, 'confirmed'
  );

  INSERT INTO public.supplier_order_allocations (
    id, order_item_id, supplier_id, supplier_offer_id, fulfilment_mode,
    quantity, supplier_unit_cost_inr, customer_unit_price_inr,
    platform_fee_rate, platform_fee_amount_inr, supplier_payable_inr,
    reseller_gross_margin_inr, payment_method, allocation_status
  ) VALUES (
    v_allocation_id, v_order_item_id, v_supplier_id, v_offer_id, 'supplier_direct',
    1, 100, 150, 0, 0, 100, 50, 'upi', 'awaiting_supplier'
  );

  PERFORM set_config('request.jwt.claim.sub', v_other::text, true);
  v_blocked := false;
  BEGIN
    PERFORM public.supplier_update_fulfilment(v_allocation_id, 'accept');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Unrelated supplier updated another supplier allocation';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  v_result := public.get_my_supplier_fulfilments();
  IF jsonb_array_length(v_result) <> 1
     OR v_result -> 0 ->> 'allocation_id' <> v_allocation_id::text
     OR v_result -> 0 ->> 'shipping_address' IS NOT NULL
     OR v_result -> 0 ->> 'customer_phone' IS NOT NULL THEN
    RAISE EXCEPTION 'Pending supplier fulfilment read leaked address/phone or omitted allocation: %', v_result;
  END IF;

  v_blocked := false;
  BEGIN
    PERFORM public.supplier_update_fulfilment(v_allocation_id, 'shipped', 'Courier X', 'TRACK-123');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Supplier shipped an allocation before acceptance';
  END IF;

  v_result := public.supplier_update_fulfilment(v_allocation_id, 'accept');
  IF v_result ->> 'allocation_status' <> 'accepted' THEN
    RAISE EXCEPTION 'Supplier acceptance transition failed: %', v_result;
  END IF;

  v_result := public.get_my_supplier_fulfilments();
  IF v_result -> 0 ->> 'shipping_address' <> '42 Test Road'
     OR v_result -> 0 ->> 'customer_phone' <> '9876543210' THEN
    RAISE EXCEPTION 'Accepted supplier could not access required delivery details: %', v_result;
  END IF;

  v_result := public.supplier_update_fulfilment(v_allocation_id, 'packed');
  IF v_result ->> 'allocation_status' <> 'dispatch_pending' THEN
    RAISE EXCEPTION 'Supplier packed transition failed: %', v_result;
  END IF;

  v_result := public.supplier_update_fulfilment(
    v_allocation_id, 'shipped', 'Manual Courier', 'MANUAL-TRACK-123', 'Handed to courier'
  );
  IF v_result ->> 'allocation_status' <> 'shipped'
     OR v_result ->> 'tracking_verification' <> 'supplier_reported_not_courier_verified' THEN
    RAISE EXCEPTION 'Supplier dispatch was not correctly labelled as unverified: %', v_result;
  END IF;

  SELECT count(*) INTO v_event_count
  FROM public.supplier_fulfilment_events
  WHERE allocation_id = v_allocation_id;
  IF v_event_count <> 3 THEN
    RAISE EXCEPTION 'Expected exactly 3 append-only fulfilment events, got %', v_event_count;
  END IF;

  v_blocked := false;
  BEGIN
    PERFORM public.supplier_update_fulfilment(v_allocation_id, 'delivered');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Supplier was allowed to self-assert delivery without courier verification';
  END IF;
END
$$;

ROLLBACK;
