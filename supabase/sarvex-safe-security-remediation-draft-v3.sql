-- SARVEX SAFE SECURITY REMEDIATION (REVISED DRAFT)
-- Prepared from read-only live inspection on 2026-11-20.
-- DO NOT RUN until a current restorable backup exists and app/API impact is reviewed.
-- This file has NOT been executed or tested against an isolated PostgreSQL instance.
-- Static review only; the two SECURITY DEFINER views remain intentional residual advisor findings.
-- No marketplace rows, users, products, orders, or storage objects are modified.

BEGIN;

-- 0. Preflight: stop if expected objects/signatures are missing.
DO $preflight$
BEGIN
  IF to_regclass('public.seller_shops') IS NULL
     OR to_regclass('public.sellers') IS NULL
     OR to_regclass('public.seller_order_items_view') IS NULL
     OR to_regclass('public.orders') IS NULL
     OR to_regclass('public.order_items') IS NULL THEN
    RAISE EXCEPTION 'SARVEX preflight failed: expected table/view missing';
  END IF;

  IF to_regprocedure('public.is_sarvex_admin()') IS NULL
     OR to_regprocedure('public.is_seller_shop_owner(uuid)') IS NULL
     OR to_regprocedure('public.is_approved_seller_shop(uuid)') IS NULL
     OR to_regprocedure('public.claim_sarvex_admin_seat()') IS NULL
     OR to_regprocedure('public.has_verified_purchase(uuid,uuid)') IS NULL
     OR to_regprocedure('public.order_has_seller_item(uuid)') IS NULL
     OR to_regprocedure('public.is_order_customer(uuid)') IS NULL
     OR to_regprocedure('public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)') IS NULL
     OR to_regprocedure('public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)') IS NULL
     OR to_regprocedure('public.vote_review_helpful(uuid)') IS NULL
     OR to_regprocedure('public.handle_new_sarvex_user()') IS NULL
     OR to_regprocedure('public.protect_customer_account_role()') IS NULL
     OR to_regprocedure('public.protect_seller_shop_status()') IS NULL
     OR to_regprocedure('public.protect_product_fields()') IS NULL
     OR to_regprocedure('public.protect_order_item_fields()') IS NULL
     OR to_regprocedure('public.protect_and_verify_review()') IS NULL
     OR to_regprocedure('public.sync_parent_order_status()') IS NULL
     OR to_regprocedure('public.sync_product_review_stats()') IS NULL
     OR to_regprocedure('public.sync_review_helpful_count()') IS NULL
     OR to_regprocedure('public.bootstrap_first_admin()') IS NULL THEN
    RAISE EXCEPTION 'SARVEX preflight failed: one or more expected function signatures are missing';
  END IF;
END
$preflight$;

-- 1. Restrict DEFAULT privileges for future objects created by postgres in public.
-- This does not change grants on existing tables/sequences/functions.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

-- 2. Preserve the public seller directory safely.
-- Live definition inspected: public.sellers exposes only:
-- id, owner_id (as user_id), shop_name, owner_name, city, state, pincode,
-- approval_status (as status), rating, created_at; and filters approved shops.
-- Keep this deliberately limited SECURITY DEFINER view so anonymous and
-- signed-in customers can browse the directory without direct table access.
-- security_barrier remains enabled.
-- IMPORTANT: this view may continue to appear in the advisor as a
-- security_definer_view warning. Do not "fix" it by making it invoker until
-- the app uses a separate anon client or a reviewed safe directory RPC.
ALTER VIEW public.sellers SET (security_barrier = true, security_invoker = false);
GRANT SELECT ON TABLE public.sellers TO anon, authenticated;

-- Remove the older broad public policy if the previous follow-up migration
-- was applied. It would otherwise let authenticated customers read approved
-- seller_shops rows, including private payout/KYC fields because authenticated
-- currently has table-level SELECT.
DROP POLICY IF EXISTS "Public can view approved seller shops"
  ON public.seller_shops;

-- The public directory is served only through the limited public.sellers view.
-- Revoke both table-level access and the column-level grants made by the older
-- follow-up migration. Include every live seller_shops column inspected.
REVOKE ALL ON TABLE public.seller_shops FROM PUBLIC, anon;
REVOKE SELECT (
  id, created_at, updated_at, owner_id, shop_name, approval_status, owner_name,
  phone, email, city, state, pincode, pickup_address, upi_id, bank_account,
  ifsc_code, commission_rate, rating
) ON TABLE public.seller_shops FROM PUBLIC, anon;

-- 3. Preserve the existing narrowly-projected seller order view.
-- Live definition inspected: it joins order_items/orders/seller_shops and
-- returns only item details plus delivery name/phone/address for the seller's
-- own approved shop; admins pass the explicit is_sarvex_admin() predicate.
-- Keep security_invoker=false so sellers can use this filtered projection
-- without granting them SELECT access to whole customer order rows.
-- Keep security_barrier=true and do NOT add a seller-wide SELECT policy on
-- public.orders: that would expose other columns through direct table queries.
-- The view is granted only to authenticated users (existing ACL also has
-- service_role); it is not granted to anon.
ALTER VIEW public.seller_order_items_view
  SET (security_barrier = true, security_invoker = false);
GRANT SELECT ON TABLE public.seller_order_items_view TO authenticated;
REVOKE ALL ON TABLE public.seller_order_items_view FROM anon;

-- 4. Restrict helper predicates to the roles that need them.
REVOKE ALL ON FUNCTION public.is_sarvex_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_sarvex_admin()
  TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_seller_shop_owner(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_seller_shop_owner(UUID)
  TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_approved_seller_shop(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_approved_seller_shop(UUID)
  TO anon, authenticated, service_role;

-- 5. Customer/order operations require an authenticated caller.
REVOKE ALL ON FUNCTION public.claim_sarvex_admin_seat()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_sarvex_admin_seat()
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.has_verified_purchase(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_verified_purchase(UUID, UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.order_has_seller_item(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.order_has_seller_item(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_order_customer(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_order_customer(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.place_sarvex_order(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB
) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.place_sarvex_order(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT
) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.vote_review_helpful(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vote_review_helpful(UUID)
  TO authenticated, service_role;

-- 6. Trigger-only functions must not be callable as PostgREST RPC endpoints.
-- Revoking EXECUTE does not remove or disable the triggers already attached.
REVOKE ALL ON FUNCTION public.handle_new_sarvex_user()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_customer_account_role()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_seller_shop_status()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_product_fields()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_order_item_fields()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_and_verify_review()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_parent_order_status()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_product_review_stats()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_review_helpful_count()
  FROM PUBLIC, anon, authenticated;

-- 7. First-admin bootstrap is backend/service-role only.
REVOKE ALL ON FUNCTION public.bootstrap_first_admin()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin()
  TO service_role;

COMMIT;

-- END OF REVISED DRAFT.
-- Required before any production run:
-- (1) obtain a real restorable database/Auth/Storage backup;
-- (2) test on an isolated PostgreSQL version matching production;
-- (3) test customer directory, seller portal, order tracking, checkout, admin;
-- (4) inspect remaining Security Advisor warnings; sellers and seller_order_items_view
--     remain SECURITY DEFINER views by design until a safer API-compatible replacement exists;
-- (5) enable Leaked Password Protection separately in Auth settings.
