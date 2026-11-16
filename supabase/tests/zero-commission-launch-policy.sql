DO $$
DECLARE
  v_shop_default TEXT;
  v_item_default TEXT;
  v_trigger_source TEXT;
  v_checkout_source TEXT;
  v_nonzero_shops BIGINT;
BEGIN
  SELECT pg_get_expr(d.adbin, d.adrelid)
    INTO v_shop_default
  FROM pg_attrdef d
  JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
  WHERE d.adrelid = 'public.seller_shops'::regclass AND a.attname = 'commission_rate';

  IF COALESCE(v_shop_default, '') NOT LIKE '0%' THEN
    RAISE EXCEPTION 'FAIL: seller_shops commission default is not 0 (found %)', v_shop_default;
  END IF;

  SELECT pg_get_expr(d.adbin, d.adrelid)
    INTO v_item_default
  FROM pg_attrdef d
  JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
  WHERE d.adrelid = 'public.order_items'::regclass AND a.attname = 'commission_rate';

  IF COALESCE(v_item_default, '') NOT LIKE '0%' THEN
    RAISE EXCEPTION 'FAIL: order_items commission default is not 0 (found %)', v_item_default;
  END IF;

  SELECT pg_get_functiondef('public.protect_seller_shop_status()'::regprocedure)
    INTO v_trigger_source;
  IF position('NEW.commission_rate := 0.00' IN v_trigger_source) = 0 THEN
    RAISE EXCEPTION 'FAIL: seller registration trigger does not force 0% commission';
  END IF;

  SELECT pg_get_functiondef('public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)'::regprocedure)
    INTO v_checkout_source;
  IF position('COALESCE(s.commission_rate, 0.0)' IN v_checkout_source) = 0
     OR position('COALESCE(v_prod.commission_rate, 0.0)' IN v_checkout_source) = 0 THEN
    RAISE EXCEPTION 'FAIL: COD order RPC still has a non-zero commission fallback';
  END IF;

  SELECT count(*) INTO v_nonzero_shops
  FROM public.seller_shops WHERE commission_rate <> 0.00;
  IF v_nonzero_shops <> 0 THEN
    RAISE EXCEPTION 'FAIL: % seller shops still have non-zero commission', v_nonzero_shops;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.seller_shops'::regclass
      AND conname = 'seller_shops_launch_zero_commission_check'
      AND contype = 'c'
      AND convalidated
  ) THEN
    RAISE EXCEPTION 'FAIL: zero-commission launch policy constraint missing or unvalidated';
  END IF;
END
$$;
