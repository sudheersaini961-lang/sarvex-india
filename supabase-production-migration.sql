-- ============================================================================
-- SARVEX INDIA: HARDENED PRODUCTION SUPABASE MIGRATION & SECURITY HARBOR (V4)
-- Fully Idempotent script: Safe to execute repeatedly on existing databases.
-- Preserves existing tables & data: customer_profiles, seller_shops, products, cart_items
-- ============================================================================

BEGIN;

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 2. EXACT CATALOG-DEFINITION VERIFICATION: HARDENED POLICY HARBOR (SEC-02)
-- Verifies exact catalog attributes: schemaname, tablename, policyname, cmd,
-- roles, permissive status, qual (USING), and with_check expressions.
-- Unknown or mismatched PERMISSIVE policies (including generic legacy templates)
-- will immediately abort migration with error 42501 to prevent RLS bypass.
-- RESTRICTIVE policies are preserved unconditionally.
-- ============================================================================
DO $$
DECLARE
  pol RECORD;
  v_is_approved boolean;
BEGIN
  -- Temporary table defining exact specifications for all approved managed SARVEX policies
  CREATE TEMP TABLE IF NOT EXISTS sarvex_approved_policy_specs (
    schemaname text NOT NULL,
    tablename text NOT NULL,
    policyname text NOT NULL,
    cmd text NOT NULL,
    target_role text NOT NULL,
    permissive text NOT NULL DEFAULT 'PERMISSIVE',
    qual_pattern text,
    with_check_pattern text
  ) ON COMMIT DROP;

  TRUNCATE sarvex_approved_policy_specs;

  INSERT INTO sarvex_approved_policy_specs
    (schemaname, tablename, policyname, cmd, target_role, permissive, qual_pattern, with_check_pattern)
  VALUES
    -- customer_profiles
    ('public', 'customer_profiles', 'Users view own profile or admin', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$', NULL),
    ('public', 'customer_profiles', 'Users can create their own profile', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?\s*and\s*\(?\(?account_role\s+is\s+null\)?\s*or\s*\(?account_role\s*=\s*''customer''(::text)?\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?\)?\)?[\s\(\)]*$'),
    ('public', 'customer_profiles', 'Users can update their own profile details', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$'),

    -- seller_shops
    ('public', 'seller_shops', 'Sellers and Admins view seller shops', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*(auth\.)?uid\(\)\s+is\s+not\s+null[\s\(\)]*and[\s\(\)]*owner_id\s*=\s*(auth\.)?uid\(\)[\s\(\)]*or[\s\(\)]*(public\.)?is_sarvex_admin\(\)[\s\(\)]*$', NULL),
    ('public', 'seller_shops', 'Authenticated users can register a shop', 'INSERT', 'public', 'PERMISSIVE',
      NULL, '^[\s\(\)]*\(?\(?approval_status\s*=\s*''pending''(::text)?\)?\s*and\s*\(?\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?\)?\)?[\s\(\)]*$'),
    ('public', 'seller_shops', 'Sellers can update their own shop details', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?owner_id\s*=\s*(auth\.)?uid\(\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?owner_id\s*=\s*(auth\.)?uid\(\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$'),
    ('public', 'seller_shops', 'Public can view approved seller shops', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?approval_status\s*=\s*''approved''(::text)?\)?[\s\(\)]*$', NULL),

    -- products
    ('public', 'products', 'Public can view products from approved shops', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(\(?(public\.)?is_approved_seller_shop\(\s*seller_shop_id\s*\)\)?|EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+(public\.)?seller_shops\s+[a-z_]*\s*WHERE\s+[a-z_.]*id\s*=\s*(products\.)?seller_shop_id\s*AND\s+[a-z_.]*approval_status\s*=\s*''approved''(::text)?\s*\))\s*or\s*\(?(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$', NULL),
    ('public', 'products', 'Sellers can add products to their own shop', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?\(?(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$'),
    ('public', 'products', 'Sellers can update products in their own shop', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$'),
    ('public', 'products', 'Sellers can delete products from their own shop', 'DELETE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$', NULL),

    -- cart_items
    ('public', 'cart_items', 'Users can view only their own cart items', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?[\s\(\)]*$', NULL),
    ('public', 'cart_items', 'Users can insert into their own cart', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?[\s\(\)]*$'),
    ('public', 'cart_items', 'Users can update their own cart items', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?[\s\(\)]*$'),
    ('public', 'cart_items', 'Users can delete their own cart items', 'DELETE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?[\s\(\)]*$', NULL),

    -- orders
    ('public', 'orders', 'Customers and Admins view relevant orders', 'SELECT', 'public', 'PERMISSIVE',
      '^[\\s\\(\\)]*\\(*\\s*(auth\\.)?uid\\(\\)\\s+is\\s+not\\s+null\\s*\\)*\\s+and\\s+\\(*\\s*customer_id\\s*=\\s*(auth\\.)?uid\\(\\)\\s*\\)*\\s*\\)*\\s+or\\s+\\(*\\s*(public\\.)?order_has_seller_item\\(\\s*id\\s*\\)\\s*\\)*\\s+or\\s+\\(*\\s*(public\\.)?is_sarvex_admin\\(\\)\\s*\\)*\\s*\\)*[\\s\\(\\)]*$', NULL),
    ('public', 'orders', 'Customers and Sellers view relevant orders', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?\(?(auth\.)?uid\(\)\s+is\s+not\s+null\s*and\s*\(?customer_id\s*=\s*(auth\.)?uid\(\)\)?\)?\s*or\s*\(?(public\.)?is_seller_shop_owner\(.*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$', NULL),
    ('public', 'orders', 'Only admins or trusted procedures create orders', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$'),
    ('public', 'orders', 'Customers insert their own orders', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*customer_id\)?[\s\(\)]*$'),
    ('public', 'orders', 'Only Admins can update global order status', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$'),

    -- order_items
    ('public', 'order_items', 'View order items', 'SELECT', 'public', 'PERMISSIVE',
      '^[\s\(\)]*(auth\.)?uid\(\)[\s\(\)]*is[\s\(\)]*not[\s\(\)]*null[\s\(\)]*and[\s\(\)]*(public\.)?is_order_customer\(\s*order_id\s*\)[\s\(\)]*or[\s\(\)]*(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)[\s\(\)]*or[\s\(\)]*(public\.)?is_sarvex_admin\(\)[\s\(\)]*$', NULL),
    ('public', 'order_items', 'Only admins or trusted procedures insert order items', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$'),
    ('public', 'order_items', 'Customers insert order items for their own orders', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?(public\.)?is_order_customer\(\s*order_id\s*\)\)?[\s\(\)]*$'),
    ('public', 'order_items', 'Sellers can update only their own order items status', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?(public\.)?is_seller_shop_owner\(\s*seller_shop_id\s*\)\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$'),

    -- reviews
    ('public', 'reviews', 'Public can view all reviews', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*true[\s\(\)]*$', NULL),
    ('public', 'reviews', 'Verified buyers can submit reviews', 'INSERT', 'public', 'PERMISSIVE',
      NULL, '^[\s\(\)]*(auth\.)?uid\(\)[\s\(\)]*is[\s\(\)]*not[\s\(\)]*null[\s\(\)]*and[\s\(\)]*customer_id[\s\(\)]*=[\s\(\)]*(auth\.)?uid\(\)[\s\(\)]*$'),
    ('public', 'reviews', 'Customers can update their own reviews', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*customer_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*customer_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$'),
    ('public', 'reviews', 'Customers can delete their own reviews', 'DELETE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*customer_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$', NULL),

    -- review_helpful_votes
    ('public', 'review_helpful_votes', 'Users view own review votes', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*user_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$', NULL),
    ('public', 'review_helpful_votes', 'Only admins or trusted procedures insert review votes', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$'),
    ('public', 'review_helpful_votes', 'Users can insert their own review vote', 'INSERT', 'public', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*user_id\)?[\s\(\)]*$'),
    ('public', 'review_helpful_votes', 'Only admins manage review votes', 'UPDATE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$'),
    ('public', 'review_helpful_votes', 'Only admins delete review votes', 'DELETE', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$', NULL),

    -- wishlist_items
    ('public', 'wishlist_items', 'Users can manage their own wishlist', 'ALL', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?(auth\.)?uid\(\)\s*=\s*owner_id\)?[\s\(\)]*$'),

    -- categories
    ('public', 'categories', 'Public read categories', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*true[\s\(\)]*$', NULL),
    ('public', 'categories', 'Admins manage categories', 'ALL', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$'),

    -- sarvex_admin_allowlist
    ('public', 'sarvex_admin_allowlist', 'Only admins view admin allowlist', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$', NULL),
    ('public', 'sarvex_admin_allowlist', 'Only admins manage admin allowlist', 'ALL', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?(public\.)?is_sarvex_admin\(\)\)?[\s\(\)]*$'),

    -- order_idempotency_keys
    ('public', 'order_idempotency_keys', 'Users view own idempotency keys', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?(auth\.)?uid\(\)\s*=\s*customer_id\)?\s*or\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$', NULL),

    -- storage.objects (product-images bucket)
    ('storage', 'objects', 'Public can view product images', 'SELECT', 'public', 'PERMISSIVE',
     '^[\s\(\)]*\(?bucket_id\s*=\s*''product-images''(::text)?\)?[\s\(\)]*$', NULL),
    ('storage', 'objects', 'Approved sellers upload product images', 'INSERT', 'authenticated', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?\(?\(?bucket_id\s*=\s*''product-images''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?\s*and\s*\(?EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+(public\.)?seller_shops.*approval_status\s*=\s*''approved''.*\)\)?\)?[\s\(\)]*$'),
    ('storage', 'objects', 'Approved sellers update own product images', 'UPDATE', 'authenticated', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?\(?bucket_id\s*=\s*''product-images''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?\s*and\s*\(?EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+(public\.)?seller_shops.*approval_status\s*=\s*''approved''.*\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?\(?bucket_id\s*=\s*''product-images''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?\s*and\s*\(?EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+(public\.)?seller_shops.*approval_status\s*=\s*''approved''.*\)\)?\)?[\s\(\)]*$'),
    ('storage', 'objects', 'Approved sellers delete own product images', 'DELETE', 'authenticated', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?\(?bucket_id\s*=\s*''product-images''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?\s*and\s*\(?EXISTS\s*\(\s*SELECT\s+1\s+FROM\s+(public\.)?seller_shops.*approval_status\s*=\s*''approved''.*\)\)?\)?[\s\(\)]*$', NULL),
    ('storage', 'objects', 'Admins manage all product images', 'ALL', 'authenticated', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''product-images''(::text)?\)?\s*and\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''product-images''(::text)?\)?\s*and\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$'),

    -- storage.objects (seller-kyc-documents bucket)
    ('storage', 'objects', 'Sellers upload own KYC documents', 'INSERT', 'authenticated', 'PERMISSIVE',
     NULL, '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''seller-kyc-documents''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?[\s\(\)]*$'),
    ('storage', 'objects', 'Sellers view own KYC documents', 'SELECT', 'authenticated', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''seller-kyc-documents''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?[\s\(\)]*$', NULL),
    ('storage', 'objects', 'Sellers update own KYC documents', 'UPDATE', 'authenticated', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''seller-kyc-documents''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?(\s*and\s*\(?not\s*\(?exists\s*\(.*seller_shops.*owner_id\s*=\s*(auth\.)?uid\(\).*approval_status\s*=\s*''approved''.*\)[\s\(\)]*)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''seller-kyc-documents''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?(\s*and\s*\(?not\s*\(?exists\s*\(.*seller_shops.*owner_id\s*=\s*(auth\.)?uid\(\).*approval_status\s*=\s*''approved''.*\)[\s\(\)]*)?[\s\(\)]*$'),
    ('storage', 'objects', 'Sellers delete own KYC documents', 'DELETE', 'authenticated', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''seller-kyc-documents''(::text)?\)?\s*and\s*\(?\(?\(?storage\.foldername\(name\)\)?\[1\]\s*=\s*\(?(auth\.)?uid\(\)\)?::text\)?\)?(\s*and\s*\(?not\s*\(?exists\s*\(.*seller_shops.*owner_id\s*=\s*(auth\.)?uid\(\).*approval_status\s*=\s*''approved''.*\)[\s\(\)]*)?[\s\(\)]*$', NULL),
    ('storage', 'objects', 'Admins manage all KYC documents', 'ALL', 'authenticated', 'PERMISSIVE',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''seller-kyc-documents''(::text)?\)?\s*and\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$',
     '^[\s\(\)]*\(?\(?bucket_id\s*=\s*''seller-kyc-documents''(::text)?\)?\s*and\s*\(?(public\.)?is_sarvex_admin\(\)\)?\)?[\s\(\)]*$');

  -- Explicitly retire only the exact, catalog-verified legacy policies found on the
  -- existing SARVEX starter schema. Any same-named policy with a different definition
  -- is NOT dropped; it remains for the strict verifier below to reject.
  CREATE TEMP TABLE IF NOT EXISTS sarvex_legacy_policy_specs (
    tablename text NOT NULL,
    policyname text NOT NULL,
    cmd text NOT NULL,
    roles text[] NOT NULL,
    qual text,
    with_check text
  ) ON COMMIT DROP;

  INSERT INTO sarvex_legacy_policy_specs (tablename, policyname, cmd, roles, qual, with_check)
  VALUES
    ('cart_items', 'cart_items_create_policy', 'INSERT', ARRAY['public'], NULL, '(( SELECT auth.uid() AS uid) IS NOT NULL)'),
    ('cart_items', 'cart_items_delete_policy', 'DELETE', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', NULL),
    ('cart_items', 'cart_items_read_policy', 'SELECT', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', NULL),
    ('cart_items', 'cart_items_update_policy', 'UPDATE', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', '(owner_id = ( SELECT auth.uid() AS uid))'),
    ('customer_profiles', 'customer_profiles_create_policy', 'INSERT', ARRAY['public'], NULL, '(( SELECT auth.uid() AS uid) IS NOT NULL)'),
    ('customer_profiles', 'customer_profiles_delete_policy', 'DELETE', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', NULL),
    ('customer_profiles', 'customer_profiles_read_policy', 'SELECT', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', NULL),
    ('customer_profiles', 'customer_profiles_update_policy', 'UPDATE', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', '(owner_id = ( SELECT auth.uid() AS uid))'),
    ('products', 'products_create_policy', 'INSERT', ARRAY['public'], NULL, '(( SELECT auth.uid() AS uid) IS NOT NULL)'),
    ('products', 'products_delete_policy', 'DELETE', ARRAY['public'], '(( SELECT auth.uid() AS uid) IS NOT NULL)', NULL),
    ('products', 'products_read_policy', 'SELECT', ARRAY['public'], '(( SELECT auth.uid() AS uid) IS NOT NULL)', NULL),
    ('products', 'products_update_policy', 'UPDATE', ARRAY['public'], '(( SELECT auth.uid() AS uid) IS NOT NULL)', '(( SELECT auth.uid() AS uid) IS NOT NULL)'),
    ('seller_shops', 'seller_shops_create_policy', 'INSERT', ARRAY['public'], NULL, '(( SELECT auth.uid() AS uid) IS NOT NULL)'),
    ('seller_shops', 'seller_shops_delete_policy', 'DELETE', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', NULL),
    ('seller_shops', 'seller_shops_read_policy', 'SELECT', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', NULL),
    ('seller_shops', 'seller_shops_update_policy', 'UPDATE', ARRAY['public'], '(owner_id = ( SELECT auth.uid() AS uid))', '(owner_id = ( SELECT auth.uid() AS uid))');

  FOR pol IN
    SELECT p.schemaname, p.tablename, p.policyname
    FROM pg_policies p
    JOIN sarvex_legacy_policy_specs s
      ON s.tablename = p.tablename
     AND s.policyname = p.policyname
     AND s.cmd = p.cmd
     AND s.roles = p.roles::text[]
     AND s.qual IS NOT DISTINCT FROM p.qual
     AND s.with_check IS NOT DISTINCT FROM p.with_check
    WHERE p.schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    RAISE NOTICE 'Removed exact insecure legacy policy "%" on %.%', pol.policyname, pol.schemaname, pol.tablename;
  END LOOP;

  -- Scan existing policies on SARVEX tables and compare against approved catalog
  FOR pol IN (
    SELECT schemaname, tablename, policyname, permissive, cmd, roles, qual, with_check
    FROM pg_policies
    WHERE (
      schemaname = 'public'
      AND tablename IN (
        'customer_profiles',
        'seller_shops',
        'products',
        'cart_items',
        'orders',
        'order_items',
        'order_idempotency_keys',
        'reviews',
        'wishlist_items',
        'categories',
        'sarvex_admin_allowlist',
        'review_helpful_votes'
      )
    ) OR (
      schemaname = 'storage'
      AND tablename = 'objects'
    )
  ) LOOP
    -- 1. Preserve restrictive policies unconditionally
    IF pol.permissive = 'RESTRICTIVE' THEN
      RAISE NOTICE 'Preserving verified RESTRICTIVE policy "%" on %.%', pol.policyname, pol.schemaname, pol.tablename;
      CONTINUE;
    END IF;

    -- 2. Anti-bypass guard: Reject any permissive policy with dangerous disjunction bypasses
    -- (e.g., 'OR TRUE', 'TRUE OR', 'OR 1=1', 'OR NULL IS NULL') on protected tables
    IF (
      (pol.qual IS NOT NULL AND pol.qual ~* '(\bor\s+true\b|\btrue\s+or\b|\bor\s+1\s*=\s*1\b|\b1\s*=\s*1\s+or\b|\bor\s+null\s+is\s+null\b|\bor\s*''''\s*=\s*'''')')
      OR
      (pol.with_check IS NOT NULL AND pol.with_check ~* '(\bor\s+true\b|\btrue\s+or\b|\bor\s+1\s*=\s*1\b|\b1\s*=\s*1\s+or\b|\bor\s+null\s+is\s+null\b|\bor\s*''''\s*=\s*'''')')
    ) AND pol.policyname NOT IN ('Public can view all reviews', 'Users can view review votes', 'Public read categories') THEN
      RAISE EXCEPTION 'SARVEX SECURITY VIOLATION: Weaker disjunctive bypass detected in PERMISSIVE policy "%" on %.% (qual: %, with_check: %). Migration aborted to prevent RLS bypass.',
        pol.policyname, pol.schemaname, pol.tablename, pol.qual, pol.with_check
        USING ERRCODE = '42501';
    END IF;

    -- 3. Verify exact catalog specification for PERMISSIVE policy using strict anchored patterns, exact role matching, and qual/with_check parity
    SELECT EXISTS (
      SELECT 1 FROM sarvex_approved_policy_specs s
      WHERE s.schemaname = pol.schemaname
        AND s.tablename = pol.tablename
        AND s.policyname = pol.policyname
        AND s.cmd = pol.cmd
        AND s.permissive = pol.permissive
        AND pol.roles::text[] = ARRAY[s.target_role]
        -- The KYC update policy must always prevent edits after seller approval.
        -- Require the ownership and approved-status exclusion in BOTH USING and WITH CHECK.
        AND (
          pol.policyname <> 'Sellers update own KYC documents'
          OR (
            pol.qual IS NOT NULL
            AND pol.qual ~* 'not.*exists.*seller_shops.*owner_id\s*=\s*(auth\.)?uid\(\).*approval_status\s*=\s*''approved'''
            AND pol.with_check IS NOT NULL
            AND pol.with_check ~* 'not.*exists.*seller_shops.*owner_id\s*=\s*(auth\.)?uid\(\).*approval_status\s*=\s*''approved'''
          )
        )
        AND (
          (s.qual_pattern IS NULL AND pol.qual IS NULL) OR
          (s.qual_pattern IS NOT NULL AND pol.qual IS NOT NULL AND pol.qual ~* s.qual_pattern)
        )
        AND (
          (s.with_check_pattern IS NULL AND pol.with_check IS NULL) OR
          (s.with_check_pattern IS NOT NULL AND pol.with_check IS NOT NULL AND pol.with_check ~* s.with_check_pattern)
        )
    ) INTO v_is_approved;

    IF v_is_approved THEN
      -- Exact approved managed SARVEX policy: drop cleanly so Section 15 can idempotently recreate latest definition
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
      RAISE NOTICE 'Verified and dropped approved managed policy "%" on %.% for refresh', pol.policyname, pol.schemaname, pol.tablename;
    ELSE
      -- Unknown, generic legacy (e.g. "Public Access", "Allow all"), or mismatched permissive policy: FAIL CLOSED
      RAISE EXCEPTION 'SARVEX SECURITY VIOLATION: Unrecognized or mismatched PERMISSIVE policy "%" (cmd: %, roles: %, qual: %, with_check: %) on table "%.%". Aborting migration to prevent RLS bypass. Remove or convert to RESTRICTIVE before running migration.',
        pol.policyname, pol.cmd, pol.roles, pol.qual, pol.with_check, pol.schemaname, pol.tablename
        USING ERRCODE = '42501';
    END IF;
  END LOOP;
END $$;

-- ============================================================================
-- 3. ENHANCE EXISTING: customer_profiles
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID UNIQUE NOT NULL,
  display_name TEXT,
  account_role TEXT DEFAULT 'customer',
  phone TEXT,
  email TEXT,
  city TEXT,
  state TEXT,
  pincode TEXT,
  address TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS public.customer_profiles
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN account_role SET DEFAULT 'customer',
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS pincode TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Secure Auth signup provisioning: every new Auth user receives a customer-only profile.
-- The role is never copied from user metadata; account_role always uses the DB default.
CREATE OR REPLACE FUNCTION public.handle_new_sarvex_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  INSERT INTO public.customer_profiles (owner_id, display_name, email, phone, account_role)
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), ''),
      NULLIF(trim(NEW.raw_user_meta_data ->> 'name'), '')
    ),
    NEW.email,
    NULLIF(trim(NEW.raw_user_meta_data ->> 'phone'), ''),
    'customer'
  )
  ON CONFLICT (owner_id) DO NOTHING;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.handle_new_sarvex_user() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.handle_new_sarvex_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_sarvex_user() TO service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_sarvex_user() TO supabase_auth_admin';
  END IF;
END
$$;
DROP TRIGGER IF EXISTS on_auth_user_created_sarvex ON auth.users;
CREATE TRIGGER on_auth_user_created_sarvex
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_sarvex_user();

-- Idempotent Catalog-Verified Hardening of UNIQUE (owner_id) on customer_profiles
DO $$
DECLARE
    v_attnum smallint;
    v_att_notnull boolean;
    v_existing_idx_name text;
    v_dup_count bigint;
BEGIN
    SELECT attnum, attnotnull INTO v_attnum, v_att_notnull
    FROM pg_attribute
    WHERE attrelid = 'public.customer_profiles'::regclass
      AND attname = 'owner_id' AND NOT attisdropped;

    IF v_attnum IS NULL THEN
        RAISE EXCEPTION 'Column owner_id missing on public.customer_profiles';
    END IF;

    IF NOT v_att_notnull THEN
        RAISE EXCEPTION 'Column owner_id on public.customer_profiles must be NOT NULL for unique constraint';
    END IF;

    -- Check for ANY existing valid, ready, non-partial, non-expression 1-key B-tree unique index
    SELECT c.relname INTO v_existing_idx_name
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indexrelid
    JOIN pg_am am ON am.oid = c.relam
    WHERE i.indrelid = 'public.customer_profiles'::regclass
      AND am.amname = 'btree'
      AND i.indisunique = true
      AND i.indisvalid = true
      AND i.indisready = true
      AND i.indpred IS NULL
      AND i.indexprs IS NULL
      AND i.indnatts = 1
      AND i.indnkeyatts = 1
      AND i.indkey[0] = v_attnum
    LIMIT 1;

    IF v_existing_idx_name IS NOT NULL THEN
        RAISE NOTICE 'Valid unique index % already covers customer_profiles(owner_id)', v_existing_idx_name;
        RETURN;
    END IF;

    -- Pre-check duplicate owner_ids before attempting constraint creation (ZERO DATA LOSS)
    SELECT count(*) INTO v_dup_count
    FROM (
        SELECT owner_id
        FROM public.customer_profiles
        GROUP BY owner_id
        HAVING count(*) > 1
    ) dups;

    IF v_dup_count > 0 THEN
        RAISE EXCEPTION 'Cannot add unique constraint: found % duplicate owner_id records in customer_profiles. Data preservation policy forbids automatic deletion. Manual remediation required.', v_dup_count;
    END IF;

    -- Collision check on target constraint and relation name
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.customer_profiles'::regclass
          AND conname = 'customer_profiles_owner_id_key'
    ) OR EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = 'customer_profiles_owner_id_key'
          AND relnamespace = 'public'::regnamespace
    ) THEN
        RAISE EXCEPTION 'Identifier customer_profiles_owner_id_key already exists with mismatched definition';
    END IF;

    ALTER TABLE public.customer_profiles
        ADD CONSTRAINT customer_profiles_owner_id_key
        UNIQUE (owner_id);

    RAISE NOTICE 'Added constraint customer_profiles_owner_id_key successfully';
END $$;

-- ============================================================================
-- 4. ENHANCE EXISTING: seller_shops
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.seller_shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL,
  shop_name TEXT NOT NULL,
  approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  owner_name TEXT,
  phone TEXT,
  email TEXT,
  city TEXT,
  state TEXT,
  pincode TEXT,
  pickup_address TEXT,
  upi_id TEXT,
  bank_account TEXT,
  ifsc_code TEXT,
  commission_rate NUMERIC DEFAULT 10.0 CHECK (commission_rate >= 0 AND commission_rate <= 100),
  rating NUMERIC DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS public.seller_shops
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ALTER COLUMN approval_status SET DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS owner_name TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS state TEXT,
  ADD COLUMN IF NOT EXISTS pincode TEXT,
  ADD COLUMN IF NOT EXISTS pickup_address TEXT,
  ADD COLUMN IF NOT EXISTS upi_id TEXT,
  ADD COLUMN IF NOT EXISTS bank_account TEXT,
  ADD COLUMN IF NOT EXISTS ifsc_code TEXT,
  ADD COLUMN IF NOT EXISTS commission_rate NUMERIC DEFAULT 10.0,
  ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5);

ALTER TABLE IF EXISTS public.seller_shops
  ALTER COLUMN commission_rate SET DEFAULT 10.0,
  ALTER COLUMN rating SET DEFAULT 0.0;

-- Idempotent Catalog-Verified Hardening of seller_shops_commission_rate_check (commission_rate >= 0 AND commission_rate <= 100)
DO $$
DECLARE
    v_cdef text;
    v_invalid_count bigint;
BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_cdef
    FROM pg_constraint c
    WHERE c.conrelid = 'public.seller_shops'::regclass
      AND c.conname = 'seller_shops_commission_rate_check'
      AND c.contype = 'c';

    IF v_cdef IS NOT NULL THEN
        RAISE NOTICE 'Constraint seller_shops_commission_rate_check already exists on public.seller_shops';
        RETURN;
    END IF;

    SELECT count(*) INTO v_invalid_count
    FROM public.seller_shops
    WHERE commission_rate IS NOT NULL AND (commission_rate < 0 OR commission_rate > 100);

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'Cannot add constraint seller_shops_commission_rate_check: found % shop(s) with commission_rate outside [0, 100]. Manual remediation required.', v_invalid_count
            USING ERRCODE = '23514';
    END IF;

    ALTER TABLE public.seller_shops
        ADD CONSTRAINT seller_shops_commission_rate_check
        CHECK (commission_rate >= 0 AND commission_rate <= 100);

    RAISE NOTICE 'Added constraint seller_shops_commission_rate_check successfully';
END $$;

-- ============================================================================
-- 5. ENHANCE EXISTING: products
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_shop_id UUID REFERENCES public.seller_shops(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  description TEXT,
  price_inr NUMERIC NOT NULL CHECK (price_inr >= 0),
  mrp NUMERIC,
  category TEXT NOT NULL,
  stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
  discount_percent NUMERIC DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
  image_url TEXT,
  rating NUMERIC DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
  rating_count INTEGER DEFAULT 0 CHECK (rating_count >= 0),
  is_featured BOOLEAN DEFAULT FALSE,
  badge TEXT DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT products_mrp_check CHECK (mrp IS NULL OR mrp >= price_inr)
);

ALTER TABLE IF EXISTS public.products
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS mrp NUMERIC,
  ADD COLUMN IF NOT EXISTS discount_percent NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS badge TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0 CHECK (rating_count >= 0);

ALTER TABLE IF EXISTS public.products
  ALTER COLUMN rating SET DEFAULT 0.0,
  ALTER COLUMN rating_count SET DEFAULT 0,
  ALTER COLUMN badge SET DEFAULT NULL;

-- Idempotent Catalog-Verified Hardening of products_mrp_check (mrp IS NULL OR mrp >= price_inr)
DO $$
DECLARE
    v_cdef text;
    v_norm_cdef text;
    v_invalid_count bigint;
    v_con_rec record;
BEGIN
    -- 1. Check if constraint products_mrp_check exists on public.products and verify catalog definition
    SELECT pg_get_constraintdef(c.oid) INTO v_cdef
    FROM pg_constraint c
    WHERE c.conrelid = 'public.products'::regclass
      AND c.conname = 'products_mrp_check'
      AND c.contype = 'c';

    IF v_cdef IS NOT NULL THEN
        -- Normalize definition: remove outer/inner parentheses and collapse whitespace
        v_norm_cdef := trim(regexp_replace(regexp_replace(lower(v_cdef), '[()]', '', 'g'), '\s+', ' ', 'g'));

        -- Verify expression equivalence to: CHECK (mrp IS NULL OR mrp >= price_inr)
        IF v_norm_cdef IN (
            'check mrp is null or mrp >= price_inr',
            'check mrp is null or mrp >= price_inr::numeric',
            'check mrp >= price_inr or mrp is null',
            'check mrp >= price_inr::numeric or mrp is null',
            'check mrp is null or price_inr <= mrp',
            'check price_inr <= mrp or mrp is null'
        ) THEN
            RAISE NOTICE 'Constraint products_mrp_check already exists on public.products with verified catalog definition: %', v_cdef;
            RETURN;
        ELSE
            -- Incompatible definition: fail closed without dropping or modifying the existing constraint
            RAISE EXCEPTION 'Constraint products_mrp_check exists on public.products with incompatible definition "%" (normalized: "%"). Expected "CHECK (mrp IS NULL OR mrp >= price_inr)". Aborting migration to prevent data integrity violation.',
                v_cdef, v_norm_cdef
                USING ERRCODE = '42804';
        END IF;
    END IF;

    -- 2. Check if an equivalent check constraint exists under a different name
    FOR v_con_rec IN (
        SELECT c.conname, pg_get_constraintdef(c.oid) AS cdef
        FROM pg_constraint c
        WHERE c.conrelid = 'public.products'::regclass
          AND c.contype = 'c'
    ) LOOP
        v_norm_cdef := trim(regexp_replace(regexp_replace(lower(v_con_rec.cdef), '[()]', '', 'g'), '\s+', ' ', 'g'));
        IF v_norm_cdef IN (
            'check mrp is null or mrp >= price_inr',
            'check mrp is null or mrp >= price_inr::numeric',
            'check mrp >= price_inr or mrp is null',
            'check mrp >= price_inr::numeric or mrp is null',
            'check mrp is null or price_inr <= mrp',
            'check price_inr <= mrp or mrp is null'
        ) THEN
            RAISE NOTICE 'An equivalent constraint % already exists on public.products with verified catalog definition: %', v_con_rec.conname, v_con_rec.cdef;
            RETURN;
        END IF;
    END LOOP;

    -- 3. Pre-check existing records for constraint violation (ZERO DATA LOSS & EXPLICIT DIAGNOSTIC)
    SELECT count(*) INTO v_invalid_count
    FROM public.products
    WHERE mrp IS NOT NULL AND mrp < price_inr;

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'Cannot add constraint products_mrp_check: found % product record(s) where mrp < price_inr. Data preservation policy forbids automatic modification. Manual remediation required.', v_invalid_count
            USING ERRCODE = '23514';
    END IF;

    -- 4. Add constraint safely
    ALTER TABLE public.products
        ADD CONSTRAINT products_mrp_check
        CHECK (mrp IS NULL OR mrp >= price_inr);

    RAISE NOTICE 'Added constraint products_mrp_check successfully';
END $$;

-- Idempotent Catalog-Verified Hardening of products_discount_percent_check (discount_percent >= 0 AND discount_percent <= 100)
DO $$
DECLARE
    v_cdef text;
    v_invalid_count bigint;
BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_cdef
    FROM pg_constraint c
    WHERE c.conrelid = 'public.products'::regclass
      AND c.conname = 'products_discount_percent_check'
      AND c.contype = 'c';

    IF v_cdef IS NOT NULL THEN
        RAISE NOTICE 'Constraint products_discount_percent_check already exists on public.products';
        RETURN;
    END IF;

    SELECT count(*) INTO v_invalid_count
    FROM public.products
    WHERE discount_percent IS NOT NULL AND (discount_percent < 0 OR discount_percent > 100);

    IF v_invalid_count > 0 THEN
        RAISE EXCEPTION 'Cannot add constraint products_discount_percent_check: found % product(s) with discount_percent outside [0, 100]. Manual remediation required.', v_invalid_count
            USING ERRCODE = '23514';
    END IF;

    ALTER TABLE public.products
        ADD CONSTRAINT products_discount_percent_check
        CHECK (discount_percent >= 0 AND discount_percent <= 100);

    RAISE NOTICE 'Added constraint products_discount_percent_check successfully';
END $$;

-- ============================================================================
-- 6. ENHANCE EXISTING: cart_items
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS public.cart_items
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- Idempotent Catalog-Verified Hardening of UNIQUE (owner_id, product_id) on cart_items
DO $$
DECLARE
    v_att_owner smallint;
    v_att_product smallint;
    v_owner_notnull boolean;
    v_product_notnull boolean;
    v_existing_idx_name text;
    v_dup_count bigint;
BEGIN
    SELECT attnum, attnotnull INTO v_att_owner, v_owner_notnull
    FROM pg_attribute
    WHERE attrelid = 'public.cart_items'::regclass
      AND attname = 'owner_id' AND NOT attisdropped;

    SELECT attnum, attnotnull INTO v_att_product, v_product_notnull
    FROM pg_attribute
    WHERE attrelid = 'public.cart_items'::regclass
      AND attname = 'product_id' AND NOT attisdropped;

    IF v_att_owner IS NULL OR v_att_product IS NULL THEN
        RAISE EXCEPTION 'Required columns owner_id or product_id missing on public.cart_items';
    END IF;

    IF NOT (v_owner_notnull AND v_product_notnull) THEN
        RAISE EXCEPTION 'Columns owner_id and product_id on public.cart_items must both be NOT NULL for unique constraint';
    END IF;

    -- Check for ANY existing valid, ready, non-partial, non-expression 2-key B-tree unique index
    SELECT c.relname INTO v_existing_idx_name
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indexrelid
    JOIN pg_am am ON am.oid = c.relam
    WHERE i.indrelid = 'public.cart_items'::regclass
      AND am.amname = 'btree'
      AND i.indisunique = true
      AND i.indisvalid = true
      AND i.indisready = true
      AND i.indpred IS NULL
      AND i.indexprs IS NULL
      AND i.indnatts = 2
      AND i.indnkeyatts = 2
      AND (
          (i.indkey[0] = v_att_owner AND i.indkey[1] = v_att_product) OR
          (i.indkey[0] = v_att_product AND i.indkey[1] = v_att_owner)
      )
    LIMIT 1;

    IF v_existing_idx_name IS NOT NULL THEN
        RAISE NOTICE 'Valid unique index % already covers cart_items(owner_id, product_id)', v_existing_idx_name;
        RETURN;
    END IF;

    -- Pre-check duplicate rows before attempting constraint creation (ZERO DATA LOSS)
    SELECT count(*) INTO v_dup_count
    FROM (
        SELECT owner_id, product_id
        FROM public.cart_items
        GROUP BY owner_id, product_id
        HAVING count(*) > 1
    ) dups;

    IF v_dup_count > 0 THEN
        RAISE EXCEPTION 'Cannot add unique constraint: found % duplicate (owner_id, product_id) records in cart_items. Data preservation policy forbids automatic deletion. Manual remediation required.', v_dup_count;
    END IF;

    -- Collision check on target constraint and relation name
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.cart_items'::regclass
          AND conname = 'cart_items_owner_product_key'
    ) OR EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = 'cart_items_owner_product_key'
          AND relnamespace = 'public'::regnamespace
    ) THEN
        RAISE EXCEPTION 'Identifier cart_items_owner_product_key already exists with mismatched definition';
    END IF;

    ALTER TABLE public.cart_items
        ADD CONSTRAINT cart_items_owner_product_key
        UNIQUE (owner_id, product_id);

    RAISE NOTICE 'Added constraint cart_items_owner_product_key successfully';
END $$;

CREATE INDEX IF NOT EXISTS cart_items_owner_id_idx ON public.cart_items(owner_id);

-- ============================================================================
-- 7. CREATE NEW MARKETPLACE TABLES
-- ============================================================================

-- Orders Table
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code TEXT UNIQUE NOT NULL,
  customer_id UUID,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  customer_email TEXT,
  shipping_address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  pincode TEXT NOT NULL,
  total_amount NUMERIC NOT NULL CHECK (total_amount >= 0),
  payment_method TEXT DEFAULT 'cod' CHECK (payment_method IN ('cod', 'upi', 'card')),
  status TEXT DEFAULT 'placed' CHECK (status IN ('placed', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Order Idempotency Keys Table (Checkout duplicate & replay protection)
CREATE TABLE IF NOT EXISTS public.order_idempotency_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key TEXT NOT NULL,
  customer_id UUID NOT NULL,
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  request_hash TEXT NOT NULL DEFAULT '',
  response_payload JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT order_idempotency_keys_cust_key_key UNIQUE (customer_id, idempotency_key)
);

ALTER TABLE IF EXISTS public.order_idempotency_keys
  ADD COLUMN IF NOT EXISTS request_hash TEXT DEFAULT '';

-- Idempotent schema evolution & safe backfill for public.orders on existing databases
ALTER TABLE IF EXISTS public.orders
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS customer_email TEXT,
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cod',
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'placed',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'public.orders'::regclass
      AND attname = 'order_code'
      AND NOT attisdropped
  ) THEN
    ALTER TABLE public.orders ADD COLUMN order_code TEXT;
    UPDATE public.orders
    SET order_code = 'SRX-' || TO_CHAR(COALESCE(created_at, NOW()), 'YYMMDD') || '-' || UPPER(SUBSTRING(REPLACE(id::text, '-', '') FROM 1 FOR 10))
    WHERE order_code IS NULL;
    ALTER TABLE public.orders ALTER COLUMN order_code SET NOT NULL;
    ALTER TABLE public.orders ADD CONSTRAINT orders_order_code_key UNIQUE (order_code);
    RAISE NOTICE 'Added and backfilled order_code on existing public.orders table';
  END IF;
END $$;

-- Order Items Table
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  seller_shop_id UUID REFERENCES public.seller_shops(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  price_inr NUMERIC NOT NULL CHECK (price_inr >= 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  commission_rate NUMERIC DEFAULT 10.0 CHECK (commission_rate >= 0 AND commission_rate <= 100),
  commission_amount NUMERIC DEFAULT 0.0 CHECK (commission_amount >= 0),
  seller_payable_amount NUMERIC DEFAULT 0.0 CHECK (seller_payable_amount >= 0),
  image_url TEXT,
  item_status TEXT DEFAULT 'placed' CHECK (item_status IN ('placed', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Idempotent schema evolution for public.order_items on existing databases
ALTER TABLE IF EXISTS public.order_items
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS seller_shop_id UUID REFERENCES public.seller_shops(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS commission_rate NUMERIC DEFAULT 10.0,
  ADD COLUMN IF NOT EXISTS commission_amount NUMERIC DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS seller_payable_amount NUMERIC DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS item_status TEXT DEFAULT 'placed',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Idempotent Hardened CHECK Constraint Validation for order_items.item_status
DO $$
DECLARE
    v_attnum smallint;
    v_r record;
    v_extracted_vals text[];
    v_target_vals text[] := ARRAY['cancelled', 'confirmed', 'delivered', 'out_for_delivery', 'packed', 'placed', 'shipped'];
    v_legacy_5_vals text[] := ARRAY['cancelled', 'confirmed', 'delivered', 'placed', 'shipped'];
    v_legacy_4_vals text[] := ARRAY['cancelled', 'confirmed', 'placed', 'shipped'];
    v_legacy_6_vals text[] := ARRAY['cancelled', 'confirmed', 'delivered', 'out_for_delivery', 'placed', 'shipped'];
    v_has_logical_operators boolean;
    v_exact_match_count int := 0;
    v_unrecognized_count int := 0;
    v_unrecognized_details text := '';
BEGIN
    SELECT attnum INTO v_attnum
    FROM pg_attribute
    WHERE attrelid = 'public.order_items'::regclass
      AND attname = 'item_status'
      AND NOT attisdropped;

    IF v_attnum IS NULL THEN
        -- Column does not exist on existing legacy table; add it cleanly
        ALTER TABLE public.order_items
            ADD COLUMN item_status TEXT DEFAULT 'placed'
            CHECK (item_status IN ('placed', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled'));
        RAISE NOTICE 'Added item_status column with 7-value check constraint to order_items';
        RETURN;
    END IF;

    -- Inspect all single-column CHECK constraints belonging exclusively to item_status
    FOR v_r IN
        SELECT c.oid, c.conname, pg_get_constraintdef(c.oid) AS cdef
        FROM pg_constraint c
        WHERE c.conrelid = 'public.order_items'::regclass
          AND c.contype = 'c'
          AND c.conkey = ARRAY[v_attnum]
    LOOP
        -- Fail-closed: Detect any logical connectives, NULL-bypasses or relational operators
        v_has_logical_operators := (
            v_r.cdef ~* '\m(AND|OR|NOT|IS\s+NULL|IS\s+NOT\s+NULL|CASE|WHEN|THEN|ELSE|LIKE|ILIKE|BETWEEN)\M'
            OR v_r.cdef ~ '(!=|<>|[><])'
        );

        IF v_has_logical_operators THEN
            v_unrecognized_count := v_unrecognized_count + 1;
            v_unrecognized_details := v_unrecognized_details || format('%I: contains operators in "%s"; ', v_r.conname, v_r.cdef);
            CONTINUE;
        END IF;

        -- Extract all distinct quoted string literals
        SELECT array_agg(DISTINCT val ORDER BY val) INTO v_extracted_vals
        FROM (
            SELECT (regexp_matches(v_r.cdef, '''([^'']+)''', 'g'))[1] AS val
        ) s;

        -- Exact set matching without operator pollution
        IF v_extracted_vals = v_target_vals THEN
            v_exact_match_count := v_exact_match_count + 1;
        ELSIF v_extracted_vals = v_legacy_5_vals OR v_extracted_vals = v_legacy_4_vals OR v_extracted_vals = v_legacy_6_vals THEN
            EXECUTE format('ALTER TABLE public.order_items DROP CONSTRAINT %I', v_r.conname);
            RAISE NOTICE 'Dropped legacy status constraint: %', v_r.conname;
        ELSE
            v_unrecognized_count := v_unrecognized_count + 1;
            v_unrecognized_details := v_unrecognized_details || format('%I: unexpected values %s; ', v_r.conname, v_extracted_vals::text);
        END IF;
    END LOOP;

    -- Fail-closed on any unrecognized or ambiguous business rule
    IF v_unrecognized_count > 0 THEN
        RAISE EXCEPTION 'Aborting migration: Found % unrecognized check constraint(s) on order_items.item_status: %',
            v_unrecognized_count, v_unrecognized_details;
    END IF;

    IF v_exact_match_count = 0 THEN
        IF EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'public.order_items'::regclass
              AND conname = 'order_items_item_status_check'
        ) THEN
            RAISE EXCEPTION 'Constraint name collision: order_items_item_status_check already exists with mismatched definition.';
        END IF;

        ALTER TABLE public.order_items
            ADD CONSTRAINT order_items_item_status_check
            CHECK (item_status IN ('placed', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled'));
        RAISE NOTICE 'Added order_items_item_status_check successfully';
    ELSIF v_exact_match_count = 1 THEN
        RAISE NOTICE 'Exact 7-value constraint already present and verified pure. Retained.';
    ELSE
        RAISE EXCEPTION 'Detected % duplicate exact constraints on order_items.item_status. Manual review required.', v_exact_match_count;
    END IF;
END $$;

-- Reviews Table
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL,
  customer_name TEXT NOT NULL,
  customer_city TEXT,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title TEXT NOT NULL,
  comment TEXT NOT NULL,
  is_verified_buyer BOOLEAN DEFAULT FALSE,
  helpful_count INTEGER DEFAULT 0 CHECK (helpful_count >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (product_id, customer_id)
);

-- Idempotent schema evolution for public.reviews on existing databases
ALTER TABLE IF EXISTS public.reviews
  ALTER COLUMN id SET DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS is_verified_buyer BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS helpful_count INTEGER DEFAULT 0;

-- Review Helpful Votes Table (Strict duplicate vote prevention)
CREATE TABLE IF NOT EXISTS public.review_helpful_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (review_id, user_id)
);

-- Idempotent Catalog-Verified Hardening of review_helpful_votes(review_id, user_id)
DO $$
DECLARE
    v_att_review smallint;
    v_att_user smallint;
    v_review_notnull boolean;
    v_user_notnull boolean;
    v_existing_idx_name text;
    v_dup_count bigint;
BEGIN
    -- Verify attribute presence and NOT NULL status
    SELECT attnum, attnotnull INTO v_att_review, v_review_notnull
    FROM pg_attribute
    WHERE attrelid = 'public.review_helpful_votes'::regclass
      AND attname = 'review_id' AND NOT attisdropped;

    SELECT attnum, attnotnull INTO v_att_user, v_user_notnull
    FROM pg_attribute
    WHERE attrelid = 'public.review_helpful_votes'::regclass
      AND attname = 'user_id' AND NOT attisdropped;

    IF v_att_review IS NULL OR v_att_user IS NULL THEN
        RAISE EXCEPTION 'Required columns review_id or user_id missing on public.review_helpful_votes';
    END IF;

    IF NOT (v_review_notnull AND v_user_notnull) THEN
        RAISE EXCEPTION 'Aborting unique constraint: review_id and user_id must both be NOT NULL for strict uniqueness';
    END IF;

    -- Check for ANY existing valid, ready, non-partial, non-expression 2-key B-tree unique index
    SELECT c.relname INTO v_existing_idx_name
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indexrelid
    JOIN pg_am am ON am.oid = c.relam
    WHERE i.indrelid = 'public.review_helpful_votes'::regclass
      AND am.amname = 'btree'
      AND i.indisunique = true
      AND i.indisvalid = true
      AND i.indisready = true
      AND i.indpred IS NULL
      AND i.indexprs IS NULL
      AND i.indnatts = 2
      AND i.indnkeyatts = 2
      AND (
          (i.indkey[0] = v_att_review AND i.indkey[1] = v_att_user) OR
          (i.indkey[0] = v_att_user AND i.indkey[1] = v_att_review)
      )
    LIMIT 1;

    IF v_existing_idx_name IS NOT NULL THEN
        RAISE NOTICE 'Valid unique index % already covers review_helpful_votes(review_id, user_id)', v_existing_idx_name;
        RETURN;
    END IF;

    -- Pre-check for duplicate rows before attempting constraint creation (ZERO DATA LOSS)
    SELECT count(*) INTO v_dup_count
    FROM (
        SELECT review_id, user_id
        FROM public.review_helpful_votes
        GROUP BY review_id, user_id
        HAVING count(*) > 1
    ) dups;

    IF v_dup_count > 0 THEN
        RAISE EXCEPTION 'Cannot add unique constraint: found % duplicate (review_id, user_id) pairs in public.review_helpful_votes. Data preservation policy forbids automatic deletion. Manual remediation required.', v_dup_count;
    END IF;

    -- Collision check on target constraint and relation name
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.review_helpful_votes'::regclass
          AND conname = 'review_helpful_votes_review_id_user_id_key'
    ) OR EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = 'review_helpful_votes_review_id_user_id_key'
          AND relnamespace = 'public'::regnamespace
    ) THEN
        RAISE EXCEPTION 'Identifier review_helpful_votes_review_id_user_id_key already exists with mismatched definition';
    END IF;

    -- Apply unique constraint
    ALTER TABLE public.review_helpful_votes
        ADD CONSTRAINT review_helpful_votes_review_id_user_id_key
        UNIQUE (review_id, user_id);

    RAISE NOTICE 'Added constraint review_helpful_votes_review_id_user_id_key successfully';
END $$;

-- Wishlist Table
CREATE TABLE IF NOT EXISTS public.wishlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(owner_id, product_id)
);

-- Idempotent Catalog-Verified Hardening of UNIQUE (owner_id, product_id) on wishlist_items
DO $$
DECLARE
    v_att_owner smallint;
    v_att_product smallint;
    v_owner_notnull boolean;
    v_product_notnull boolean;
    v_existing_idx_name text;
    v_dup_count bigint;
BEGIN
    SELECT attnum, attnotnull INTO v_att_owner, v_owner_notnull
    FROM pg_attribute
    WHERE attrelid = 'public.wishlist_items'::regclass
      AND attname = 'owner_id' AND NOT attisdropped;

    SELECT attnum, attnotnull INTO v_att_product, v_product_notnull
    FROM pg_attribute
    WHERE attrelid = 'public.wishlist_items'::regclass
      AND attname = 'product_id' AND NOT attisdropped;

    IF v_att_owner IS NULL OR v_att_product IS NULL THEN
        RAISE EXCEPTION 'Required columns owner_id or product_id missing on public.wishlist_items';
    END IF;

    IF NOT (v_owner_notnull AND v_product_notnull) THEN
        RAISE EXCEPTION 'Columns owner_id and product_id on public.wishlist_items must both be NOT NULL for unique constraint';
    END IF;

    -- Check for ANY existing valid, ready, non-partial, non-expression 2-key B-tree unique index
    SELECT c.relname INTO v_existing_idx_name
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indexrelid
    JOIN pg_am am ON am.oid = c.relam
    WHERE i.indrelid = 'public.wishlist_items'::regclass
      AND am.amname = 'btree'
      AND i.indisunique = true
      AND i.indisvalid = true
      AND i.indisready = true
      AND i.indpred IS NULL
      AND i.indexprs IS NULL
      AND i.indnatts = 2
      AND i.indnkeyatts = 2
      AND (
          (i.indkey[0] = v_att_owner AND i.indkey[1] = v_att_product) OR
          (i.indkey[0] = v_att_product AND i.indkey[1] = v_att_owner)
      )
    LIMIT 1;

    IF v_existing_idx_name IS NOT NULL THEN
        RAISE NOTICE 'Valid unique index % already covers wishlist_items(owner_id, product_id)', v_existing_idx_name;
        RETURN;
    END IF;

    -- Pre-check duplicate rows before attempting constraint creation (ZERO DATA LOSS)
    SELECT count(*) INTO v_dup_count
    FROM (
        SELECT owner_id, product_id
        FROM public.wishlist_items
        GROUP BY owner_id, product_id
        HAVING count(*) > 1
    ) dups;

    IF v_dup_count > 0 THEN
        RAISE EXCEPTION 'Cannot add unique constraint: found % duplicate (owner_id, product_id) records in wishlist_items. Data preservation policy forbids automatic deletion. Manual remediation required.', v_dup_count;
    END IF;

    -- Collision check on target constraint and relation name
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.wishlist_items'::regclass
          AND conname = 'wishlist_items_owner_product_key'
    ) OR EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = 'wishlist_items_owner_product_key'
          AND relnamespace = 'public'::regnamespace
    ) THEN
        RAISE EXCEPTION 'Identifier wishlist_items_owner_product_key already exists with mismatched definition';
    END IF;

    ALTER TABLE public.wishlist_items
        ADD CONSTRAINT wishlist_items_owner_product_key
        UNIQUE (owner_id, product_id);

    RAISE NOTICE 'Added constraint wishlist_items_owner_product_key successfully';
END $$;

-- Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  icon TEXT,
  image_url TEXT,
  item_count INTEGER DEFAULT 0
);

-- Admin Allowlist Table
CREATE TABLE IF NOT EXISTS public.sarvex_admin_allowlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE,
  email TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Idempotent Hardening of UNIQUE (user_id) on sarvex_admin_allowlist
DO $$
DECLARE
    v_attnum smallint;
    v_existing_conname text;
    v_dup_uids bigint;
BEGIN
    SELECT attnum INTO v_attnum
    FROM pg_attribute
    WHERE attrelid = 'public.sarvex_admin_allowlist'::regclass
      AND attname = 'user_id'
      AND NOT attisdropped;

    IF v_attnum IS NULL THEN
        RAISE EXCEPTION 'Column user_id missing on public.sarvex_admin_allowlist';
    END IF;

    -- 1. Check for ANY existing UNIQUE constraint covering exactly (user_id)
    SELECT conname INTO v_existing_conname
    FROM pg_constraint
    WHERE conrelid = 'public.sarvex_admin_allowlist'::regclass
      AND contype = 'u'
      AND conkey = ARRAY[v_attnum];

    IF v_existing_conname IS NOT NULL THEN
        RAISE NOTICE 'Unique constraint % already covers sarvex_admin_allowlist(user_id)', v_existing_conname;
        RETURN;
    END IF;

    -- 2. Pre-check duplicate non-null user_ids (STRICT ZERO DATA LOSS)
    SELECT count(*) INTO v_dup_uids
    FROM (
        SELECT user_id
        FROM public.sarvex_admin_allowlist
        WHERE user_id IS NOT NULL
        GROUP BY user_id
        HAVING count(*) > 1
    ) d;

    IF v_dup_uids > 0 THEN
        RAISE EXCEPTION 'Cannot add unique constraint: found % duplicate non-null user_id assignments in sarvex_admin_allowlist. Manual remediation required.', v_dup_uids;
    END IF;

    -- 3. Verify target name collision on constraint or class
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.sarvex_admin_allowlist'::regclass
          AND conname = 'sarvex_admin_allowlist_user_id_key'
    ) OR EXISTS (
        SELECT 1 FROM pg_class
        WHERE relname = 'sarvex_admin_allowlist_user_id_key'
          AND relnamespace = 'public'::regnamespace
    ) THEN
        RAISE EXCEPTION 'Identifier sarvex_admin_allowlist_user_id_key already exists with mismatched definition';
    END IF;

    -- 4. Add constraint safely
    ALTER TABLE public.sarvex_admin_allowlist
        ADD CONSTRAINT sarvex_admin_allowlist_user_id_key
        UNIQUE (user_id);

    RAISE NOTICE 'Added constraint sarvex_admin_allowlist_user_id_key successfully';
END $$;

-- ============================================================================
-- 8. PERFORMANCE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_products_seller_shop ON public.products(seller_shop_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_owner ON public.cart_items(owner_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON public.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_seller_shop ON public.order_items(seller_shop_id);
CREATE INDEX IF NOT EXISTS idx_reviews_product ON public.reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer ON public.reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_review_votes_rev_user ON public.review_helpful_votes(review_id, user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_owner ON public.wishlist_items(owner_id);

-- ============================================================================
-- 9. SECURED VIEWS WITH IN-PLACE REPLACEMENT & ZERO-CASCADE DEPENDENCY SAFETY
-- Preserves existing view OIDs, grants, and object dependencies in-place.
-- Strips financial and sensitive columns safely. Drops with CASCADE are strictly prohibited.
-- ============================================================================
DO $$
DECLARE
  v_view_oid oid;
  v_dep_count int;
  v_dep_names text;
  v_existing_cols text[];
  v_views_to_check RECORD;
BEGIN
  -- Forward stub for is_sarvex_admin to allow view definition/replacement prior to section 10
  CREATE OR REPLACE FUNCTION public.is_sarvex_admin() RETURNS BOOLEAN LANGUAGE sql AS 'SELECT false;';

  -- Inspect each managed view to ensure compatible in-place replacement and dependency safety
  FOR v_views_to_check IN (
    SELECT 'profiles' AS viewname,
           ARRAY['id', 'user_id', 'full_name', 'email', 'phone', 'role', 'avatar_url', 'created_at']::text[] AS expected_cols
    UNION ALL
    SELECT 'sellers' AS viewname,
           ARRAY['id', 'user_id', 'store_name', 'owner_name', 'city', 'state', 'pincode', 'status', 'rating', 'created_at']::text[] AS expected_cols
    UNION ALL
    SELECT 'seller_order_items_view' AS viewname,
           ARRAY['id', 'order_id', 'product_id', 'seller_id', 'quantity', 'unit_price', 'item_subtotal', 'item_status', 'order_date', 'delivery_address', 'delivery_city', 'delivery_state', 'delivery_pincode', 'delivery_phone', 'delivery_name']::text[] AS expected_cols
  ) LOOP
    SELECT c.oid INTO v_view_oid
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = v_views_to_check.viewname AND c.relkind = 'v';

    IF v_view_oid IS NOT NULL THEN
      -- Fetch current column names of the existing view ordered by attnum
      SELECT array_agg(a.attname ORDER BY a.attnum) INTO v_existing_cols
      FROM pg_attribute a
      WHERE a.attrelid = v_view_oid AND a.attnum > 0 AND NOT a.attisdropped;

      -- Check external objects depending on this view
      SELECT count(*), string_agg(coalesce(c.relname, p.proname, d.objid::text), ', ')
      INTO v_dep_count, v_dep_names
      FROM pg_depend d
      LEFT JOIN pg_rewrite rw ON rw.oid = d.objid
      LEFT JOIN pg_class c ON c.oid = rw.ev_class
      LEFT JOIN pg_proc p ON p.oid = d.objid
      WHERE d.refobjid = v_view_oid
        AND d.refclassid = 'pg_class'::regclass
        AND d.deptype = 'n'
        AND (rw.ev_class IS NULL OR rw.ev_class <> v_view_oid);

      -- If column signatures differ, PostgreSQL CREATE OR REPLACE VIEW cannot replace in-place (42P16)
      IF v_existing_cols IS DISTINCT FROM v_views_to_check.expected_cols THEN
        IF v_dep_count > 0 THEN
          RAISE EXCEPTION 'Cannot replace view public.%: existing view has incompatible columns (current: %, expected: %) and % dependent object(s) [%] depend on it. Manual migration required to avoid breaking dependencies. DROP CASCADE is strictly prohibited.',
            v_views_to_check.viewname, v_existing_cols, v_views_to_check.expected_cols, v_dep_count, v_dep_names
            USING ERRCODE = '2BP01';
        ELSE
          -- 0 dependencies: safe to drop cleanly without CASCADE and recreate
          EXECUTE format('DROP VIEW public.%I', v_views_to_check.viewname);
          RAISE NOTICE 'Dropped existing view public.% with incompatible columns cleanly (0 dependencies existed)', v_views_to_check.viewname;
        END IF;
      ELSE
        -- Columns match perfectly: in-place replacement will succeed, preserving view OID, dependencies, and grants
        RAISE NOTICE 'View public.% column structure is compatible. Preserving view OID, dependencies, and grants via in-place replacement.', v_views_to_check.viewname;
      END IF;
    END IF;
  END LOOP;
END $$;

CREATE OR REPLACE VIEW public.profiles
WITH (security_invoker = true) AS
  SELECT id, owner_id AS user_id, display_name AS full_name, email, phone, account_role AS role, avatar_url, created_at
  FROM public.customer_profiles;

CREATE OR REPLACE VIEW public.sellers
WITH (security_barrier = true, security_invoker = true) AS
  SELECT
    id,
    owner_id AS user_id,
    shop_name AS store_name,
    owner_name,
    city,
    state,
    pincode,
    approval_status AS status,
    rating,
    created_at
  FROM public.seller_shops
  WHERE approval_status = 'approved';

ALTER VIEW public.sellers OWNER TO postgres;

CREATE OR REPLACE VIEW public.seller_order_items_view
WITH (security_barrier = true, security_invoker = true) AS
  SELECT
    oi.id,
    oi.order_id,
    oi.product_id,
    oi.seller_shop_id AS seller_id,
    oi.quantity,
    oi.price_inr AS unit_price,
    (oi.price_inr * oi.quantity) AS item_subtotal,
    oi.item_status,
    o.created_at AS order_date,
    o.shipping_address AS delivery_address,
    o.city AS delivery_city,
    o.state AS delivery_state,
    o.pincode AS delivery_pincode,
    o.customer_phone AS delivery_phone,
    o.customer_name AS delivery_name
  FROM public.order_items oi
  JOIN public.orders o ON o.id = oi.order_id
  JOIN public.seller_shops s ON s.id = oi.seller_shop_id
  WHERE (
    (s.owner_id = auth.uid() AND s.approval_status = 'approved')
    OR public.is_sarvex_admin()
  );

ALTER VIEW public.seller_order_items_view OWNER TO postgres;

-- ============================================================================
-- 10. SECURITY DEFINER FUNCTIONS (WITH EXPLICIT search_path & ROLE RESTRICTIONS)
-- ============================================================================

-- A. is_sarvex_admin(): Hardened admin verification requiring verified email & trusted identity
CREATE OR REPLACE FUNCTION public.is_sarvex_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_uid UUID;
  v_jwt_role TEXT;
  v_email TEXT;
  v_confirmed TIMESTAMPTZ;
  v_is_admin BOOLEAN := FALSE;
BEGIN
  -- 1. Direct administrative session via psql / CLI (outside HTTP PostgREST context)
  IF session_user IN ('postgres', 'supabase_admin')
     AND current_setting('request.jwt.claim.role', true) IS NULL THEN
    RETURN TRUE;
  END IF;

  -- 2. Supabase internal service_role backend operations
  BEGIN
    v_jwt_role := current_setting('request.jwt.claim.role', true);
  EXCEPTION WHEN OTHERS THEN
    v_jwt_role := NULL;
  END;

  IF v_jwt_role = 'service_role' THEN
    RETURN TRUE;
  END IF;

  -- 3. Authenticated client caller check (fails closed for anonymous callers)
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 4. Verified email from trusted auth.users table
  SELECT email, email_confirmed_at
  INTO v_email, v_confirmed
  FROM auth.users
  WHERE id = v_uid;

  IF v_email IS NULL OR v_confirmed IS NULL THEN
    RETURN FALSE;
  END IF;

  -- 5. Strict Allowlist match: Bound UID + matching normalized email
  -- Database-side instant revocation: removing user_id or row instantly revokes admin status
  SELECT EXISTS (
    SELECT 1
    FROM public.sarvex_admin_allowlist a
    WHERE a.user_id = v_uid
      AND lower(trim(a.email)) = lower(trim(v_email))
  ) INTO v_is_admin;

  RETURN COALESCE(v_is_admin, FALSE);
END;
$$;

-- B. claim_sarvex_admin_seat(): Atomic first-claim of allowlist seat with 64-bit advisory locking
DO $$
DECLARE
    v_func_oid oid;
    v_ret_typename text;
    v_dep_count int;
BEGIN
    SELECT p.oid, t.typname
    INTO v_func_oid, v_ret_typename
    FROM pg_proc p
    JOIN pg_type t ON t.oid = p.prorettype
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'claim_sarvex_admin_seat'
      AND p.pronargs = 0;

    -- Only drop if an existing conflicting return type requires it for 42P13 avoidance
    IF v_func_oid IS NOT NULL AND v_ret_typename <> 'jsonb' THEN
        -- Inspect dependent objects where claim_sarvex_admin_seat is the referenced object
        SELECT count(*) INTO v_dep_count
        FROM pg_depend d
        WHERE d.refobjid = v_func_oid
          AND d.refclassid = 'pg_proc'::regclass
          AND d.deptype IN ('n', 'a');

        IF v_dep_count > 0 THEN
            RAISE EXCEPTION 'Cannot drop legacy claim_sarvex_admin_seat: % dependent database object(s) depend on this function. Manual migration required.', v_dep_count;
        END IF;

        DROP FUNCTION public.claim_sarvex_admin_seat();
        RAISE NOTICE 'Dropped legacy signature of claim_sarvex_admin_seat (returned %) to allow upgrade to jsonb', v_ret_typename;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.claim_sarvex_admin_seat()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
    v_caller_uid uuid;
    v_caller_email text;
    v_norm_email text;
    v_email_confirmed timestamptz;
    v_existing_seat_id uuid;
    v_target_seat_id uuid;
    v_updated_rows int;
BEGIN
    v_caller_uid := auth.uid();
    IF v_caller_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required', 'code', '42501');
    END IF;

    -- Fetch trusted email and confirmed timestamp from auth.users
    SELECT email, email_confirmed_at
    INTO v_caller_email, v_email_confirmed
    FROM auth.users
    WHERE id = v_caller_uid;

    IF v_caller_email IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User record missing in auth.users', 'code', '42501');
    END IF;

    IF v_email_confirmed IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Email verification required before claiming administrator seat', 'code', '42501');
    END IF;

    v_norm_email := lower(trim(v_caller_email));

    -- Acquire 64-bit transaction-level advisory lock on normalized email hash to serialize claims
    PERFORM pg_advisory_xact_lock(hashtextextended('sarvex_admin_claim:' || v_norm_email, 0));

    -- Post-lock Check 1: Does caller already hold a bound seat?
    SELECT id INTO v_existing_seat_id
    FROM public.sarvex_admin_allowlist
    WHERE user_id = v_caller_uid
    LIMIT 1;

    IF v_existing_seat_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_claimed', true,
            'seat_id', v_existing_seat_id,
            'message', 'Admin seat is already bound to your account.'
        );
    END IF;

    -- Post-lock Check 2: Find earliest unclaimed seat for this normalized email
    SELECT id INTO v_target_seat_id
    FROM public.sarvex_admin_allowlist
    WHERE lower(trim(email)) = v_norm_email
      AND user_id IS NULL
    ORDER BY created_at ASC, id ASC
    LIMIT 1
    FOR UPDATE;

    IF v_target_seat_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No unclaimed admin seat available for this verified email.',
            'code', '42501'
        );
    END IF;

    -- Atomic assignment (sarvex_admin_allowlist schema has: id UUID, user_id UUID, email TEXT, created_at TIMESTAMPTZ)
    UPDATE public.sarvex_admin_allowlist
    SET user_id = v_caller_uid
    WHERE id = v_target_seat_id
      AND user_id IS NULL;

    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
    IF v_updated_rows != 1 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Concurrent modification detected during seat claim',
            'code', '40001'
        );
    END IF;

    -- Synchronize customer profile account_role with confirmed admin status
    UPDATE public.customer_profiles
    SET account_role = 'admin'
    WHERE owner_id = v_caller_uid;

    RETURN jsonb_build_object(
        'success', true,
        'already_claimed', false,
        'seat_id', v_target_seat_id,
        'email', v_norm_email,
        'message', 'Admin seat claimed successfully.'
    );
END;
$$;

ALTER FUNCTION public.claim_sarvex_admin_seat() OWNER TO postgres;

-- A3. bootstrap_first_admin(): Atomic bootstrap of the very first platform administrator
DO $$
DECLARE
    v_func_oid oid;
    v_ret_typename text;
BEGIN
    SELECT p.oid, t.typname
    INTO v_func_oid, v_ret_typename
    FROM pg_proc p
    JOIN pg_type t ON t.oid = p.prorettype
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'bootstrap_first_admin'
      AND p.pronargs = 0;

    IF v_func_oid IS NOT NULL AND v_ret_typename <> 'jsonb' THEN
        DROP FUNCTION public.bootstrap_first_admin();
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.bootstrap_first_admin()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_caller_uid UUID;
  v_caller_email TEXT;
  v_email_confirmed TIMESTAMPTZ;
  v_existing_admin_count INTEGER;
BEGIN
  -- Security check: Restrict execution strictly to service_role or database superuser
  IF (session_user NOT IN ('postgres', 'supabase_admin') AND COALESCE(current_setting('request.jwt.claim.role', true), '') != 'service_role') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Security Exception: bootstrap_first_admin is restricted to service_role or database administrator.',
      'code', '42501'
    );
  END IF;

  v_caller_uid := auth.uid();
  IF v_caller_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required', 'code', '42501');
  END IF;

  -- 1. Fetch trusted caller email and confirmed timestamp from auth.users
  SELECT email, email_confirmed_at
  INTO v_caller_email, v_email_confirmed
  FROM auth.users
  WHERE id = v_caller_uid;

  IF v_caller_email IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User record missing in auth.users', 'code', '42501');
  END IF;

  IF v_email_confirmed IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Email verification required before bootstrapping administrator', 'code', '42501');
  END IF;

  -- 2. Concurrency Control: Acquire EXCLUSIVE table lock on sarvex_admin_allowlist
  -- This serializes any concurrent first-admin bootstrap attempts so only one can succeed
  LOCK TABLE public.sarvex_admin_allowlist IN EXCLUSIVE MODE;

  -- 3. Check if ANY administrator already exists in allowlist
  SELECT count(*) INTO v_existing_admin_count
  FROM public.sarvex_admin_allowlist;

  IF v_existing_admin_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Platform administrator bootstrapping is permanently closed. Administrator(s) already exist.',
      'code', '42501'
    );
  END IF;

  -- 4. Insert caller into allowlist
  INSERT INTO public.sarvex_admin_allowlist (id, user_id, email, created_at)
  VALUES (gen_random_uuid(), v_caller_uid, lower(trim(v_caller_email)), NOW());

  -- 5. Synchronize customer profile account_role
  UPDATE public.customer_profiles
  SET account_role = 'admin'
  WHERE owner_id = v_caller_uid;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Initial platform administrator seat claimed successfully.',
    'email', lower(trim(v_caller_email))
  );
END;
$$;

ALTER FUNCTION public.bootstrap_first_admin() OWNER TO postgres;

-- B. is_seller_shop_owner(check_shop_id): Server-side verified shop ownership AND approval enforcement
CREATE OR REPLACE FUNCTION public.is_seller_shop_owner(check_shop_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT (
    auth.uid() IS NOT NULL
    AND check_shop_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.seller_shops
      WHERE id = check_shop_id
        AND owner_id = auth.uid()
        AND approval_status = 'approved'
    )
  ) OR public.is_sarvex_admin();
$$;

-- B2. is_approved_seller_shop(check_shop_id): Safe public helper for product discovery without exposing seller_shops
CREATE OR REPLACE FUNCTION public.is_approved_seller_shop(check_shop_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT check_shop_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.seller_shops
    WHERE id = check_shop_id
      AND approval_status = 'approved'
  );
$$;

ALTER FUNCTION public.is_approved_seller_shop(UUID) OWNER TO postgres;

-- C. has_verified_purchase(check_customer_id, check_product_id): Privacy-hardened purchase verification
CREATE OR REPLACE FUNCTION public.has_verified_purchase(check_customer_id UUID, check_product_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_caller_uid UUID;
BEGIN
  IF check_customer_id IS NULL OR check_product_id IS NULL THEN
    RETURN FALSE;
  END IF;

  v_caller_uid := auth.uid();

  -- Direct psql administrative session or service_role or Sarvex admin
  IF (session_user IN ('postgres', 'supabase_admin') AND current_setting('request.jwt.claim.role', true) IS NULL)
     OR current_setting('request.jwt.claim.role', true) = 'service_role'
     OR public.is_sarvex_admin() THEN
    NULL;
  ELSIF v_caller_uid IS NOT NULL AND v_caller_uid = check_customer_id THEN
    -- Normal authenticated caller verifying their own purchase
    NULL;
  ELSE
    -- Privacy protection: Reject caller attempting to probe another customer's purchases (Zero oracle leak)
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.orders o
    JOIN public.order_items oi ON oi.order_id = o.id
    WHERE o.customer_id = check_customer_id
      AND oi.product_id = check_product_id
      AND o.status = 'delivered'
      AND oi.item_status = 'delivered'
  );
END;
$$;

-- D. order_has_seller_item(check_order_id UUID): Recursion-free seller order header check
CREATE OR REPLACE FUNCTION public.order_has_seller_item(check_order_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.order_items oi
    JOIN public.seller_shops s ON s.id = oi.seller_shop_id
    WHERE oi.order_id = check_order_id
      AND s.owner_id = auth.uid()
      AND auth.uid() IS NOT NULL
  );
$$;

-- E. is_order_customer(check_order_id UUID): Recursion-free customer order item check
CREATE OR REPLACE FUNCTION public.is_order_customer(check_order_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.orders
    WHERE id = check_order_id
      AND customer_id = auth.uid()
      AND auth.uid() IS NOT NULL
  );
$$;

-- ============================================================================
-- 11. RECURSION-FREE IN-MEMORY VALIDATION TRIGGERS (OLD vs NEW)
-- ============================================================================

-- A. Trigger on customer_profiles: Prevent modifying account_role & ownership
CREATE OR REPLACE FUNCTION public.protect_customer_account_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_is_admin BOOLEAN := FALSE;
  v_has_approved_shop BOOLEAN := FALSE;
BEGIN
  v_is_admin := public.is_sarvex_admin();

  IF TG_OP = 'INSERT' THEN
    -- Only permitted roles: 'customer', 'seller', 'admin'
    IF NEW.account_role NOT IN ('customer', 'seller', 'admin') OR NEW.account_role IS NULL THEN
      NEW.account_role := 'customer';
    END IF;

    -- Block self-granting admin on insert
    IF NEW.account_role = 'admin' AND NOT v_is_admin THEN
      NEW.account_role := 'customer';
    END IF;

    -- Block self-granting seller on insert without verified approved shop
    IF NEW.account_role = 'seller' AND NOT v_is_admin THEN
      SELECT EXISTS (
        SELECT 1 FROM public.seller_shops
        WHERE owner_id = NEW.owner_id AND approval_status = 'approved'
      ) INTO v_has_approved_shop;

      IF NOT v_has_approved_shop THEN
        NEW.account_role := 'customer';
      END IF;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    -- Validate permitted role values
    IF NEW.account_role NOT IN ('customer', 'seller', 'admin') THEN
      RAISE EXCEPTION 'Invalid account_role "%": permitted values are customer, seller, admin.', NEW.account_role;
    END IF;

    -- Prevent profile ownership transfer
    IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND NOT v_is_admin THEN
      RAISE EXCEPTION 'Security Exception: Profile ownership cannot be transferred.';
    END IF;

    -- Role transition checks for non-administrators
    IF NEW.account_role IS DISTINCT FROM OLD.account_role AND NOT v_is_admin THEN
      IF NEW.account_role = 'admin' THEN
        RAISE EXCEPTION 'Security Exception: Admin role cannot be acquired via profile update. Must claim via admin allowlist.';
      ELSIF NEW.account_role = 'seller' THEN
        SELECT EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = NEW.owner_id AND approval_status = 'approved'
        ) INTO v_has_approved_shop;

        IF NOT v_has_approved_shop THEN
          RAISE EXCEPTION 'Security Exception: Seller role requires an approved seller store.';
        END IF;
      ELSIF NEW.account_role = 'customer' THEN
        -- Allow demotion to customer
        NULL;
      ELSE
        RAISE EXCEPTION 'Security Exception: account_role modification is restricted to SARVEX Administrators.';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_customer_account_role ON public.customer_profiles;
CREATE TRIGGER trg_protect_customer_account_role
  BEFORE INSERT OR UPDATE ON public.customer_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_customer_account_role();

-- B. Trigger on seller_shops: Block altering approval_status, owner_id, commission_rate, rating, and approved banking fields
CREATE OR REPLACE FUNCTION public.protect_seller_shop_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF NOT public.is_sarvex_admin() THEN
    IF TG_OP = 'INSERT' THEN
      -- Force pending status, default platform commission (10%), 0.0 initial rating, and caller ownership on registration
      NEW.approval_status := 'pending';
      NEW.commission_rate := 10.0;
      NEW.rating := 0.0;
      NEW.owner_id := auth.uid();
      IF NEW.owner_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to register a seller store.'
          USING ERRCODE = '42501';
      END IF;

    ELSIF TG_OP = 'UPDATE' THEN
      -- 1. Block changing approval_status
      IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
        RAISE EXCEPTION 'Security Exception: Only SARVEX administrators can alter shop approval_status.'
          USING ERRCODE = '42501';
      END IF;

      -- 2. Block transferring shop ownership
      IF NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
        RAISE EXCEPTION 'Security Exception: Shop ownership transfer is restricted to administrators.'
          USING ERRCODE = '42501';
      END IF;

      -- 3. Block modifying commission_rate
      IF NEW.commission_rate IS DISTINCT FROM OLD.commission_rate THEN
        RAISE EXCEPTION 'Security Exception: Sellers cannot modify their platform commission rate.'
          USING ERRCODE = '42501';
      END IF;

      -- 4. Block modifying seller rating directly
      IF NEW.rating IS DISTINCT FROM OLD.rating THEN
        RAISE EXCEPTION 'Security Exception: Sellers cannot alter shop rating.'
          USING ERRCODE = '42501';
      END IF;

      -- 5. Block tampering with verified banking info once approved
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

DROP TRIGGER IF EXISTS trg_protect_seller_shop_status ON public.seller_shops;
CREATE TRIGGER trg_protect_seller_shop_status
  BEFORE INSERT OR UPDATE ON public.seller_shops
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_seller_shop_status();

-- C. Trigger on order_items: Sellers can ONLY alter item_status to permitted transitions
CREATE OR REPLACE FUNCTION public.protect_order_item_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_caller_uid UUID;
  v_shop_owner UUID;
  v_shop_status TEXT;
BEGIN
  -- 1. Direct psql/CLI administrative session bypass
  IF session_user IN ('postgres', 'supabase_admin')
     AND current_setting('request.jwt.claim.role', true) IS NULL THEN
    RETURN NEW;
  END IF;

  -- 2. Supabase internal service_role backend operations bypass
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- 3. Sarvex Administrator bypass (Allowlist verified)
  IF public.is_sarvex_admin() THEN
    RETURN NEW;
  END IF;

  -- 4. Authenticated caller check (fails closed for anonymous callers)
  v_caller_uid := auth.uid();
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to update order items'
      USING ERRCODE = '42501';
  END IF;

  -- 5. Deadlock mitigation: Acquire row lock on seller_shops with FOR SHARE NOWAIT
  -- Prevents circular deadlock with concurrent admin suspension transactions
  BEGIN
    SELECT owner_id, approval_status
    INTO v_shop_owner, v_shop_status
    FROM public.seller_shops
    WHERE id = OLD.seller_shop_id
    FOR SHARE NOWAIT;
  EXCEPTION
    WHEN lock_not_available THEN
      RAISE EXCEPTION 'Seller shop record is currently being updated by platform administration. Please retry shortly.'
        USING ERRCODE = '55P03';
  END;

  -- 6. Verify seller ownership using verified owner_id column
  IF v_shop_owner IS NULL OR v_shop_owner != v_caller_uid THEN
    RAISE EXCEPTION 'Unauthorized: You do not own the shop associated with this order item'
      USING ERRCODE = '42501';
  END IF;

  -- 7. Verify shop approval status
  IF v_shop_status != 'approved' THEN
    RAISE EXCEPTION 'Forbidden: Seller shop is currently %, order items cannot be updated', v_shop_status
      USING ERRCODE = '42501';
  END IF;

  -- 8. Dynamic JSONB column immutability: sellers may ONLY modify item_status
  -- Automatically protects all current and future schema columns against unauthorized mutation
  IF (to_jsonb(NEW) - 'item_status') IS DISTINCT FROM (to_jsonb(OLD) - 'item_status') THEN
    RAISE EXCEPTION 'Security Exception: Sellers are restricted to modifying item_status only. All item details, pricing, product and order references are immutable.'
      USING ERRCODE = '42501';
  END IF;

  -- 9. Explicit NULL check for item_status (prevents three-valued logic bypass)
  IF NEW.item_status IS NULL THEN
    RAISE EXCEPTION 'Security Exception: Order item status cannot be NULL.'
      USING ERRCODE = '23502';
  END IF;

  -- If status is identical, allow without transition error
  IF NEW.item_status = OLD.item_status THEN
    RETURN NEW;
  END IF;

  -- 10. Strict seller status transition state machine
  -- Permitted seller transitions:
  --   placed -> confirmed
  --   placed -> cancelled
  --   confirmed -> packed
  --   confirmed -> shipped
  --   confirmed -> cancelled
  --   packed -> shipped
  --   packed -> cancelled
  -- All other transitions (including to/from out_for_delivery, delivered) are restricted to admin/logistics
  IF OLD.item_status = 'placed' AND NEW.item_status IN ('confirmed', 'cancelled') THEN
    RETURN NEW;
  ELSIF OLD.item_status = 'confirmed' AND NEW.item_status IN ('packed', 'shipped', 'cancelled') THEN
    RETURN NEW;
  ELSIF OLD.item_status = 'packed' AND NEW.item_status IN ('shipped', 'cancelled') THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Invalid status transition by seller: cannot transition from % to %',
      OLD.item_status, NEW.item_status
      USING ERRCODE = '22023';
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_order_item_fields ON public.order_items;
CREATE TRIGGER trg_protect_order_item_fields
  BEFORE UPDATE ON public.order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_order_item_fields();

-- D. Trigger on products: Protect system-controlled fields (rating, rating_count, is_featured, badge) & shop assignment
CREATE OR REPLACE FUNCTION public.protect_product_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  -- 1. Direct psql/CLI administrative session, service_role or Sarvex admin bypass
  IF (session_user IN ('postgres', 'supabase_admin') AND current_setting('request.jwt.claim.role', true) IS NULL)
     OR current_setting('request.jwt.claim.role', true) = 'service_role'
     OR public.is_sarvex_admin() THEN
    RETURN NEW;
  END IF;

  -- 2. Seller operations
  IF TG_OP = 'INSERT' THEN
    -- Enforce initial system baselines
    NEW.rating := 0.0;
    NEW.rating_count := 0;
    NEW.is_featured := FALSE;
    NEW.badge := NULL;
    NEW.created_at := NOW();
    NEW.updated_at := NOW();

    -- Verify seller ownership and approval
    IF NOT public.is_seller_shop_owner(NEW.seller_shop_id) THEN
      RAISE EXCEPTION 'Security Exception: Cannot create products for a shop you do not own or an unapproved shop.'
        USING ERRCODE = '42501';
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    -- Immutable identifiers and timestamps
    NEW.id := OLD.id;
    NEW.created_at := OLD.created_at;

    -- Relational proof of authorization: If rating or rating_count changed, verify against public.reviews
    IF NEW.rating IS DISTINCT FROM OLD.rating OR NEW.rating_count IS DISTINCT FROM OLD.rating_count THEN
      DECLARE
        v_auth_avg numeric;
        v_auth_count integer;
      BEGIN
        SELECT COALESCE(ROUND(AVG(rating)::numeric, 1), 0.0), COUNT(*)::integer
        INTO v_auth_avg, v_auth_count
        FROM public.reviews
        WHERE product_id = OLD.id;

        IF NEW.rating = v_auth_avg AND NEW.rating_count = v_auth_count THEN
          -- Valid authoritative update from review sync
          NULL;
        ELSE
          RAISE EXCEPTION 'Security Exception: Product rating and rating_count can only be updated to match verified review aggregates.'
            USING ERRCODE = '42501';
        END IF;
      END;
    END IF;

    -- If other fields changed, seller ownership and immutability checks apply
    IF (to_jsonb(NEW) - 'rating' - 'rating_count' - 'updated_at') IS DISTINCT FROM (to_jsonb(OLD) - 'rating' - 'rating_count' - 'updated_at') THEN
      -- Verify seller ownership
      IF NOT public.is_seller_shop_owner(OLD.seller_shop_id) THEN
        RAISE EXCEPTION 'Security Exception: Cannot modify products belonging to another seller.'
          USING ERRCODE = '42501';
      END IF;

      -- Block moving product to another shop
      IF NEW.seller_shop_id IS DISTINCT FROM OLD.seller_shop_id THEN
        RAISE EXCEPTION 'Security Exception: Product shop assignment cannot be altered.'
          USING ERRCODE = '42501';
      END IF;

      IF NEW.is_featured IS DISTINCT FROM OLD.is_featured THEN
        RAISE EXCEPTION 'Security Exception: Only SARVEX administrators can designate featured products.'
          USING ERRCODE = '42501';
      END IF;

      IF NEW.badge IS DISTINCT FROM OLD.badge THEN
        RAISE EXCEPTION 'Security Exception: Only SARVEX administrators can alter product assurance badges.'
          USING ERRCODE = '42501';
      END IF;
    END IF;

    NEW.updated_at := NOW();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_product_fields ON public.products;
CREATE TRIGGER trg_protect_product_fields
  BEFORE INSERT OR UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_product_fields();

-- E. Trigger on reviews: Strict customer, product & verified buyer integrity
CREATE OR REPLACE FUNCTION public.protect_and_verify_review()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Force customer_id from authenticated session
    NEW.customer_id := auth.uid();
    IF NEW.customer_id IS NULL THEN
      RAISE EXCEPTION 'Authentication required to post a review.';
    END IF;

    -- Block sellers from reviewing products belonging to their own store
    IF EXISTS (
      SELECT 1 FROM public.products p
      JOIN public.seller_shops s ON s.id = p.seller_shop_id
      WHERE p.id = NEW.product_id AND s.owner_id = NEW.customer_id
    ) AND NOT public.is_sarvex_admin() THEN
      RAISE EXCEPTION 'Security Exception: Sellers are prohibited from reviewing products from their own store.'
        USING ERRCODE = '42501';
    END IF;

    -- Compute verified buyer status strictly from database orders
    NEW.is_verified_buyer := public.has_verified_purchase(NEW.customer_id, NEW.product_id);
    IF NOT NEW.is_verified_buyer AND NOT public.is_sarvex_admin() THEN
      RAISE EXCEPTION 'Only verified purchasers with a delivered order can review this product.';
    END IF;
    NEW.helpful_count := 0;

  ELSIF TG_OP = 'UPDATE' THEN
    IF NOT public.is_sarvex_admin() THEN
      IF NEW.customer_id IS DISTINCT FROM OLD.customer_id OR
         NEW.product_id IS DISTINCT FROM OLD.product_id OR
         NEW.is_verified_buyer IS DISTINCT FROM OLD.is_verified_buyer THEN
        RAISE EXCEPTION 'Security Exception: Immutable review fields cannot be altered.';
      END IF;

      -- Helpful count can ONLY be modified if it matches the authoritative review_helpful_votes table count, or if admin
      IF NEW.helpful_count IS DISTINCT FROM OLD.helpful_count THEN
        IF NOT public.is_sarvex_admin() THEN
          -- Relational proof of authorization: count must match authoritative review_helpful_votes table exactly
          IF NEW.helpful_count != (SELECT count(*) FROM public.review_helpful_votes WHERE review_id = NEW.id) THEN
            NEW.helpful_count := OLD.helpful_count;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_and_verify_review ON public.reviews;
CREATE TRIGGER trg_protect_and_verify_review
  BEFORE INSERT OR UPDATE ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_and_verify_review();

-- E. Trigger on reviews: Genuine average rating & count calculation
CREATE OR REPLACE FUNCTION public.sync_product_review_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  target_product_id UUID;
  avg_score NUMERIC;
  rev_count INTEGER;
BEGIN
  IF TG_OP = 'DELETE' THEN
    target_product_id := OLD.product_id;
  ELSE
    target_product_id := NEW.product_id;
  END IF;

  IF target_product_id IS NOT NULL THEN
    -- Concurrency Serialization: Lock target product row to serialize concurrent review aggregation
    PERFORM 1 FROM public.products WHERE id = target_product_id FOR UPDATE;

    SELECT COALESCE(ROUND(AVG(rating)::numeric, 1), 0.0), COUNT(*)
    INTO avg_score, rev_count
    FROM public.reviews
    WHERE product_id = target_product_id;

    UPDATE public.products
    SET rating = avg_score, rating_count = rev_count, updated_at = NOW()
    WHERE id = target_product_id;
  END IF;

  -- Recompute for OLD product if product reference changed on UPDATE
  IF TG_OP = 'UPDATE' AND OLD.product_id IS DISTINCT FROM NEW.product_id AND OLD.product_id IS NOT NULL THEN
    PERFORM 1 FROM public.products WHERE id = OLD.product_id FOR UPDATE;

    SELECT COALESCE(ROUND(AVG(rating)::numeric, 1), 0.0), COUNT(*)
    INTO avg_score, rev_count
    FROM public.reviews
    WHERE product_id = OLD.product_id;

    UPDATE public.products
    SET rating = avg_score, rating_count = rev_count, updated_at = NOW()
    WHERE id = OLD.product_id;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_product_reviews ON public.reviews;
CREATE TRIGGER trg_sync_product_reviews
  AFTER INSERT OR DELETE OR UPDATE OF rating, product_id ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_product_review_stats();

-- F. Trigger on review_helpful_votes: Synchronize reviews.helpful_count atomically without custom GUCs
CREATE OR REPLACE FUNCTION public.sync_review_helpful_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM 1 FROM public.reviews WHERE id = NEW.review_id FOR UPDATE;
    UPDATE public.reviews
    SET helpful_count = helpful_count + 1
    WHERE id = NEW.review_id;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM 1 FROM public.reviews WHERE id = OLD.review_id FOR UPDATE;
    UPDATE public.reviews
    SET helpful_count = GREATEST(0, helpful_count - 1)
    WHERE id = OLD.review_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_review_helpful_count ON public.review_helpful_votes;
CREATE TRIGGER trg_sync_review_helpful_count
  AFTER INSERT OR DELETE ON public.review_helpful_votes
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_review_helpful_count();

-- G. Trigger on order_items: Multi-vendor aggregate parent order status synchronization
CREATE OR REPLACE FUNCTION public.sync_parent_order_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_order_id UUID;
  v_total_count INTEGER;
  v_delivered_count INTEGER;
  v_out_for_delivery_count INTEGER;
  v_shipped_count INTEGER;
  v_packed_count INTEGER;
  v_confirmed_count INTEGER;
  v_cancelled_count INTEGER;
  v_new_status TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_order_id := OLD.order_id;
  ELSE
    v_order_id := NEW.order_id;
  END IF;

  IF v_order_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Concurrency Serialization: Lock parent order row to serialize concurrent order item updates
  PERFORM 1 FROM public.orders WHERE id = v_order_id FOR UPDATE;

  -- Compute counts of distinct item statuses for this parent order
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE item_status = 'delivered'),
    COUNT(*) FILTER (WHERE item_status = 'out_for_delivery'),
    COUNT(*) FILTER (WHERE item_status = 'shipped'),
    COUNT(*) FILTER (WHERE item_status = 'packed'),
    COUNT(*) FILTER (WHERE item_status = 'confirmed'),
    COUNT(*) FILTER (WHERE item_status = 'cancelled')
  INTO
    v_total_count,
    v_delivered_count,
    v_out_for_delivery_count,
    v_shipped_count,
    v_packed_count,
    v_confirmed_count,
    v_cancelled_count
  FROM public.order_items
  WHERE order_id = v_order_id;

  IF v_total_count = 0 THEN
    RETURN NULL;
  END IF;

  -- Multi-vendor rollup state machine:
  IF v_cancelled_count = v_total_count THEN
    v_new_status := 'cancelled';
  ELSIF (v_total_count - v_cancelled_count) > 0 AND v_delivered_count = (v_total_count - v_cancelled_count) THEN
    v_new_status := 'delivered';
  ELSIF (v_delivered_count + v_out_for_delivery_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
    v_new_status := 'out_for_delivery';
  ELSIF (v_delivered_count + v_out_for_delivery_count + v_shipped_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
    v_new_status := 'shipped';
  ELSIF (v_delivered_count + v_out_for_delivery_count + v_shipped_count + v_packed_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
    v_new_status := 'packed';
  ELSIF (v_delivered_count + v_out_for_delivery_count + v_shipped_count + v_packed_count + v_confirmed_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
    v_new_status := 'confirmed';
  ELSE
    v_new_status := 'placed';
  END IF;

  UPDATE public.orders
  SET status = v_new_status, updated_at = NOW()
  WHERE id = v_order_id AND status IS DISTINCT FROM v_new_status;

  -- Handle re-parenting if item was moved to a different order on UPDATE
  IF TG_OP = 'UPDATE' AND OLD.order_id IS DISTINCT FROM NEW.order_id AND OLD.order_id IS NOT NULL THEN
    PERFORM 1 FROM public.orders WHERE id = OLD.order_id FOR UPDATE;

    SELECT
      COUNT(*),
      COUNT(*) FILTER (WHERE item_status = 'delivered'),
      COUNT(*) FILTER (WHERE item_status = 'out_for_delivery'),
      COUNT(*) FILTER (WHERE item_status = 'shipped'),
      COUNT(*) FILTER (WHERE item_status = 'packed'),
      COUNT(*) FILTER (WHERE item_status = 'confirmed'),
      COUNT(*) FILTER (WHERE item_status = 'cancelled')
    INTO
      v_total_count,
      v_delivered_count,
      v_out_for_delivery_count,
      v_shipped_count,
      v_packed_count,
      v_confirmed_count,
      v_cancelled_count
    FROM public.order_items
    WHERE order_id = OLD.order_id;

    IF v_total_count > 0 THEN
      IF v_cancelled_count = v_total_count THEN
        v_new_status := 'cancelled';
      ELSIF (v_total_count - v_cancelled_count) > 0 AND v_delivered_count = (v_total_count - v_cancelled_count) THEN
        v_new_status := 'delivered';
      ELSIF (v_delivered_count + v_out_for_delivery_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
        v_new_status := 'out_for_delivery';
      ELSIF (v_delivered_count + v_out_for_delivery_count + v_shipped_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
        v_new_status := 'shipped';
      ELSIF (v_delivered_count + v_out_for_delivery_count + v_shipped_count + v_packed_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
        v_new_status := 'packed';
      ELSIF (v_delivered_count + v_out_for_delivery_count + v_shipped_count + v_packed_count + v_confirmed_count) = (v_total_count - v_cancelled_count) AND (v_total_count - v_cancelled_count) > 0 THEN
        v_new_status := 'confirmed';
      ELSE
        v_new_status := 'placed';
      END IF;

      UPDATE public.orders
      SET status = v_new_status, updated_at = NOW()
      WHERE id = OLD.order_id AND status IS DISTINCT FROM v_new_status;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_parent_order_status ON public.order_items;
CREATE TRIGGER trg_sync_parent_order_status
  AFTER INSERT OR DELETE OR UPDATE OF item_status, order_id ON public.order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_parent_order_status();

-- ============================================================================
-- 12. HARDENED TRANSACTIONAL CHECKOUT RPC
-- Authenticated COD only, seller approval check, collision-resistant code,
-- grouped item quantities, deterministic row locking, and server-side pricing.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.place_sarvex_order(
  p_customer_name TEXT,
  p_customer_phone TEXT,
  p_customer_email TEXT,
  p_shipping_address TEXT,
  p_city TEXT,
  p_state TEXT,
  p_pincode TEXT,
  p_items JSONB,
  p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_order_id UUID := gen_random_uuid();
  v_order_code TEXT;
  v_customer_id UUID;
  v_lock_time TIMESTAMPTZ;
  v_recent_orders_count INTEGER := 0;
  v_calculated_total NUMERIC := 0;
  v_unit_price NUMERIC;
  v_item_subtotal NUMERIC;
  v_commission_rate NUMERIC;
  v_commission_amount NUMERIC;
  v_seller_payable NUMERIC;
  v_group RECORD;
  v_prod RECORD;
  v_elem JSONB;
  v_attempts INTEGER := 0;
  v_constraint_name TEXT;
  v_cached_response JSONB;
  v_cached_hash TEXT;
  v_payload_hash TEXT;
  v_result JSONB;
  v_clean_key TEXT;
BEGIN
  -- 1. Authentication check: Mandatory authenticated checkout
  v_customer_id := auth.uid();
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required: You must be logged in with a SARVEX account to place an order.';
  END IF;

  -- 1a. Idempotency & Replay Protection (when idempotency key is provided)
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    v_clean_key := TRIM(p_idempotency_key);
    IF LENGTH(v_clean_key) > 128 THEN
      RAISE EXCEPTION 'Idempotency key must not exceed 128 characters.';
    END IF;

    -- Compute deterministic SHA-256 payload fingerprint
    v_payload_hash := encode(digest(
      TRIM(p_customer_name) || '|' ||
      TRIM(p_customer_phone) || '|' ||
      COALESCE(TRIM(p_customer_email), '') || '|' ||
      TRIM(p_shipping_address) || '|' ||
      TRIM(p_city) || '|' ||
      TRIM(p_state) || '|' ||
      TRIM(p_pincode) || '|' ||
      p_items::text,
      'sha256'
    ), 'hex');

    -- Serialize checkout execution on (customer_id, idempotency_key)
    PERFORM pg_advisory_xact_lock(hashtextextended('sarvex_order_idempotency:' || v_customer_id::text || ':' || v_clean_key, 0));

    -- Check existing idempotency record within 24-hour retention window
    SELECT response_payload, request_hash
    INTO v_cached_response, v_cached_hash
    FROM public.order_idempotency_keys
    WHERE customer_id = v_customer_id
      AND idempotency_key = v_clean_key
      AND created_at >= (NOW() - INTERVAL '24 hours');

    IF v_cached_response IS NOT NULL THEN
      -- If key was reused with a DIFFERENT payload, reject with 42804 error
      IF v_cached_hash IS NOT NULL AND v_cached_hash <> '' AND v_cached_hash <> v_payload_hash THEN
        RAISE EXCEPTION 'Idempotency key violation: The provided idempotency key was previously used with a different order request payload.'
          USING ERRCODE = '42804';
      END IF;
      -- Return cached response for identical idempotent replay
      RETURN v_cached_response;
    END IF;
  END IF;

  -- 1b. Per-customer transactional advisory lock & velocity check (abuse & fraud prevention)
  -- Applies to all orders (both 8-argument legacy and 9-argument calls)
  PERFORM pg_advisory_xact_lock(hashtextextended('sarvex_order_velocity:' || v_customer_id::text, 0));
  v_lock_time := clock_timestamp();

  SELECT count(*) INTO v_recent_orders_count
  FROM public.orders
  WHERE customer_id = v_customer_id
    AND created_at >= (v_lock_time - INTERVAL '10 minutes');

  IF v_recent_orders_count >= 5 THEN
    RAISE EXCEPTION 'SARVEX SECURITY: Order velocity limit exceeded (max 5 orders per 10 minutes). Please wait before placing another order.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 2. Input validation: Required non-empty fields, phone (10 digits), PIN (6 digits starting 1-9)
  IF p_customer_name IS NULL OR LENGTH(TRIM(p_customer_name)) = 0 OR LENGTH(TRIM(p_customer_name)) > 100 THEN
    RAISE EXCEPTION 'Customer name is required and must not exceed 100 characters.';
  END IF;
  IF p_customer_phone IS NULL OR TRIM(p_customer_phone) !~ '^[0-9]{10}$' THEN
    RAISE EXCEPTION 'Valid 10-digit customer phone number is required.';
  END IF;
  IF p_shipping_address IS NULL OR LENGTH(TRIM(p_shipping_address)) < 5 OR LENGTH(TRIM(p_shipping_address)) > 300 THEN
    RAISE EXCEPTION 'Detailed delivery address must be between 5 and 300 characters.';
  END IF;
  IF p_city IS NULL OR LENGTH(TRIM(p_city)) = 0 OR LENGTH(TRIM(p_city)) > 100 THEN
    RAISE EXCEPTION 'City is required and must not exceed 100 characters.';
  END IF;
  IF p_state IS NULL OR LENGTH(TRIM(p_state)) = 0 OR LENGTH(TRIM(p_state)) > 100 THEN
    RAISE EXCEPTION 'State is required and must not exceed 100 characters.';
  END IF;
  IF p_pincode IS NULL OR TRIM(p_pincode) !~ '^[1-9][0-9]{5}$' THEN
    RAISE EXCEPTION 'Valid 6-digit Indian PIN code is required (first digit must be 1-9).';
  END IF;

  -- Validate optional customer email format
  IF p_customer_email IS NOT NULL AND TRIM(p_customer_email) != '' THEN
    IF LENGTH(TRIM(p_customer_email)) > 150 OR
       TRIM(p_customer_email) !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
      RAISE EXCEPTION 'Invalid customer email address format.';
    END IF;
  END IF;

  -- Validate items JSON payload with sensible bounds (1 to 50 items)
  IF p_items IS NULL OR jsonb_typeof(p_items) != 'array' OR jsonb_array_length(p_items) = 0 OR jsonb_array_length(p_items) > 50 THEN
    RAISE EXCEPTION 'Cart must contain between 1 and 50 entries. Cannot place order.';
  END IF;

  -- Validate individual item elements for valid UUID syntax and bounded quantity (prevents integer overflow)
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_elem) != 'object' THEN
      RAISE EXCEPTION 'Each cart item must be a JSON object.';
    END IF;
    IF (v_elem->>'product_id') IS NULL OR
       (v_elem->>'product_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RAISE EXCEPTION 'Invalid or missing product_id UUID in cart items.';
    END IF;
    -- Strictly bounded regex prevents integer overflow before type casting
    IF (v_elem->>'quantity') IS NULL OR
       (v_elem->>'quantity') !~ '^[1-9][0-9]{0,2}$' OR
       (v_elem->>'quantity')::integer > 50 THEN
      RAISE EXCEPTION 'Invalid quantity in cart items: must be a positive integer between 1 and 50.';
    END IF;
  END LOOP;

  -- 3. Collision-resistant unique Order Code will be generated and validated in atomic retry loop in step 5.

  -- 4. Aggregate duplicate cart entries, lock rows deterministically, validate seller approval & stock
  FOR v_group IN
    SELECT
      (item->>'product_id')::UUID AS prod_id,
      SUM((item->>'quantity')::INTEGER) AS total_qty
    FROM jsonb_array_elements(p_items) AS item
    GROUP BY (item->>'product_id')::UUID
    ORDER BY (item->>'product_id')::UUID -- Prevents deadlocks under high concurrency
  LOOP
    IF v_group.total_qty <= 0 OR v_group.total_qty > 50 THEN
      RAISE EXCEPTION 'Invalid quantity: Total items per product must be between 1 and 50.';
    END IF;

    -- Row-level lock on product row joining seller_shops
    SELECT
      p.id,
      p.product_name,
      p.price_inr,
      p.stock_quantity,
      p.seller_shop_id,
      p.image_url,
      s.shop_name,
      s.approval_status AS seller_status,
      COALESCE(s.commission_rate, 10.0) AS commission_rate
    INTO v_prod
    FROM public.products p
    JOIN public.seller_shops s ON s.id = p.seller_shop_id
    WHERE p.id = v_group.prod_id
    FOR UPDATE OF p FOR SHARE OF s;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product with ID % does not exist or seller store was not found.', v_group.prod_id;
    END IF;

    -- Verify Seller Store is Approved (NULL-safe comparison)
    IF v_prod.seller_status IS DISTINCT FROM 'approved' THEN
      RAISE EXCEPTION 'Product "%" cannot be purchased because seller store "%" is not approved or active.',
        v_prod.product_name, v_prod.shop_name;
    END IF;

    -- Verify Stock: NULL stock is strictly invalid; requested quantity must be available
    IF v_prod.stock_quantity IS NULL OR v_prod.stock_quantity < v_group.total_qty THEN
      RAISE EXCEPTION 'Insufficient stock for "%". Available: %, Requested: %',
        v_prod.product_name, COALESCE(v_prod.stock_quantity::text, 'NULL'), v_group.total_qty;
    END IF;

    -- Authoritative final selling price strictly from products.price_inr (Loop 1)
    IF v_prod.price_inr IS NULL OR v_prod.price_inr <= 0 THEN
      RAISE EXCEPTION 'Invalid price configuration for product "%": price must be a positive number.', v_prod.product_name;
    END IF;

    v_unit_price := ROUND(v_prod.price_inr, 2);
    v_item_subtotal := ROUND(v_unit_price * v_group.total_qty, 2);
    v_calculated_total := v_calculated_total + v_item_subtotal;
  END LOOP;

  -- Ensure calculated order total is strictly positive
  IF v_calculated_total <= 0 THEN
    RAISE EXCEPTION 'Calculated order total must be a positive amount.';
  END IF;

  -- 5. Insert verified Order with Automatic Collision Retry Loop (SRX-YYMMDD-XXXXXXXXXX)
  v_attempts := 0;
  LOOP
    v_attempts := v_attempts + 1;
    v_order_code := 'SRX-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::text, '-', '') FROM 1 FOR 10));

    BEGIN
      INSERT INTO public.orders (
        id,
        order_code,
        customer_id,
        customer_name,
        customer_phone,
        customer_email,
        shipping_address,
        city,
        state,
        pincode,
        total_amount,
        payment_method,
        status
      ) VALUES (
        v_order_id,
        v_order_code,
        v_customer_id,
        TRIM(p_customer_name),
        TRIM(p_customer_phone),
        NULLIF(TRIM(p_customer_email), ''),
        TRIM(p_shipping_address),
        TRIM(p_city),
        TRIM(p_state),
        TRIM(p_pincode),
        v_calculated_total,
        'cod',
        'placed'
      );

      EXIT; -- Insert succeeded, exit retry loop
    EXCEPTION
      WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME;
        IF v_constraint_name IN ('orders_order_code_key', 'orders_code_key') THEN
          IF v_attempts >= 5 THEN
            RAISE EXCEPTION 'Failed to generate a unique order code after % attempts. Please try again.', v_attempts;
          END IF;
        ELSE
          RAISE; -- Re-raise other unique constraint violations immediately
        END IF;
    END;
  END LOOP;

  -- 6. Insert Order Items & Deduct Stock Atomically
  FOR v_group IN
    SELECT
      (item->>'product_id')::UUID AS prod_id,
      SUM((item->>'quantity')::INTEGER) AS total_qty
    FROM jsonb_array_elements(p_items) AS item
    GROUP BY (item->>'product_id')::UUID
    ORDER BY (item->>'product_id')::UUID
  LOOP
    SELECT
      p.id,
      p.product_name,
      p.price_inr,
      p.seller_shop_id,
      p.image_url,
      COALESCE(s.commission_rate, 10.0) AS commission_rate
    INTO v_prod
    FROM public.products p
    LEFT JOIN public.seller_shops s ON s.id = p.seller_shop_id
    WHERE p.id = v_group.prod_id;

    -- Authoritative final selling price strictly from products.price_inr (Loop 2 - identical to Loop 1)
    IF v_prod.price_inr IS NULL OR v_prod.price_inr <= 0 THEN
      RAISE EXCEPTION 'Invalid price configuration for product "%": price must be a positive number.', v_prod.product_name;
    END IF;

    v_unit_price := ROUND(v_prod.price_inr, 2);
    v_item_subtotal := ROUND(v_unit_price * v_group.total_qty, 2);
    v_commission_rate := COALESCE(v_prod.commission_rate, 10.0);
    v_commission_amount := ROUND((v_item_subtotal * v_commission_rate / 100.0), 2);
    v_seller_payable := v_item_subtotal - v_commission_amount;

    INSERT INTO public.order_items (
      id,
      order_id,
      product_id,
      seller_shop_id,
      product_name,
      price_inr,
      quantity,
      commission_rate,
      commission_amount,
      seller_payable_amount,
      image_url,
      item_status
    ) VALUES (
      gen_random_uuid(),
      v_order_id,
      v_prod.id,
      v_prod.seller_shop_id,
      v_prod.product_name,
      v_unit_price,
      v_group.total_qty,
      v_commission_rate,
      v_commission_amount,
      v_seller_payable,
      v_prod.image_url,
      'placed'
    );

    UPDATE public.products
    SET stock_quantity = stock_quantity - v_group.total_qty, updated_at = NOW()
    WHERE id = v_prod.id;
  END LOOP;

  -- 7. Clear customer cart
  DELETE FROM public.cart_items WHERE owner_id = v_customer_id;

  v_result := jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_code', v_order_code,
    'total_amount', v_calculated_total,
    'status', 'placed'
  );

  -- 8. Store idempotency record if client provided an explicit idempotency key
  IF v_clean_key IS NOT NULL THEN
    INSERT INTO public.order_idempotency_keys (
      idempotency_key, customer_id, order_id, request_hash, response_payload, created_at
    ) VALUES (
      v_clean_key, v_customer_id, v_order_id, v_payload_hash, v_result, NOW()
    )
    ON CONFLICT (customer_id, idempotency_key)
    DO UPDATE SET
      order_id = EXCLUDED.order_id,
      request_hash = EXCLUDED.request_hash,
      response_payload = EXCLUDED.response_payload,
      created_at = NOW();
  END IF;

  RETURN v_result;
END;
$$;

ALTER FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) OWNER TO postgres;

-- 8-argument backward-compatible overload forwarding to 9-argument procedure
CREATE OR REPLACE FUNCTION public.place_sarvex_order(
  p_customer_name TEXT,
  p_customer_phone TEXT,
  p_customer_email TEXT,
  p_shipping_address TEXT,
  p_city TEXT,
  p_state TEXT,
  p_pincode TEXT,
  p_items JSONB
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.place_sarvex_order(
    p_customer_name,
    p_customer_phone,
    p_customer_email,
    p_shipping_address,
    p_city,
    p_state,
    p_pincode,
    p_items,
    NULL
  );
$$;

ALTER FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) OWNER TO postgres;

-- ============================================================================
-- 13. SECURE HELPFUL VOTE RPC WITH DUPLICATE PROTECTION
-- ============================================================================
CREATE OR REPLACE FUNCTION public.vote_review_helpful(p_review_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
DECLARE
  v_uid UUID;
  v_author_id UUID;
  v_vote_id UUID;
  new_count INTEGER;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to vote on reviews.';
  END IF;

  IF p_review_id IS NULL THEN
    RAISE EXCEPTION 'Review ID is required.';
  END IF;

  -- Verify target review exists, lock row, and prevent author self-voting
  SELECT customer_id INTO v_author_id
  FROM public.reviews
  WHERE id = p_review_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Review not found.';
  END IF;

  IF v_author_id = v_uid THEN
    RAISE EXCEPTION 'Authors cannot vote their own reviews as helpful.';
  END IF;

  -- Atomic INSERT with duplicate prevention (ON CONFLICT DO NOTHING)
  INSERT INTO public.review_helpful_votes (id, review_id, user_id, created_at)
  VALUES (gen_random_uuid(), p_review_id, v_uid, NOW())
  ON CONFLICT (review_id, user_id) DO NOTHING
  RETURNING id INTO v_vote_id;

  IF v_vote_id IS NULL THEN
    RAISE EXCEPTION 'You have already voted this review as helpful.';
  END IF;

  -- Atomic synchronization of helpful_count is managed by the trg_sync_review_helpful_count
  -- trigger on public.review_helpful_votes, executing at trigger depth > 1 without custom GUCs.
  -- Fetch the authoritative count directly from public.reviews.
  SELECT helpful_count INTO new_count
  FROM public.reviews
  WHERE id = p_review_id;

  RETURN COALESCE(new_count, 0);
END;
$$;

-- ============================================================================
-- 14. EXPLICIT FUNCTION GRANTS & REVOCATIONS
-- ============================================================================
REVOKE ALL ON FUNCTION public.is_sarvex_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_sarvex_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_sarvex_admin() TO service_role;
-- Anon grant is strictly required so that public SELECT policies (e.g., on products and seller_shops)
-- can evaluate is_sarvex_admin(). The function returns FALSE for anon callers, preventing any escalation.
GRANT EXECUTE ON FUNCTION public.is_sarvex_admin() TO anon;

REVOKE ALL ON FUNCTION public.claim_sarvex_admin_seat() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_sarvex_admin_seat() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_sarvex_admin_seat() TO service_role;

REVOKE ALL ON FUNCTION public.bootstrap_first_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin() TO service_role;

REVOKE ALL ON FUNCTION public.is_seller_shop_owner(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_seller_shop_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_seller_shop_owner(UUID) TO service_role;
-- Anon grant is required so public SELECT policy on products can evaluate is_seller_shop_owner
GRANT EXECUTE ON FUNCTION public.is_seller_shop_owner(UUID) TO anon;

REVOKE ALL ON FUNCTION public.is_approved_seller_shop(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_approved_seller_shop(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_approved_seller_shop(UUID) TO service_role;
-- Anon grant is required so public SELECT policy on products can evaluate is_approved_seller_shop
GRANT EXECUTE ON FUNCTION public.is_approved_seller_shop(UUID) TO anon;

REVOKE ALL ON FUNCTION public.has_verified_purchase(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_verified_purchase(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_verified_purchase(UUID, UUID) TO service_role;

REVOKE ALL ON FUNCTION public.order_has_seller_item(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.order_has_seller_item(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.order_has_seller_item(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.order_has_seller_item(UUID) TO anon;

REVOKE ALL ON FUNCTION public.is_order_customer(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_order_customer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_order_customer(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.is_order_customer(UUID) TO anon;

-- place_sarvex_order: Strictly authenticated and service_role (NO anon execution)
REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) TO service_role;

REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.vote_review_helpful(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.vote_review_helpful(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_review_helpful(UUID) TO service_role;

-- Table & View Privileges: reset inherited/legacy grants before applying least privilege.
-- REVOKE ALL is essential: GRANT of a narrow set does not remove old explicit TRUNCATE/DDL grants.
REVOKE ALL ON TABLE
  public.seller_shops, public.customer_profiles, public.products, public.cart_items,
  public.orders, public.order_items, public.order_idempotency_keys, public.reviews,
  public.review_helpful_votes, public.wishlist_items, public.sarvex_admin_allowlist,
  public.categories
FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE ON TABLE public.seller_shops TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.customer_profiles TO authenticated;
GRANT SELECT ON TABLE public.products TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.products TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cart_items TO authenticated;
GRANT SELECT ON TABLE public.orders TO authenticated;
GRANT SELECT ON TABLE public.order_items TO authenticated;
GRANT UPDATE (item_status) ON TABLE public.order_items TO authenticated;
GRANT SELECT ON TABLE public.order_idempotency_keys TO authenticated;
GRANT SELECT ON TABLE public.reviews TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.reviews TO authenticated;
GRANT SELECT ON TABLE public.review_helpful_votes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.wishlist_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.sarvex_admin_allowlist TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.categories TO authenticated;
GRANT SELECT ON TABLE public.categories TO anon;

-- Public seller discovery exposes only the columns projected by the safe sellers view.
GRANT SELECT (id, shop_name, owner_name, city, state, pincode, approval_status, rating, created_at)
  ON TABLE public.seller_shops TO anon;

GRANT ALL ON TABLE
  public.seller_shops, public.customer_profiles, public.products, public.cart_items,
  public.orders, public.order_items, public.order_idempotency_keys, public.reviews,
  public.review_helpful_votes, public.wishlist_items, public.sarvex_admin_allowlist,
  public.categories
TO service_role;

-- Compatibility views execute with caller privileges and respect underlying RLS.
REVOKE ALL ON TABLE public.profiles, public.sellers, public.seller_order_items_view
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.sellers TO anon, authenticated;
GRANT SELECT ON TABLE public.seller_order_items_view TO authenticated;
GRANT ALL ON TABLE public.profiles, public.sellers, public.seller_order_items_view TO service_role;

-- Function privileges: only three read-only helpers are callable anonymously for public RLS.
REVOKE ALL ON FUNCTION public.is_sarvex_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_sarvex_admin() TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_seller_shop_owner(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_seller_shop_owner(UUID) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_approved_seller_shop(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_approved_seller_shop(UUID) TO anon, authenticated, service_role;

-- Authenticated-only helper/RPC functions; never expose order/purchase predicates to anon.
REVOKE ALL ON FUNCTION public.claim_sarvex_admin_seat() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_sarvex_admin_seat() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.has_verified_purchase(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_verified_purchase(UUID, UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.order_has_seller_item(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.order_has_seller_item(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_order_customer(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_order_customer(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, TEXT) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.vote_review_helpful(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vote_review_helpful(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.bootstrap_first_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_first_admin() TO service_role;

-- Trigger-only SECURITY DEFINER functions must not be callable as browser RPCs.
REVOKE ALL ON FUNCTION public.handle_new_sarvex_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_customer_account_role() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_seller_shop_status() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_product_fields() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_order_item_fields() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_and_verify_review() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_parent_order_status() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_product_review_stats() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_review_helpful_count() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_updated_at() FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- 15. ROW LEVEL SECURITY (RLS) POLICIES — IDEMPOTENT & RECURSION-FREE
-- ============================================================================

ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.seller_shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_shops FORCE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders FORCE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.order_idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_idempotency_keys FORCE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_helpful_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_helpful_votes FORCE ROW LEVEL SECURITY;
ALTER TABLE public.wishlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlist_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sarvex_admin_allowlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sarvex_admin_allowlist FORCE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- customer_profiles: Private access only (No public SELECT)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users view own profile or admin" ON public.customer_profiles;
CREATE POLICY "Users view own profile or admin"
  ON public.customer_profiles FOR SELECT
  USING (auth.uid() = owner_id OR public.is_sarvex_admin());

DROP POLICY IF EXISTS "Users can create their own profile" ON public.customer_profiles;
CREATE POLICY "Users can create their own profile"
  ON public.customer_profiles FOR INSERT
  WITH CHECK (
    auth.uid() = owner_id
    AND (account_role IS NULL OR account_role = 'customer' OR public.is_sarvex_admin())
  );

DROP POLICY IF EXISTS "Users can update their own profile details" ON public.customer_profiles;
CREATE POLICY "Users can update their own profile details"
  ON public.customer_profiles FOR UPDATE
  USING (auth.uid() = owner_id OR public.is_sarvex_admin())
  WITH CHECK (auth.uid() = owner_id OR public.is_sarvex_admin());

-- ----------------------------------------------------------------------------
-- seller_shops: Private access only (Owner & Admin only). Public discovery via public.sellers view.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public can view approved seller shops" ON public.seller_shops;
DROP POLICY IF EXISTS "Sellers and Admins view seller shops" ON public.seller_shops;
CREATE POLICY "Sellers and Admins view seller shops"
  ON public.seller_shops FOR SELECT
  USING ((auth.uid() IS NOT NULL AND owner_id = auth.uid()) OR public.is_sarvex_admin());

DROP POLICY IF EXISTS "Public can view approved seller shops" ON public.seller_shops;
CREATE POLICY "Public can view approved seller shops"
  ON public.seller_shops FOR SELECT
  USING (approval_status = 'approved');

DROP POLICY IF EXISTS "Authenticated users can register a shop" ON public.seller_shops;
CREATE POLICY "Authenticated users can register a shop"
  ON public.seller_shops FOR INSERT
  WITH CHECK (
    approval_status = 'pending'
    AND auth.uid() = owner_id
  );

DROP POLICY IF EXISTS "Sellers can update their own shop details" ON public.seller_shops;
CREATE POLICY "Sellers can update their own shop details"
  ON public.seller_shops FOR UPDATE
  USING (owner_id = auth.uid() OR public.is_sarvex_admin())
  WITH CHECK (owner_id = auth.uid() OR public.is_sarvex_admin());

-- ----------------------------------------------------------------------------
-- products
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public can view products from approved shops" ON public.products;
CREATE POLICY "Public can view products from approved shops"
  ON public.products FOR SELECT
  USING (
    public.is_approved_seller_shop(seller_shop_id)
    OR public.is_seller_shop_owner(seller_shop_id)
    OR public.is_sarvex_admin()
  );

DROP POLICY IF EXISTS "Sellers can add products to their own shop" ON public.products;
CREATE POLICY "Sellers can add products to their own shop"
  ON public.products FOR INSERT
  WITH CHECK (
    public.is_seller_shop_owner(seller_shop_id) OR public.is_sarvex_admin()
  );

DROP POLICY IF EXISTS "Sellers can update products in their own shop" ON public.products;
CREATE POLICY "Sellers can update products in their own shop"
  ON public.products FOR UPDATE
  USING (
    public.is_seller_shop_owner(seller_shop_id) OR public.is_sarvex_admin()
  )
  WITH CHECK (
    public.is_seller_shop_owner(seller_shop_id) OR public.is_sarvex_admin()
  );

DROP POLICY IF EXISTS "Sellers can delete products from their own shop" ON public.products;
CREATE POLICY "Sellers can delete products from their own shop"
  ON public.products FOR DELETE
  USING (
    public.is_seller_shop_owner(seller_shop_id) OR public.is_sarvex_admin()
  );

-- ----------------------------------------------------------------------------
-- cart_items (Owner Privacy)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view only their own cart items" ON public.cart_items;
CREATE POLICY "Users can view only their own cart items"
  ON public.cart_items FOR SELECT
  USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can insert into their own cart" ON public.cart_items;
CREATE POLICY "Users can insert into their own cart"
  ON public.cart_items FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can update their own cart items" ON public.cart_items;
CREATE POLICY "Users can update their own cart items"
  ON public.cart_items FOR UPDATE
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Users can delete their own cart items" ON public.cart_items;
CREATE POLICY "Users can delete their own cart items"
  ON public.cart_items FOR DELETE
  USING (auth.uid() = owner_id);

-- ----------------------------------------------------------------------------
-- orders: Direct INSERT blocked for regular users; created only via place_sarvex_order RPC
-- Multi-vendor isolation: Customers and Admins only on base table. Sellers use seller_order_items_view.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Customers and Sellers view relevant orders" ON public.orders;
DROP POLICY IF EXISTS "Customers and Admins view relevant orders" ON public.orders;
CREATE POLICY "Customers and Admins view relevant orders"
  ON public.orders FOR SELECT
  USING (
    (auth.uid() IS NOT NULL AND customer_id = auth.uid())
    OR public.order_has_seller_item(id)
    OR public.is_sarvex_admin()
  );

DROP POLICY IF EXISTS "Customers insert their own orders" ON public.orders;
DROP POLICY IF EXISTS "Only admins or trusted procedures create orders" ON public.orders;
CREATE POLICY "Only admins or trusted procedures create orders"
  ON public.orders FOR INSERT
  WITH CHECK (public.is_sarvex_admin());

DROP POLICY IF EXISTS "Only Admins can update global order status" ON public.orders;
CREATE POLICY "Only Admins can update global order status"
  ON public.orders FOR UPDATE
  USING (public.is_sarvex_admin())
  WITH CHECK (public.is_sarvex_admin());

-- ----------------------------------------------------------------------------
-- order_idempotency_keys: Private to customer or admin
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users view own idempotency keys" ON public.order_idempotency_keys;
CREATE POLICY "Users view own idempotency keys"
  ON public.order_idempotency_keys FOR SELECT
  USING (auth.uid() = customer_id OR public.is_sarvex_admin());

-- ----------------------------------------------------------------------------
-- order_items: Direct INSERT blocked for regular users; created only via place_sarvex_order RPC
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "View order items" ON public.order_items;
CREATE POLICY "View order items"
  ON public.order_items FOR SELECT
  USING (
    (auth.uid() IS NOT NULL AND public.is_order_customer(order_id))
    OR public.is_seller_shop_owner(seller_shop_id)
    OR public.is_sarvex_admin()
  );

DROP POLICY IF EXISTS "Customers insert order items for their own orders" ON public.order_items;
DROP POLICY IF EXISTS "Only admins or trusted procedures insert order items" ON public.order_items;
CREATE POLICY "Only admins or trusted procedures insert order items"
  ON public.order_items FOR INSERT
  WITH CHECK (public.is_sarvex_admin());

DROP POLICY IF EXISTS "Sellers can update only their own order items status" ON public.order_items;
CREATE POLICY "Sellers can update only their own order items status"
  ON public.order_items FOR UPDATE
  USING (
    public.is_seller_shop_owner(seller_shop_id) OR public.is_sarvex_admin()
  )
  WITH CHECK (
    public.is_seller_shop_owner(seller_shop_id) OR public.is_sarvex_admin()
  );

-- ----------------------------------------------------------------------------
-- reviews
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public can view all reviews" ON public.reviews;
CREATE POLICY "Public can view all reviews"
  ON public.reviews FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Verified buyers can submit reviews" ON public.reviews;
CREATE POLICY "Verified buyers can submit reviews"
  ON public.reviews FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND customer_id = auth.uid()
  );

DROP POLICY IF EXISTS "Customers can update their own reviews" ON public.reviews;
CREATE POLICY "Customers can update their own reviews"
  ON public.reviews FOR UPDATE
  USING (auth.uid() = customer_id OR public.is_sarvex_admin())
  WITH CHECK (auth.uid() = customer_id OR public.is_sarvex_admin());

DROP POLICY IF EXISTS "Customers can delete their own reviews" ON public.reviews;
CREATE POLICY "Customers can delete their own reviews"
  ON public.reviews FOR DELETE
  USING (auth.uid() = customer_id OR public.is_sarvex_admin());

-- ----------------------------------------------------------------------------
-- review_helpful_votes: Direct user INSERT blocked. Only vote_review_helpful() RPC or admins.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view review votes" ON public.review_helpful_votes;
DROP POLICY IF EXISTS "Users view own review votes" ON public.review_helpful_votes;
CREATE POLICY "Users view own review votes"
  ON public.review_helpful_votes FOR SELECT
  USING (auth.uid() = user_id OR public.is_sarvex_admin());

DROP POLICY IF EXISTS "Users can insert their own review vote" ON public.review_helpful_votes;
DROP POLICY IF EXISTS "Only admins or trusted procedures insert review votes" ON public.review_helpful_votes;
CREATE POLICY "Only admins or trusted procedures insert review votes"
  ON public.review_helpful_votes FOR INSERT
  WITH CHECK (public.is_sarvex_admin());

DROP POLICY IF EXISTS "Only admins manage review votes" ON public.review_helpful_votes;
CREATE POLICY "Only admins manage review votes"
  ON public.review_helpful_votes FOR UPDATE
  USING (public.is_sarvex_admin())
  WITH CHECK (public.is_sarvex_admin());

DROP POLICY IF EXISTS "Only admins delete review votes" ON public.review_helpful_votes;
CREATE POLICY "Only admins delete review votes"
  ON public.review_helpful_votes FOR DELETE
  USING (public.is_sarvex_admin());

-- ----------------------------------------------------------------------------
-- wishlist_items
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can manage their own wishlist" ON public.wishlist_items;
CREATE POLICY "Users can manage their own wishlist"
  ON public.wishlist_items FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- ----------------------------------------------------------------------------
-- categories
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public read categories" ON public.categories;
CREATE POLICY "Public read categories"
  ON public.categories FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins manage categories" ON public.categories;
CREATE POLICY "Admins manage categories"
  ON public.categories FOR ALL
  USING (public.is_sarvex_admin())
  WITH CHECK (public.is_sarvex_admin());

-- ----------------------------------------------------------------------------
-- sarvex_admin_allowlist
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Only admins view admin allowlist" ON public.sarvex_admin_allowlist;
CREATE POLICY "Only admins view admin allowlist"
  ON public.sarvex_admin_allowlist FOR SELECT
  USING (public.is_sarvex_admin());

DROP POLICY IF EXISTS "Only admins manage admin allowlist" ON public.sarvex_admin_allowlist;
CREATE POLICY "Only admins manage admin allowlist"
  ON public.sarvex_admin_allowlist FOR ALL
  USING (public.is_sarvex_admin())
  WITH CHECK (public.is_sarvex_admin());

-- ============================================================================
-- 16. STORAGE SECURITY POLICIES: product-images BUCKET
-- Restricts uploads, updates, deletes to approved sellers in their own auth.uid() folder
-- Enforces 5MB file size limit and valid image MIME types
-- ============================================================================
DO $$
BEGIN
  -- Supabase owns storage.objects with supabase_storage_admin. Never alter managed
  -- Storage metadata from the postgres migration role. The same policies are tested
  -- in CI where the disposable fixture is owned by postgres.
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'storage'
      AND c.relname = 'objects'
      AND (
        pg_get_userbyid(c.relowner) = current_user
        OR EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper)
      )
  ) THEN
    -- Ensure product-images bucket exists with 5MB limit and image MIME restrictions
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'product-images',
      'product-images',
      true,
      5242880, -- 5 MB
      ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    )
    ON CONFLICT (id) DO UPDATE SET
      public = true,
      file_size_limit = 5242880,
      allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

    -- 1. Public Read: Anyone can view product images
    DROP POLICY IF EXISTS "Public can view product images" ON storage.objects;
    CREATE POLICY "Public can view product images"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'product-images');

    -- 2. Approved Seller Upload: Only approved sellers in their own auth.uid() folder
    DROP POLICY IF EXISTS "Approved sellers upload product images" ON storage.objects;
    CREATE POLICY "Approved sellers upload product images"
      ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'product-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = auth.uid() AND approval_status = 'approved'
        )
      );

    -- 3. Approved Seller Update: Only approved sellers in their own auth.uid() folder
    DROP POLICY IF EXISTS "Approved sellers update own product images" ON storage.objects;
    CREATE POLICY "Approved sellers update own product images"
      ON storage.objects FOR UPDATE TO authenticated
      USING (
        bucket_id = 'product-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = auth.uid() AND approval_status = 'approved'
        )
      )
      WITH CHECK (
        bucket_id = 'product-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = auth.uid() AND approval_status = 'approved'
        )
      );

    -- 4. Approved Seller Delete: Only approved sellers in their own auth.uid() folder
    DROP POLICY IF EXISTS "Approved sellers delete own product images" ON storage.objects;
    CREATE POLICY "Approved sellers delete own product images"
      ON storage.objects FOR DELETE TO authenticated
      USING (
        bucket_id = 'product-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = auth.uid() AND approval_status = 'approved'
        )
      );

    -- 5. Admins full management access on product images
    DROP POLICY IF EXISTS "Admins manage all product images" ON storage.objects;
    CREATE POLICY "Admins manage all product images"
      ON storage.objects FOR ALL TO authenticated
      USING (
        bucket_id = 'product-images' AND public.is_sarvex_admin()
      )
      WITH CHECK (
        bucket_id = 'product-images' AND public.is_sarvex_admin()
      );

    -- Ensure seller-kyc-documents bucket exists (PRIVATE bucket for confidential seller KYC documents: PAN, GSTIN, Bank proofs)
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'seller-kyc-documents',
      'seller-kyc-documents',
      false, -- Strictly private: No public or anonymous read
      10485760, -- 10 MB limit
      ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    )
    ON CONFLICT (id) DO UPDATE SET
      public = false,
      file_size_limit = 10485760,
      allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];

    -- 6. Seller KYC Upload: Authenticated sellers can upload KYC proofs only to their own folder
    DROP POLICY IF EXISTS "Sellers upload own KYC documents" ON storage.objects;
    CREATE POLICY "Sellers upload own KYC documents"
      ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'seller-kyc-documents'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );

    -- 7. Seller KYC View: Authenticated sellers can view only their own uploaded KYC documents
    DROP POLICY IF EXISTS "Sellers view own KYC documents" ON storage.objects;
    CREATE POLICY "Sellers view own KYC documents"
      ON storage.objects FOR SELECT TO authenticated
      USING (
        bucket_id = 'seller-kyc-documents'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );

    -- 8. Seller KYC Update: Authenticated sellers can update their own KYC documents before approval
    DROP POLICY IF EXISTS "Sellers update own KYC documents" ON storage.objects;
    CREATE POLICY "Sellers update own KYC documents"
      ON storage.objects FOR UPDATE TO authenticated
      USING (
        bucket_id = 'seller-kyc-documents'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND NOT EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = auth.uid() AND approval_status = 'approved'
        )
      )
      WITH CHECK (
        bucket_id = 'seller-kyc-documents'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND NOT EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = auth.uid() AND approval_status = 'approved'
        )
      );

    -- 9. Seller KYC Delete: Authenticated sellers can delete their own KYC documents before approval
    DROP POLICY IF EXISTS "Sellers delete own KYC documents" ON storage.objects;
    CREATE POLICY "Sellers delete own KYC documents"
      ON storage.objects FOR DELETE TO authenticated
      USING (
        bucket_id = 'seller-kyc-documents'
        AND (storage.foldername(name))[1] = auth.uid()::text
        AND NOT EXISTS (
          SELECT 1 FROM public.seller_shops
          WHERE owner_id = auth.uid() AND approval_status = 'approved'
        )
      );

    -- 10. Admins manage all KYC documents
    DROP POLICY IF EXISTS "Admins manage all KYC documents" ON storage.objects;
    CREATE POLICY "Admins manage all KYC documents"
      ON storage.objects FOR ALL TO authenticated
      USING (
        bucket_id = 'seller-kyc-documents' AND public.is_sarvex_admin()
      )
      WITH CHECK (
        bucket_id = 'seller-kyc-documents' AND public.is_sarvex_admin()
      );
  ELSE
    RAISE NOTICE 'Skipping Storage metadata and policy changes: storage.objects is owned by Supabase. Configure Storage buckets and policies through Supabase Dashboard.';
  END IF;
END $$;

-- Harden the legacy timestamp trigger function flagged by Supabase Security Advisor.
-- This is safe for the existing no-argument trigger function and keeps object lookup deterministic.
DO $sarvex_harden_search_path$
BEGIN
  IF to_regprocedure('public.set_updated_at()') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.set_updated_at() SET search_path = pg_catalog, public, pg_temp';
  END IF;
END
$sarvex_harden_search_path$;

COMMIT;
