-- Public reseller catalogue exposes only approved retail data to anonymous users.
-- Fixtures are synthetic and rolled back.
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
  v_listing_id UUID;
  v_result JSONB;
BEGIN
  INSERT INTO auth.users (id, email, email_confirmed_at)
  VALUES
    (v_admin, 'public-catalog-admin@example.invalid', now()),
    (v_supplier, 'public-catalog-supplier@example.invalid', now()),
    (v_reseller, 'public-catalog-reseller@example.invalid', now());

  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM public.bootstrap_first_admin(v_admin);

  INSERT INTO public.seller_shops (id, owner_id, shop_name, approval_status, owner_name)
  VALUES
    (v_supplier_shop, v_supplier, 'Private Supplier Shop', 'approved', 'Supplier Test'),
    (v_reseller_shop, v_reseller, 'Public Reseller Shop', 'approved', 'Reseller Test');

  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  v_result := public.supplier_apply(
    'Private Supplier Business', 'Private Contact', '9876543210',
    '99 Private Dispatch Lane', 'Jaipur', 'Rajasthan', '302001'
  );
  v_supplier_id := (v_result ->> 'supplier_id')::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM public.admin_review_supplier(v_supplier_id, 'approved');

  PERFORM set_config('request.jwt.claim.sub', v_supplier::text, true);
  v_result := public.supplier_save_stock(NULL, 'PUB-1', 'Source Product',
    'Source description', 'electronics', 'https://example.invalid/source.jpg', 12, true);
  v_stock_id := (v_result ->> 'stock_id')::uuid;
  v_result := public.supplier_create_offer(v_stock_id, 75.00, 1, true);
  v_offer_id := (v_result ->> 'offer_id')::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM public.admin_review_supplier_offer(v_offer_id, 'active');

  PERFORM set_config('request.jwt.claim.sub', v_reseller::text, true);
  v_result := public.reseller_create_listing(
    v_offer_id, 129.00, 'Customer-facing Product', 'Customer-facing description',
    'https://example.invalid/public.jpg'
  );
  v_listing_id := (v_result ->> 'listing_id')::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_admin::text, true);
  PERFORM public.admin_review_reseller_listing(v_listing_id, 'active');

  -- Anonymous callers can execute the public RPC, but only see approved
  -- customer-facing retail fields. No supplier identity or private economics.
  PERFORM set_config('request.jwt.claim.sub', '', true);
  SET LOCAL ROLE anon;
  v_result := public.browse_public_reseller_catalogue();
  IF jsonb_array_length(v_result) <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one approved public reseller listing: %', v_result;
  END IF;
  IF v_result -> 0 ->> 'title' <> 'Customer-facing Product'
     OR (v_result -> 0 ->> 'retail_price_inr')::numeric <> 129.00
     OR v_result -> 0 ->> 'seller_name' <> 'Public Reseller Shop' THEN
    RAISE EXCEPTION 'Public catalogue retail projection is incorrect: %', v_result;
  END IF;
  IF (v_result -> 0) ?| ARRAY[
    'supplier_id', 'supplier_name', 'dispatch_phone', 'dispatch_address',
    'wholesale_price_inr', 'supplier_unit_cost_inr', 'supplier_payable_inr',
    'reseller_gross_margin_inr', 'platform_fee_amount_inr', 'supplier_offer_id'
  ] THEN
    RAISE EXCEPTION 'Public catalogue leaked private supplier or financial data: %', v_result;
  END IF;
  RESET ROLE;
END
$$;

ROLLBACK;
