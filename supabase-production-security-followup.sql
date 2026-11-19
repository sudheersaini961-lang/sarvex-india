-- SARVEX additive production security follow-up.
-- Apply only after confirming a current Supabase backup. This script is idempotent
-- and does not delete or rewrite marketplace rows.
BEGIN;

-- Close future-object defaults for the postgres owner used by this migration.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

-- Views must execute with caller privileges so underlying RLS is enforced.
ALTER VIEW public.sellers SET (security_barrier = true, security_invoker = true);
ALTER VIEW public.seller_order_items_view SET (security_barrier = true, security_invoker = true);

-- Public seller directory: expose only non-sensitive columns to anonymous visitors.
-- Never grant anon SELECT on the entire seller_shops row (bank/UPI/KYC fields).
REVOKE SELECT ON TABLE public.seller_shops FROM anon;
GRANT SELECT (id, owner_id, shop_name, owner_name, city, state, pincode,
              approval_status, rating, created_at)
  ON TABLE public.seller_shops TO anon;
DROP POLICY IF EXISTS "Public can view approved seller shops" ON public.seller_shops;
CREATE POLICY "Public can view approved seller shops"
  ON public.seller_shops FOR SELECT TO anon
  USING (approval_status = 'approved');
GRANT SELECT ON TABLE public.sellers TO anon, authenticated;

-- The seller-order predicate must require an approved shop, not just ownership.
CREATE OR REPLACE FUNCTION public.order_has_seller_item(check_order_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $
  SELECT EXISTS (
    SELECT 1
    FROM public.order_items oi
    JOIN public.seller_shops s ON s.id = oi.seller_shop_id
    WHERE oi.order_id = check_order_id
      AND s.owner_id = auth.uid()
      AND s.approval_status = 'approved'
      AND auth.uid() IS NOT NULL
  );
$;
REVOKE ALL ON FUNCTION public.order_has_seller_item(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.order_has_seller_item(UUID) TO authenticated, service_role;

-- A security-invoker seller order view needs an explicit RLS path for sellers.
-- The helper checks approved-shop ownership of at least one item in the order.
DROP POLICY IF EXISTS "Sellers can view orders for their own items" ON public.orders;
CREATE POLICY "Sellers can view orders for their own items"
  ON public.orders FOR SELECT TO authenticated
  USING (public.order_has_seller_item(id));
GRANT SELECT ON TABLE public.seller_order_items_view TO authenticated;

-- Three narrowly scoped, read-only predicates remain callable by anon for
-- public catalogue RLS policies. Their implementations fail closed for anon.
REVOKE ALL ON FUNCTION public.is_sarvex_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_sarvex_admin() TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_seller_shop_owner(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_seller_shop_owner(UUID) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_approved_seller_shop(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_approved_seller_shop(UUID) TO anon, authenticated, service_role;

-- Customer/order predicates and checkout are authenticated-only.
REVOKE ALL ON FUNCTION public.claim_sarvex_admin_seat() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_sarvex_admin_seat() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.has_verified_purchase(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_verified_purchase(UUID, UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.order_has_seller_item(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.order_has_seller_item(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_order_customer(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_order_customer(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.vote_review_helpful(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vote_review_helpful(UUID) TO authenticated, service_role;

-- Trigger-only functions must never be exposed as PostgREST RPC endpoints.
REVOKE ALL ON FUNCTION public.handle_new_sarvex_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_customer_account_role() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_seller_shop_status() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_product_fields() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_order_item_fields() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_and_verify_review() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_parent_order_status() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_product_review_stats() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_review_helpful_count() FROM PUBLIC, anon, authenticated;

-- Bootstrap is a service-role-only operation.
REVOKE ALL ON FUNCTION public.bootstrap_first_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin() TO service_role;

COMMIT;
