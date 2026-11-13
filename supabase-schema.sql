-- ============================================================================
-- SARVEX INDIA: CANONICAL PRODUCTION SCHEMA (PostgreSQL / Supabase)
-- ============================================================================

-- See /supabase-production-migration.sql for the complete, idempotent migration
-- that preserves existing records in customer_profiles, seller_shops, products, and cart_items.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. customer_profiles
CREATE TABLE IF NOT EXISTS public.customer_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID UNIQUE,
  display_name TEXT,
  phone TEXT,
  email TEXT,
  city TEXT,
  state TEXT,
  pincode TEXT,
  address TEXT,
  avatar_url TEXT,
  account_role TEXT DEFAULT 'customer' CHECK (account_role IN ('customer', 'seller', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. seller_shops
CREATE TABLE IF NOT EXISTS public.seller_shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID,
  shop_name TEXT NOT NULL,
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
  approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  commission_rate NUMERIC DEFAULT 0,
  rating NUMERIC DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. products
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_shop_id UUID REFERENCES public.seller_shops(id) ON DELETE CASCADE,
  product_name TEXT NOT NULL,
  category TEXT NOT NULL,
  image_url TEXT NOT NULL,
  description TEXT,
  price_inr NUMERIC NOT NULL CHECK (price_inr >= 0),
  mrp NUMERIC,
  discount_percent NUMERIC DEFAULT 0,
  stock_quantity INTEGER DEFAULT 0 CHECK (stock_quantity >= 0),
  rating NUMERIC DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
  rating_count INTEGER DEFAULT 0 CHECK (rating_count >= 0),
  badge TEXT DEFAULT 'SARVEX Assured',
  is_featured BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT products_mrp_check CHECK (mrp IS NULL OR mrp >= price_inr)
);

-- 4. cart_items
CREATE TABLE IF NOT EXISTS public.cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(owner_id, product_id)
);

-- 5. orders
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
  status TEXT DEFAULT 'placed' CHECK (status IN ('placed', 'confirmed', 'shipped', 'out_for_delivery', 'delivered', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. order_items
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
  seller_shop_id UUID REFERENCES public.seller_shops(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  price_inr NUMERIC NOT NULL CHECK (price_inr >= 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. reviews
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  customer_id UUID,
  customer_name TEXT NOT NULL,
  customer_city TEXT,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  title TEXT NOT NULL,
  comment TEXT NOT NULL,
  is_verified_buyer BOOLEAN DEFAULT FALSE,
  helpful_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. wishlist_items
CREATE TABLE IF NOT EXISTS public.wishlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(owner_id, product_id)
);
