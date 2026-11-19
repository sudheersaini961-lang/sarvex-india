-- Test-only reproduction of the existing SARVEX starter schema discovered on Live.
-- Includes one customer, one pending seller and four genuine-looking fixture products.
-- Never execute this fixture against the live project.

CREATE TABLE public.customer_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL UNIQUE,
  display_name text,
  account_role text NOT NULL DEFAULT 'customer',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.seller_shops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  shop_name text NOT NULL,
  approval_status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_shop_id uuid NOT NULL,
  product_name text NOT NULL,
  category text NOT NULL,
  image_url text,
  description text,
  price_inr integer NOT NULL DEFAULT 0,
  discount_percent integer NOT NULL DEFAULT 0,
  rating double precision,
  stock_quantity integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- Existing timestamp trigger helper has no fixed search_path (the live advisor finding).
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $legacy_timestamp$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END
$legacy_timestamp$;


-- Exact legacy policies inspected on the connected Live database.
CREATE POLICY customer_profiles_create_policy ON public.customer_profiles FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY customer_profiles_delete_policy ON public.customer_profiles FOR DELETE
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY customer_profiles_read_policy ON public.customer_profiles FOR SELECT
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY customer_profiles_update_policy ON public.customer_profiles FOR UPDATE
  USING (owner_id = (SELECT auth.uid())) WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY seller_shops_create_policy ON public.seller_shops FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY seller_shops_delete_policy ON public.seller_shops FOR DELETE
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY seller_shops_read_policy ON public.seller_shops FOR SELECT
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY seller_shops_update_policy ON public.seller_shops FOR UPDATE
  USING (owner_id = (SELECT auth.uid())) WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY products_create_policy ON public.products FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY products_delete_policy ON public.products FOR DELETE
  USING ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY products_read_policy ON public.products FOR SELECT
  USING ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY products_update_policy ON public.products FOR UPDATE
  USING ((SELECT auth.uid()) IS NOT NULL)
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY cart_items_create_policy ON public.cart_items FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);
CREATE POLICY cart_items_delete_policy ON public.cart_items FOR DELETE
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY cart_items_read_policy ON public.cart_items FOR SELECT
  USING (owner_id = (SELECT auth.uid()));
CREATE POLICY cart_items_update_policy ON public.cart_items FOR UPDATE
  USING (owner_id = (SELECT auth.uid())) WITH CHECK (owner_id = (SELECT auth.uid()));

-- Stable fixture identities make preservation assertions deterministic.
INSERT INTO public.customer_profiles (id, owner_id, display_name, account_role)
VALUES ('10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001',
        'Preserved SARVEX Customer', 'customer');

INSERT INTO public.seller_shops (id, owner_id, shop_name, approval_status)
VALUES ('30000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000002',
        'Preserved Pending Shop', 'pending');

INSERT INTO public.products (id, seller_shop_id, product_name, category, price_inr, stock_quantity)
VALUES
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Fixture Product One','mobiles',1000,5),
 ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','Fixture Product Two','fashion',200,8),
 ('40000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000001','Fixture Product Three','home-kitchen',300,9),
 ('40000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000001','Fixture Product Four','electronics',400,3);
