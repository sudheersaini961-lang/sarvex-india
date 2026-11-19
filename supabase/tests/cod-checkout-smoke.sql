-- End-to-end COD checkout smoke test for disposable CI databases only.
-- Uses Auth users, an approved test seller, and a test product. Entire test rolls back.

BEGIN;

INSERT INTO auth.users (id, email, email_confirmed_at, raw_user_meta_data)
VALUES
 ('51000000-0000-4000-8000-000000000001','sarvex-ci-customer@example.invalid',now(),'{"full_name":"CI Checkout Customer","account_role":"admin"}'::jsonb),
 ('51000000-0000-4000-8000-000000000002','sarvex-ci-seller@example.invalid',now(),'{"full_name":"CI Checkout Seller","account_role":"seller"}'::jsonb);

INSERT INTO public.seller_shops (id, owner_id, shop_name, approval_status, commission_rate)
VALUES ('52000000-0000-4000-8000-000000000001',
        '51000000-0000-4000-8000-000000000002',
        'CI Approved Seller Shop', 'approved', 10);

INSERT INTO public.products (
  id, seller_shop_id, product_name, category, price_inr, mrp,
  stock_quantity, discount_percent, image_url
)
VALUES (
 '53000000-0000-4000-8000-000000000001',
 '52000000-0000-4000-8000-000000000001',
 'CI COD Product', 'mobiles', 100, 120, 5, 17, 'https://example.invalid/ci-product.png'
);

SELECT set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;

DO $cod_checkout$
DECLARE
  v_first jsonb;
  v_replay jsonb;
  v_order_id uuid;
  v_count bigint;
  v_stock integer;
  v_item_count bigint;
  v_reuse_rejected boolean := false;
BEGIN
  v_first := public.place_sarvex_order(
    'CI Checkout Customer', '9876543210', 'sarvex-ci-customer@example.invalid',
    'House 1, CI Test Road', 'Jaipur', 'Rajasthan', '302001',
    '[{"product_id":"53000000-0000-4000-8000-000000000001","quantity":2}]'::jsonb,
    'sarvex-ci-cod-idempotency-key'
  );

  IF COALESCE((v_first->>'success')::boolean,false) IS NOT TRUE THEN
    RAISE EXCEPTION 'COD checkout did not return success: %', v_first;
  END IF;

  v_order_id := (v_first->>'order_id')::uuid;
  IF v_order_id IS NULL OR v_first->>'status' <> 'placed'
     OR (v_first->>'total_amount')::numeric <> 200 THEN
    RAISE EXCEPTION 'COD checkout returned an unexpected order payload: %', v_first;
  END IF;

  v_replay := public.place_sarvex_order(
    'CI Checkout Customer', '9876543210', 'sarvex-ci-customer@example.invalid',
    'House 1, CI Test Road', 'Jaipur', 'Rajasthan', '302001',
    '[{"product_id":"53000000-0000-4000-8000-000000000001","quantity":2}]'::jsonb,
    'sarvex-ci-cod-idempotency-key'
  );

  IF (v_replay->>'order_id')::uuid IS DISTINCT FROM v_order_id THEN
    RAISE EXCEPTION 'Idempotent retry created or returned a different order: %', v_replay;
  END IF;

  SELECT count(*) INTO v_count FROM public.orders WHERE id = v_order_id AND customer_id = auth.uid() AND payment_method = 'cod' AND status = 'placed';
  IF v_count <> 1 THEN RAISE EXCEPTION 'Expected exactly one placed COD order; found %', v_count; END IF;

  SELECT count(*) INTO v_item_count FROM public.order_items WHERE order_id = v_order_id AND product_id = '53000000-0000-4000-8000-000000000001' AND quantity = 2;
  IF v_item_count <> 1 THEN RAISE EXCEPTION 'Expected one order item with quantity 2; found %', v_item_count; END IF;

  SELECT stock_quantity INTO v_stock FROM public.products WHERE id = '53000000-0000-4000-8000-000000000001';
  IF v_stock <> 3 THEN RAISE EXCEPTION 'Stock was not reserved exactly once; expected 3 remaining, found %', v_stock; END IF;

  BEGIN
    PERFORM public.place_sarvex_order(
      'Different Customer Name', '9876543210', 'sarvex-ci-customer@example.invalid',
      'House 1, CI Test Road', 'Jaipur', 'Rajasthan', '302001',
      '[{"product_id":"53000000-0000-4000-8000-000000000001","quantity":2}]'::jsonb,
      'sarvex-ci-cod-idempotency-key'
    );
    RAISE EXCEPTION 'Reusing an idempotency key with a different payload was accepted';
  EXCEPTION WHEN SQLSTATE '42804' THEN
    v_reuse_rejected := true;
  END;

  IF NOT v_reuse_rejected THEN RAISE EXCEPTION 'Different-payload idempotency replay was not rejected'; END IF;
END
$cod_checkout$;

RESET ROLE;
ROLLBACK;

SELECT 'SARVEX COD checkout, stock reservation and idempotency smoke checks passed' AS result;
