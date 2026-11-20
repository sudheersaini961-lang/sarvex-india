-- SARVEX database performance tuning v1.
-- Safe, additive/index-only plus policy-expression optimization.
-- Tested in isolated PostgreSQL 15/16/17 before any production deployment.
-- Never apply to production without a verified restorable backup and maintenance plan.

BEGIN;

DO $preflight$
BEGIN
  IF to_regclass('public.cart_items') IS NULL
     OR to_regclass('public.customer_profiles') IS NULL
     OR to_regclass('public.seller_shops') IS NULL
     OR to_regclass('public.order_idempotency_keys') IS NULL
     OR to_regclass('public.order_items') IS NULL
     OR to_regclass('public.orders') IS NULL
     OR to_regclass('public.reviews') IS NULL
     OR to_regclass('public.review_helpful_votes') IS NULL
     OR to_regclass('public.wishlist_items') IS NULL
     OR to_regclass('public.categories') IS NULL
     OR to_regclass('public.sarvex_admin_allowlist') IS NULL THEN
    RAISE EXCEPTION 'SARVEX performance tuning preflight failed: expected table missing';
  END IF;
END
$preflight$;

-- Wrap request-stable auth/helper calls in scalar subqueries so PostgreSQL
-- can evaluate them once per statement instead of once per candidate row.
ALTER POLICY "Users can delete their own cart items" ON public.cart_items
  USING ((SELECT auth.uid()) = owner_id);
ALTER POLICY "Users can insert into their own cart" ON public.cart_items
  WITH CHECK ((SELECT auth.uid()) = owner_id);
ALTER POLICY "Users can update their own cart items" ON public.cart_items
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);
ALTER POLICY "Users can view only their own cart items" ON public.cart_items
  USING ((SELECT auth.uid()) = owner_id);

ALTER POLICY "Users can create their own profile" ON public.customer_profiles
  WITH CHECK (
    (SELECT auth.uid()) = owner_id
    AND (
      account_role IS NULL
      OR account_role = 'customer'
      OR (SELECT public.is_sarvex_admin())
    )
  );
ALTER POLICY "Users can update their own profile details" ON public.customer_profiles
  USING ((SELECT auth.uid()) = owner_id OR (SELECT public.is_sarvex_admin()))
  WITH CHECK ((SELECT auth.uid()) = owner_id OR (SELECT public.is_sarvex_admin()));
ALTER POLICY "Users view own profile or admin" ON public.customer_profiles
  USING ((SELECT auth.uid()) = owner_id OR (SELECT public.is_sarvex_admin()));

ALTER POLICY "Authenticated users can register a shop" ON public.seller_shops
  WITH CHECK (approval_status = 'pending' AND (SELECT auth.uid()) = owner_id);
ALTER POLICY "Sellers and Admins view seller shops" ON public.seller_shops
  USING (
    ((SELECT auth.uid()) IS NOT NULL AND owner_id = (SELECT auth.uid()))
    OR (SELECT public.is_sarvex_admin())
  );
ALTER POLICY "Sellers can update their own shop details" ON public.seller_shops
  USING (owner_id = (SELECT auth.uid()) OR (SELECT public.is_sarvex_admin()))
  WITH CHECK (owner_id = (SELECT auth.uid()) OR (SELECT public.is_sarvex_admin()));

ALTER POLICY "Users view own idempotency keys" ON public.order_idempotency_keys
  USING (customer_id = (SELECT auth.uid()) OR (SELECT public.is_sarvex_admin()));

ALTER POLICY "Customers and Admins view relevant orders" ON public.orders
  USING (
    ((SELECT auth.uid()) IS NOT NULL AND customer_id = (SELECT auth.uid()))
    OR (SELECT public.is_sarvex_admin())
  );

ALTER POLICY "View order items" ON public.order_items
  USING (
    ((SELECT auth.uid()) IS NOT NULL AND is_order_customer(order_id))
    OR is_seller_shop_owner(seller_shop_id)
    OR (SELECT public.is_sarvex_admin())
  );

ALTER POLICY "Customers can delete their own reviews" ON public.reviews
  USING (customer_id = (SELECT auth.uid()) OR (SELECT public.is_sarvex_admin()));
ALTER POLICY "Customers can update their own reviews" ON public.reviews
  USING (customer_id = (SELECT auth.uid()) OR (SELECT public.is_sarvex_admin()))
  WITH CHECK (customer_id = (SELECT auth.uid()) OR (SELECT public.is_sarvex_admin()));
ALTER POLICY "Verified buyers can submit reviews" ON public.reviews
  WITH CHECK (
    (SELECT auth.uid()) IS NOT NULL
    AND customer_id = (SELECT auth.uid())
  );

ALTER POLICY "Users view own review votes" ON public.review_helpful_votes
  USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_sarvex_admin()));

ALTER POLICY "Users can manage their own wishlist" ON public.wishlist_items
  USING (owner_id = (SELECT auth.uid()))
  WITH CHECK (owner_id = (SELECT auth.uid()));

-- Avoid two permissive SELECT policies for the same role/action.
-- Public category reads remain unchanged; admin writes are split by command.
DROP POLICY "Admins manage categories" ON public.categories;
CREATE POLICY "Admins insert categories" ON public.categories
  FOR INSERT TO public
  WITH CHECK ((SELECT public.is_sarvex_admin()));
CREATE POLICY "Admins update categories" ON public.categories
  FOR UPDATE TO public
  USING ((SELECT public.is_sarvex_admin()))
  WITH CHECK ((SELECT public.is_sarvex_admin()));
CREATE POLICY "Admins delete categories" ON public.categories
  FOR DELETE TO public
  USING ((SELECT public.is_sarvex_admin()));

-- The ALL policy already includes SELECT; remove the identical redundant SELECT policy.
DROP POLICY "Only admins view admin allowlist" ON public.sarvex_admin_allowlist;
ALTER POLICY "Only admins manage admin allowlist" ON public.sarvex_admin_allowlist
  USING ((SELECT public.is_sarvex_admin()))
  WITH CHECK ((SELECT public.is_sarvex_admin()));

-- Cover foreign-key lookups/cascades identified by the live Performance Advisor.
CREATE INDEX IF NOT EXISTS idx_order_idempotency_keys_order_id
  ON public.order_idempotency_keys (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id
  ON public.order_items (product_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_items_product_id
  ON public.wishlist_items (product_id);

-- Remove only byte-for-byte duplicate non-constraint indexes; retain the idx_* names.
DROP INDEX IF EXISTS public.cart_items_owner_id_idx;
DROP INDEX IF EXISTS public.products_category_idx;
DROP INDEX IF EXISTS public.products_seller_shop_id_idx;

COMMIT;
