-- Seed the exact legacy permissive policies found in the original SARVEX bootstrap.
-- The next production-migration reapplication must remove these and recreate hardened policies.
DO $$
DECLARE
  t text;
  suffix text;
  op text;
  predicate text;
BEGIN
  FOREACH t IN ARRAY ARRAY['customer_profiles','seller_shops','products','cart_items'] LOOP
    FOREACH suffix IN ARRAY ARRAY['create','read','update','delete'] LOOP
      op := CASE suffix
        WHEN 'create' THEN 'INSERT'
        WHEN 'read' THEN 'SELECT'
        WHEN 'update' THEN 'UPDATE'
        ELSE 'DELETE'
      END;
      predicate := CASE
        WHEN suffix = 'create' OR t = 'products' THEN 'auth.uid() IS NOT NULL'
        ELSE 'owner_id = auth.uid()'
      END;
      IF op = 'INSERT' THEN
        EXECUTE format(
          'CREATE POLICY %I ON public.%I FOR INSERT TO public WITH CHECK (%s)',
          t || '_' || suffix || '_policy', t, predicate
        );
      ELSIF op = 'UPDATE' THEN
        EXECUTE format(
          'CREATE POLICY %I ON public.%I FOR UPDATE TO public USING (%s) WITH CHECK (%s)',
          t || '_' || suffix || '_policy', t, predicate, predicate
        );
      ELSE
        EXECUTE format(
          'CREATE POLICY %I ON public.%I FOR %s TO public USING (%s)',
          t || '_' || suffix || '_policy', t, op, predicate
        );
      END IF;
    END LOOP;
  END LOOP;
END $$;

SELECT 'Known legacy RLS policies seeded for migration cleanup test' AS result;
