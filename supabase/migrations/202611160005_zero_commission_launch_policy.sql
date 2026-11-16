-- SARVEX launch pricing policy: 0% seller/platform commission.
-- Existing seller rates are reset to the explicitly approved launch rate.
-- Historical order_items commission snapshots are not rewritten.
BEGIN;

ALTER TABLE public.seller_shops
  ALTER COLUMN commission_rate SET DEFAULT 0.00;

UPDATE public.seller_shops
SET commission_rate = 0.00
WHERE commission_rate IS DISTINCT FROM 0.00;

ALTER TABLE public.seller_shops
  ALTER COLUMN commission_rate SET NOT NULL;

ALTER TABLE public.seller_shops
  DROP CONSTRAINT IF EXISTS seller_shops_launch_zero_commission_check;

ALTER TABLE public.seller_shops
  ADD CONSTRAINT seller_shops_launch_zero_commission_check
  CHECK (commission_rate = 0.00);

ALTER TABLE public.order_items
  ALTER COLUMN commission_rate SET DEFAULT 0.00;

CREATE OR REPLACE FUNCTION public.protect_seller_shop_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT public.is_sarvex_admin() THEN
    IF TG_OP = 'INSERT' THEN
      NEW.approval_status := 'pending';
      NEW.commission_rate := 0.00;
      NEW.rating := 0.0;
      NEW.owner_id := auth.uid();
      IF NEW.owner_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to register a seller store.'
          USING ERRCODE = '42501';
      END IF;
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
        RAISE EXCEPTION 'Security Exception: Only SARVEX administrators can alter shop approval_status.'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
        RAISE EXCEPTION 'Security Exception: Shop ownership transfer is restricted to administrators.'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.commission_rate IS DISTINCT FROM OLD.commission_rate THEN
        RAISE EXCEPTION 'Security Exception: Sellers cannot modify their platform commission rate.'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.rating IS DISTINCT FROM OLD.rating THEN
        RAISE EXCEPTION 'Security Exception: Sellers cannot alter shop rating.'
          USING ERRCODE = '42501';
      END IF;
      IF OLD.approval_status = 'approved' AND (
        NEW.bank_account IS DISTINCT FROM OLD.bank_account OR
        NEW.ifsc_code IS DISTINCT FROM OLD.ifsc_code OR
        NEW.upi_id IS DISTINCT FROM OLD.upi_id
      ) THEN
        RAISE EXCEPTION 'Security Exception: Modifying verified banking payout details requires administrator KYC approval.'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON CONSTRAINT seller_shops_launch_zero_commission_check ON public.seller_shops IS
  'Launch policy: SARVEX seller/platform commission is 0%; change only through an explicitly approved policy migration.';

COMMIT;
