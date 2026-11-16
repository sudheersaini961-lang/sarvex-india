-- Incremental, idempotent public reseller catalogue RPC.
-- Exposes approved retail fields only; no supplier or wholesale information.
BEGIN;

CREATE OR REPLACE FUNCTION public.browse_public_reseller_catalogue()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'listing_id', rl.id,
        'title', COALESCE(NULLIF(trim(rl.public_title), ''), st.product_name),
        'description', COALESCE(rl.public_description, st.description),
        'image_url', COALESCE(rl.public_image_url, st.image_url),
        'category', st.category,
        'retail_price_inr', rl.retail_price_inr,
        'currency', 'INR',
        'available_quantity', st.available_quantity,
        'minimum_order_quantity', so.minimum_order_quantity,
        'seller_name', rs.shop_name
      ) ORDER BY rl.created_at DESC
    ),
    '[]'::jsonb
  )
  FROM public.reseller_listings rl
  JOIN public.seller_shops rs ON rs.id = rl.reseller_shop_id
  JOIN public.supplier_offers so ON so.id = rl.supplier_offer_id
  JOIN public.supplier_profiles sp ON sp.id = so.supplier_id
  JOIN public.seller_shops supplier_shop ON supplier_shop.id = sp.seller_shop_id
  JOIN public.supplier_stock st
    ON st.id = so.supplier_stock_id AND st.supplier_id = sp.id
  WHERE rl.listing_status = 'active'
    AND rs.approval_status = 'approved'
    AND so.offer_status = 'active'
    AND so.direct_to_customer_dispatch = true
    AND sp.approval_status = 'approved'
    AND supplier_shop.approval_status = 'approved'
    AND st.active = true
    AND st.available_quantity >= so.minimum_order_quantity;
$$;

REVOKE ALL ON FUNCTION public.browse_public_reseller_catalogue() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.browse_public_reseller_catalogue() TO anon, authenticated, service_role;

COMMIT;
