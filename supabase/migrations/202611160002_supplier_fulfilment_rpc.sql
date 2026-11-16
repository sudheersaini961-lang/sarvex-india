-- Supplier-owned order acceptance and manual dispatch milestones.
-- This migration does not create orders, allocate stock, collect payments, or
-- integrate a courier. Allocations can only be created by a future trusted
-- checkout path; this RPC only manages already-existing private allocations.

CREATE OR REPLACE FUNCTION public.get_my_supplier_fulfilments()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rows JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'allocation_id', a.id,
        'order_item_id', oi.id,
        'order_code', o.order_code,
        'product_name', oi.product_name,
        'quantity', a.quantity,
        'fulfilment_mode', a.fulfilment_mode,
        'allocation_status', a.allocation_status,
        'city', CASE
          WHEN a.allocation_status IN ('accepted', 'dispatch_pending', 'shipped')
          THEN o.city ELSE NULL END,
        'state', CASE
          WHEN a.allocation_status IN ('accepted', 'dispatch_pending', 'shipped')
          THEN o.state ELSE NULL END,
        'pincode', CASE
          WHEN a.allocation_status IN ('accepted', 'dispatch_pending', 'shipped')
          THEN o.pincode ELSE NULL END,
        'customer_name', CASE
          WHEN a.allocation_status IN ('accepted', 'dispatch_pending', 'shipped')
          THEN o.customer_name ELSE NULL END,
        'customer_phone', CASE
          WHEN a.allocation_status IN ('accepted', 'dispatch_pending', 'shipped')
          THEN o.customer_phone ELSE NULL END,
        'shipping_address', CASE
          WHEN a.allocation_status IN ('accepted', 'dispatch_pending', 'shipped')
          THEN o.shipping_address ELSE NULL END,
        'created_at', a.created_at,
        'updated_at', a.updated_at,
        'latest_fulfilment_event', (
          SELECT jsonb_build_object(
            'event_type', e.event_type,
            'courier_provider', e.courier_provider,
            'tracking_reference', e.tracking_reference,
            'event_note', e.event_note,
            'occurred_at', e.occurred_at
          )
          FROM public.supplier_fulfilment_events e
          WHERE e.allocation_id = a.id
          ORDER BY e.occurred_at DESC, e.created_at DESC
          LIMIT 1
        )
      ) ORDER BY a.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM public.supplier_order_allocations a
  JOIN public.supplier_profiles sp ON sp.id = a.supplier_id
  JOIN public.seller_shops ss ON ss.id = sp.seller_shop_id
  JOIN public.order_items oi ON oi.id = a.order_item_id
  JOIN public.orders o ON o.id = oi.order_id
  WHERE ss.owner_id = v_uid
    AND ss.approval_status = 'approved';

  RETURN v_rows;
END;
$$;

CREATE OR REPLACE FUNCTION public.supplier_update_fulfilment(
  p_allocation_id UUID,
  p_action TEXT,
  p_courier_provider TEXT DEFAULT NULL,
  p_tracking_reference TEXT DEFAULT NULL,
  p_event_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_allocation public.supplier_order_allocations%ROWTYPE;
  v_supplier_status TEXT;
  v_shop_status TEXT;
  v_next_status TEXT;
  v_event_type TEXT;
  v_provider TEXT := NULLIF(trim(COALESCE(p_courier_provider, '')), '');
  v_tracking TEXT := NULLIF(trim(COALESCE(p_tracking_reference, '')), '');
  v_note TEXT := NULLIF(trim(COALESCE(p_event_note, '')), '');
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_allocation_id IS NULL OR p_action IS NULL OR p_action NOT IN ('accept', 'reject', 'packed', 'shipped') THEN
    RAISE EXCEPTION 'Invalid fulfilment action';
  END IF;
  IF v_note IS NOT NULL AND length(v_note) > 500 THEN
    RAISE EXCEPTION 'Fulfilment note is too long';
  END IF;

  SELECT a.*
  INTO v_allocation
  FROM public.supplier_order_allocations a
  JOIN public.supplier_profiles sp ON sp.id = a.supplier_id
  JOIN public.seller_shops ss ON ss.id = sp.seller_shop_id
  WHERE a.id = p_allocation_id
    AND ss.owner_id = v_uid
  FOR UPDATE OF a;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Supplier allocation not found';
  END IF;

  SELECT sp.approval_status, ss.approval_status
  INTO v_supplier_status, v_shop_status
  FROM public.supplier_profiles sp
  JOIN public.seller_shops ss ON ss.id = sp.seller_shop_id
  WHERE sp.id = v_allocation.supplier_id AND ss.owner_id = v_uid;
  IF v_shop_status <> 'approved' THEN
    RAISE EXCEPTION 'Approved seller shop required';
  END IF;

  IF p_action IN ('accept', 'reject') THEN
    IF v_allocation.allocation_status <> 'awaiting_supplier'
       OR v_supplier_status <> 'approved' THEN
      RAISE EXCEPTION 'Only an approved supplier can accept or reject a pending allocation';
    END IF;
    IF p_action = 'accept' THEN
      v_next_status := 'accepted';
      v_event_type := 'supplier_accepted';
    ELSE
      v_next_status := 'rejected';
      v_event_type := 'supplier_rejected';
    END IF;
  ELSIF p_action = 'packed' THEN
    IF v_allocation.allocation_status <> 'accepted'
       OR v_supplier_status NOT IN ('approved', 'suspended') THEN
      RAISE EXCEPTION 'Only an accepted allocation can be marked packed';
    END IF;
    v_next_status := 'dispatch_pending';
    v_event_type := 'packed';
  ELSE
    IF v_allocation.allocation_status NOT IN ('accepted', 'dispatch_pending')
       OR v_supplier_status NOT IN ('approved', 'suspended') THEN
      RAISE EXCEPTION 'Only an accepted or packed allocation can be marked shipped';
    END IF;
    IF v_provider IS NULL OR length(v_provider) NOT BETWEEN 2 AND 80
       OR v_tracking IS NULL OR length(v_tracking) NOT BETWEEN 3 AND 120 THEN
      RAISE EXCEPTION 'Supplier-entered courier name and tracking reference are required';
    END IF;
    v_next_status := 'shipped';
    v_event_type := 'shipped';
  END IF;

  UPDATE public.supplier_order_allocations
  SET allocation_status = v_next_status,
      updated_at = NOW()
  WHERE id = p_allocation_id;

  INSERT INTO public.supplier_fulfilment_events (
    allocation_id, event_type, courier_provider, tracking_reference,
    event_note, event_payload, recorded_by, occurred_at
  ) VALUES (
    p_allocation_id, v_event_type,
    CASE WHEN p_action = 'shipped' THEN v_provider ELSE NULL END,
    CASE WHEN p_action = 'shipped' THEN v_tracking ELSE NULL END,
    v_note, '{}'::jsonb, v_uid, NOW()
  );

  RETURN jsonb_build_object(
    'allocation_id', p_allocation_id,
    'allocation_status', v_next_status,
    'event_type', v_event_type,
    'tracking_reference', CASE WHEN p_action = 'shipped' THEN v_tracking ELSE NULL END,
    'tracking_verification', CASE
      WHEN p_action = 'shipped' THEN 'supplier_reported_not_courier_verified'
      ELSE NULL END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_supplier_fulfilments() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.supplier_update_fulfilment(UUID,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_supplier_fulfilments() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.supplier_update_fulfilment(UUID,TEXT,TEXT,TEXT,TEXT) TO authenticated, service_role;
