-- Trusted payment-webhook recording boundary for dropship reservations.
-- This does NOT verify provider signatures, capture funds, create orders, or issue refunds.
-- A server-side integration may call this only AFTER verifying the provider webhook signature.
BEGIN;

ALTER TABLE public.dropship_checkout_reservations
  DROP CONSTRAINT IF EXISTS dropship_checkout_reservations_status_check;
ALTER TABLE public.dropship_checkout_reservations
  ADD CONSTRAINT dropship_checkout_reservations_status_check
  CHECK (status IN ('active', 'released', 'expired', 'converted', 'payment_verified', 'payment_review'));

CREATE TABLE IF NOT EXISTS public.dropship_payment_confirmations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES public.dropship_checkout_reservations(id) ON DELETE RESTRICT,
  provider TEXT NOT NULL CHECK (provider ~ '^[a-z0-9][a-z0-9_-]{1,39}$'),
  provider_order_id TEXT NOT NULL CHECK (length(provider_order_id) BETWEEN 1 AND 200),
  provider_payment_id TEXT NOT NULL CHECK (length(provider_payment_id) BETWEEN 1 AND 200),
  amount_inr NUMERIC(12,2) NOT NULL CHECK (amount_inr > 0 AND amount_inr = round(amount_inr, 2)),
  currency TEXT NOT NULL CHECK (currency = 'INR'),
  expected_amount_inr NUMERIC(12,2) NOT NULL CHECK (expected_amount_inr > 0),
  status TEXT NOT NULL CHECK (status IN ('verified_pending_order', 'review_required')),
  signature_verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (provider, provider_payment_id)
);

CREATE INDEX IF NOT EXISTS dropship_payment_confirmations_reservation_idx
  ON public.dropship_payment_confirmations (reservation_id, received_at DESC);

ALTER TABLE public.dropship_payment_confirmations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.dropship_payment_confirmations FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.dropship_payment_confirmations TO service_role;

CREATE OR REPLACE FUNCTION public.record_verified_dropship_payment(
  p_reservation_id UUID,
  p_provider TEXT,
  p_provider_order_id TEXT,
  p_provider_payment_id TEXT,
  p_amount_inr NUMERIC,
  p_currency TEXT DEFAULT 'INR'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_role TEXT;
  v_reservation public.dropship_checkout_reservations%ROWTYPE;
  v_existing public.dropship_payment_confirmations%ROWTYPE;
  v_expected NUMERIC(12,2);
  v_status TEXT;
  v_event_id UUID;
  v_prior_success BOOLEAN := FALSE;
BEGIN
  v_role := COALESCE(
    NULLIF(current_setting('request.jwt.claim.role', true), ''),
    NULLIF(NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role', '')
  );
  IF v_role IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Only the trusted payment webhook service may record verified payments'
      USING ERRCODE = '42501';
  END IF;

  IF p_reservation_id IS NULL
     OR lower(trim(COALESCE(p_provider, ''))) !~ '^[a-z0-9][a-z0-9_-]{1,39}$'
     OR length(trim(COALESCE(p_provider_order_id, ''))) NOT BETWEEN 1 AND 200
     OR length(trim(COALESCE(p_provider_payment_id, ''))) NOT BETWEEN 1 AND 200
     OR p_amount_inr IS NULL OR p_amount_inr <= 0
     OR p_amount_inr <> round(p_amount_inr, 2)
     OR upper(trim(COALESCE(p_currency, ''))) <> 'INR' THEN
    RAISE EXCEPTION 'Invalid verified payment event payload';
  END IF;

  -- Serialize payment events for a reservation before checking state/amount.
  SELECT * INTO v_reservation
  FROM public.dropship_checkout_reservations
  WHERE id = p_reservation_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dropship reservation not found'; END IF;

  -- Provider payment IDs are globally idempotent within a provider.
  SELECT * INTO v_existing
  FROM public.dropship_payment_confirmations
  WHERE provider = lower(trim(p_provider))
    AND provider_payment_id = trim(p_provider_payment_id)
  FOR UPDATE;
  IF FOUND THEN
    IF v_existing.reservation_id <> p_reservation_id
       OR v_existing.provider_order_id <> trim(p_provider_order_id)
       OR v_existing.amount_inr <> p_amount_inr
       OR v_existing.currency <> upper(trim(p_currency)) THEN
      RAISE EXCEPTION 'Provider payment ID was replayed with conflicting payment details'
        USING ERRCODE = '23505';
    END IF;
    RETURN jsonb_build_object(
      'payment_event_id', v_existing.id,
      'status', v_existing.status,
      'expected_amount_inr', v_existing.expected_amount_inr,
      'received_amount_inr', v_existing.amount_inr,
      'order_created', FALSE,
      'replayed', TRUE
    );
  END IF;

  SELECT round(COALESCE(SUM(ri.retail_unit_price_inr * ri.quantity), 0), 2)
  INTO v_expected
  FROM public.dropship_checkout_reservation_items ri
  WHERE ri.reservation_id = p_reservation_id;
  IF v_expected <= 0 THEN RAISE EXCEPTION 'Reservation has no payable items'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.dropship_payment_confirmations pc
    WHERE pc.reservation_id = p_reservation_id
      AND pc.status = 'verified_pending_order'
  ) INTO v_prior_success;

  IF v_reservation.status = 'active'
     AND v_reservation.expires_at > NOW()
     AND upper(trim(p_currency)) = 'INR'
     AND p_amount_inr = v_expected
     AND NOT v_prior_success THEN
    v_status := 'verified_pending_order';
    UPDATE public.dropship_checkout_reservations
    SET status = 'payment_verified', updated_at = NOW()
    WHERE id = p_reservation_id AND status = 'active';
  ELSE
    v_status := 'review_required';
    UPDATE public.dropship_checkout_reservations
    SET status = 'payment_review', updated_at = NOW()
    WHERE id = p_reservation_id
      AND status IN ('active', 'payment_verified', 'payment_review');
  END IF;

  INSERT INTO public.dropship_payment_confirmations (
    reservation_id, provider, provider_order_id, provider_payment_id,
    amount_inr, currency, expected_amount_inr, status, signature_verified_at
  ) VALUES (
    p_reservation_id, lower(trim(p_provider)), trim(p_provider_order_id),
    trim(p_provider_payment_id), p_amount_inr, upper(trim(p_currency)),
    v_expected, v_status, NOW()
  ) RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'payment_event_id', v_event_id,
    'status', v_status,
    'expected_amount_inr', v_expected,
    'received_amount_inr', p_amount_inr,
    'order_created', FALSE,
    'replayed', FALSE
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_verified_dropship_payment(UUID,TEXT,TEXT,TEXT,NUMERIC,TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_verified_dropship_payment(UUID,TEXT,TEXT,TEXT,NUMERIC,TEXT)
  TO service_role;

COMMENT ON TABLE public.dropship_payment_confirmations IS
  'Server-recorded payment webhook confirmations. Caller must verify provider signature first; this ledger does not create orders or issue refunds.';
COMMENT ON FUNCTION public.record_verified_dropship_payment(UUID,TEXT,TEXT,TEXT,NUMERIC,TEXT) IS
  'Service-role-only boundary. Invoke only after cryptographic provider webhook verification. Amount/state mismatches are held for manual review; no order is created.';

COMMIT;
