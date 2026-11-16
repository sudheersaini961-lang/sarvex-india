-- Atomic dropship stock reservation and checkout-intent foundation.
-- This is NOT an order/payment capture endpoint. No order is created and no
-- reservation is converted to an order until a trusted payment integration exists.
BEGIN;

ALTER TABLE public.supplier_stock
  ADD COLUMN IF NOT EXISTS reserved_quantity INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.supplier_stock'::regclass
      AND conname = 'supplier_stock_reserved_quantity_check'
  ) THEN
    ALTER TABLE public.supplier_stock
      ADD CONSTRAINT supplier_stock_reserved_quantity_check
      CHECK (reserved_quantity >= 0 AND reserved_quantity <= available_quantity);
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.dropship_checkout_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'released', 'expired', 'converted')),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (customer_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS public.dropship_checkout_reservation_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES public.dropship_checkout_reservations(id) ON DELETE RESTRICT,
  listing_id UUID NOT NULL REFERENCES public.reseller_listings(id) ON DELETE RESTRICT,
  supplier_stock_id UUID NOT NULL REFERENCES public.supplier_stock(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 50),
  retail_unit_price_inr NUMERIC(12,2) NOT NULL CHECK (retail_unit_price_inr > 0),
  supplier_unit_cost_inr NUMERIC(12,2) NOT NULL CHECK (supplier_unit_cost_inr > 0),
  platform_fee_rate NUMERIC(5,2) NOT NULL CHECK (platform_fee_rate BETWEEN 0 AND 100),
  platform_fee_amount_inr NUMERIC(12,2) NOT NULL CHECK (platform_fee_amount_inr >= 0),
  supplier_payable_inr NUMERIC(12,2) NOT NULL CHECK (supplier_payable_inr >= 0),
  reseller_margin_inr NUMERIC(12,2) NOT NULL CHECK (reseller_margin_inr >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (reservation_id, listing_id)
);

CREATE INDEX IF NOT EXISTS dropship_reservations_expiry_idx
  ON public.dropship_checkout_reservations (expires_at)
  WHERE status = 'active';
CREATE INDEX IF NOT EXISTS dropship_reservation_items_stock_idx
  ON public.dropship_checkout_reservation_items (supplier_stock_id);

ALTER TABLE public.dropship_checkout_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dropship_checkout_reservation_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.dropship_checkout_reservations,
  public.dropship_checkout_reservation_items FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.dropship_checkout_reservations,
  public.dropship_checkout_reservation_items TO service_role;

CREATE OR REPLACE FUNCTION public.release_expired_dropship_reservations()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_stock RECORD;
  v_released INTEGER := 0;
BEGIN
  -- Lock affected stock rows in a stable order before changing counters.
  FOR v_stock IN
    SELECT DISTINCT st.id
    FROM public.supplier_stock st
    JOIN public.dropship_checkout_reservation_items ri ON ri.supplier_stock_id = st.id
    JOIN public.dropship_checkout_reservations r ON r.id = ri.reservation_id
    WHERE r.status = 'active' AND r.expires_at <= NOW()
    ORDER BY st.id
    FOR UPDATE OF st
  LOOP
    UPDATE public.supplier_stock st
    SET reserved_quantity = st.reserved_quantity - x.qty,
        updated_at = NOW()
    FROM (
      SELECT SUM(ri.quantity)::INTEGER AS qty
      FROM public.dropship_checkout_reservation_items ri
      JOIN public.dropship_checkout_reservations r ON r.id = ri.reservation_id
      WHERE ri.supplier_stock_id = v_stock.id
        AND r.status = 'active' AND r.expires_at <= NOW()
    ) x
    WHERE st.id = v_stock.id AND x.qty > 0
      AND st.reserved_quantity >= x.qty;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Expired reservation stock counter invariant failed for stock %', v_stock.id;
    END IF;
  END LOOP;

  UPDATE public.dropship_checkout_reservations
  SET status = 'expired', updated_at = NOW()
  WHERE status = 'active' AND expires_at <= NOW();
  GET DIAGNOSTICS v_released = ROW_COUNT;
  RETURN v_released;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_dropship_checkout_reservation(
  p_items JSONB,
  p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_item JSONB;
  v_listing_id UUID;
  v_qty INTEGER;
  v_listing RECORD;
  v_stock RECORD;
  v_reservation_id UUID;
  v_hash TEXT;
  v_existing RECORD;
  v_total NUMERIC := 0;
  v_fee NUMERIC;
  v_cost NUMERIC;
  v_margin NUMERIC;
  v_expiry TIMESTAMPTZ := NOW() + INTERVAL '15 minutes';
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF p_idempotency_key IS NULL OR length(trim(p_idempotency_key)) NOT BETWEEN 16 AND 128 THEN
    RAISE EXCEPTION 'A 16-128 character idempotency key is required';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
     OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 20 THEN
    RAISE EXCEPTION 'Cart must contain 1 to 20 dropship listing entries';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_item) <> 'object'
       OR COALESCE(v_item->>'listing_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       OR COALESCE(v_item->>'quantity','') !~ '^[1-9][0-9]{0,2}$'
       OR (v_item->>'quantity')::INTEGER > 50 THEN
      RAISE EXCEPTION 'Each cart entry requires a valid listing_id and quantity 1-50';
    END IF;
  END LOOP;
  IF EXISTS (
    SELECT 1 FROM (
      SELECT value->>'listing_id' AS listing_id
      FROM jsonb_array_elements(p_items)
    ) q GROUP BY listing_id HAVING COUNT(*) > 1
  ) THEN RAISE EXCEPTION 'Duplicate listing IDs are not allowed'; END IF;

  v_hash := encode(digest(p_items::TEXT, 'sha256'), 'hex');
  PERFORM pg_advisory_xact_lock(hashtextextended('sarvex_dropship:' || v_uid::TEXT || ':' || trim(p_idempotency_key), 0));
  SELECT id, request_hash, status, expires_at
  INTO v_existing
  FROM public.dropship_checkout_reservations
  WHERE customer_id = v_uid AND idempotency_key = trim(p_idempotency_key);
  IF FOUND THEN
    IF v_existing.request_hash <> v_hash THEN
      RAISE EXCEPTION 'Idempotency key was already used with a different cart';
    END IF;
    RETURN jsonb_build_object(
      'reservation_id', v_existing.id,
      'status', v_existing.status,
      'expires_at', v_existing.expires_at,
      'replayed', TRUE,
      'payment_required', TRUE,
      'payment_verified', FALSE
    );
  END IF;

  -- Release timed-out holds before calculating availability.
  PERFORM public.release_expired_dropship_reservations();

  -- Lock every stock row in deterministic UUID order to prevent overselling
  -- and avoid deadlocks when multiple listings refer to the same stock item.
  PERFORM st.id
  FROM public.supplier_stock st
  JOIN public.supplier_offers so ON so.supplier_stock_id = st.id
  JOIN public.reseller_listings rl ON rl.supplier_offer_id = so.id
  JOIN (
    SELECT (value->>'listing_id')::UUID AS listing_id
    FROM jsonb_array_elements(p_items)
  ) requested ON requested.listing_id = rl.id
  ORDER BY st.id
  FOR UPDATE OF st;

  FOR v_item IN
    SELECT value FROM jsonb_array_elements(p_items)
    ORDER BY (value->>'listing_id')::UUID
  LOOP
    v_listing_id := (v_item->>'listing_id')::UUID;
    v_qty := (v_item->>'quantity')::INTEGER;

    SELECT rl.id AS listing_id, rl.reseller_shop_id, rl.retail_price_inr,
           rs.owner_id AS reseller_owner_id, rs.approval_status AS reseller_shop_status,
           rs.commission_rate, so.id AS offer_id, so.supplier_id,
           so.wholesale_price_inr, so.minimum_order_quantity,
           so.direct_to_customer_dispatch, so.offer_status,
           sp.approval_status AS supplier_status, supplier_shop.approval_status AS supplier_shop_status,
           st.id AS stock_id, st.available_quantity, st.reserved_quantity, st.active
    INTO v_listing
    FROM public.reseller_listings rl
    JOIN public.seller_shops rs ON rs.id = rl.reseller_shop_id
    JOIN public.supplier_offers so ON so.id = rl.supplier_offer_id
    JOIN public.supplier_profiles sp ON sp.id = so.supplier_id
    JOIN public.seller_shops supplier_shop ON supplier_shop.id = sp.seller_shop_id
    JOIN public.supplier_stock st ON st.id = so.supplier_stock_id AND st.supplier_id = sp.id
    WHERE rl.id = v_listing_id
    FOR UPDATE OF rl, so, st;

    IF NOT FOUND OR v_listing.listing_status <> 'active'
       OR v_listing.reseller_shop_status <> 'approved'
       OR v_listing.supplier_status <> 'approved'
       OR v_listing.supplier_shop_status <> 'approved'
       OR v_listing.offer_status <> 'active'
       OR NOT v_listing.direct_to_customer_dispatch
       OR NOT v_listing.active THEN
      RAISE EXCEPTION 'Dropship listing is unavailable or not approved';
    END IF;
    IF v_listing.reseller_owner_id = v_uid THEN
      RAISE EXCEPTION 'A reseller cannot purchase their own listing';
    END IF;
    IF v_qty < v_listing.minimum_order_quantity THEN
      RAISE EXCEPTION 'Quantity is below supplier minimum order quantity';
    END IF;
    IF v_qty > (v_listing.available_quantity - v_listing.reserved_quantity) THEN
      RAISE EXCEPTION 'Insufficient available supplier stock';
    END IF;

    v_fee := round((v_listing.retail_price_inr * v_qty) * (COALESCE(v_listing.commission_rate, 10.0) / 100.0), 2);
    v_cost := round(v_listing.wholesale_price_inr * v_qty, 2);
    v_margin := round((v_listing.retail_price_inr * v_qty) - v_cost - v_fee, 2);
    IF v_margin < 0 THEN
      RAISE EXCEPTION 'Retail price does not cover supplier cost and configured platform fee';
    END IF;
    v_total := v_total + (v_listing.retail_price_inr * v_qty);
  END LOOP;

  INSERT INTO public.dropship_checkout_reservations (
    customer_id, idempotency_key, request_hash, expires_at
  ) VALUES (v_uid, trim(p_idempotency_key), v_hash, v_expiry)
  RETURNING id INTO v_reservation_id;

  FOR v_item IN
    SELECT value FROM jsonb_array_elements(p_items)
    ORDER BY (value->>'listing_id')::UUID
  LOOP
    v_listing_id := (v_item->>'listing_id')::UUID;
    v_qty := (v_item->>'quantity')::INTEGER;

    SELECT rl.retail_price_inr, rs.commission_rate, so.wholesale_price_inr,
           st.id AS stock_id
    INTO v_listing
    FROM public.reseller_listings rl
    JOIN public.seller_shops rs ON rs.id = rl.reseller_shop_id
    JOIN public.supplier_offers so ON so.id = rl.supplier_offer_id
    JOIN public.supplier_stock st ON st.id = so.supplier_stock_id
    WHERE rl.id = v_listing_id;

    v_fee := round(v_listing.retail_price_inr * v_qty * (COALESCE(v_listing.commission_rate, 10.0) / 100.0), 2);
    v_cost := round(v_listing.wholesale_price_inr * v_qty, 2);
    v_margin := round(v_listing.retail_price_inr * v_qty - v_cost - v_fee, 2);

    INSERT INTO public.dropship_checkout_reservation_items (
      reservation_id, listing_id, supplier_stock_id, quantity,
      retail_unit_price_inr, supplier_unit_cost_inr, platform_fee_rate,
      platform_fee_amount_inr, supplier_payable_inr, reseller_margin_inr
    ) VALUES (
      v_reservation_id, v_listing_id, v_listing.stock_id, v_qty,
      v_listing.retail_price_inr, v_listing.wholesale_price_inr,
      COALESCE(v_listing.commission_rate, 10.0), v_fee, v_cost, v_margin
    );

    UPDATE public.supplier_stock
    SET reserved_quantity = reserved_quantity + v_qty, updated_at = NOW()
    WHERE id = v_listing.stock_id
      AND available_quantity - reserved_quantity >= v_qty;
    IF NOT FOUND THEN RAISE EXCEPTION 'Supplier stock changed during reservation'; END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'reservation_id', v_reservation_id,
    'status', 'active',
    'expires_at', v_expiry,
    'retail_total_inr', round(v_total, 2),
    'currency', 'INR',
    'payment_required', TRUE,
    'payment_verified', FALSE,
    'order_created', FALSE,
    'cod_available', FALSE
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_dropship_checkout_reservation(p_reservation_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_res RECORD;
  v_item RECORD;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO v_res
  FROM public.dropship_checkout_reservations
  WHERE id = p_reservation_id AND customer_id = v_uid
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Reservation not found'; END IF;
  IF v_res.status <> 'active' THEN RETURN FALSE; END IF;

  FOR v_item IN
    SELECT supplier_stock_id, SUM(quantity)::INTEGER AS qty
    FROM public.dropship_checkout_reservation_items
    WHERE reservation_id = p_reservation_id
    GROUP BY supplier_stock_id
    ORDER BY supplier_stock_id
  LOOP
    UPDATE public.supplier_stock
    SET reserved_quantity = reserved_quantity - v_item.qty, updated_at = NOW()
    WHERE id = v_item.supplier_stock_id AND reserved_quantity >= v_item.qty;
    IF NOT FOUND THEN RAISE EXCEPTION 'Reservation stock counter invariant failed'; END IF;
  END LOOP;

  UPDATE public.dropship_checkout_reservations
  SET status = 'released', updated_at = NOW()
  WHERE id = p_reservation_id AND status = 'active';
  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.release_expired_dropship_reservations() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_dropship_checkout_reservation(JSONB,TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_dropship_checkout_reservation(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.release_expired_dropship_reservations() TO service_role;
GRANT EXECUTE ON FUNCTION public.create_dropship_checkout_reservation(JSONB,TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_dropship_checkout_reservation(UUID) TO authenticated, service_role;

COMMENT ON TABLE public.dropship_checkout_reservations IS
  'Temporary customer checkout holds only. No order or payment is created; holds expire after 15 minutes.';
COMMENT ON TABLE public.dropship_checkout_reservation_items IS
  'Server-calculated retail, supplier cost, platform fee and reseller margin snapshots for temporary holds.';

COMMIT;
