BEGIN;
-- Keep COD closed for public clients until courier serviceability, cash collection,
-- and remittance reconciliation are integrated and verified.
REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.place_sarvex_order(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.place_sarvex_order(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) TO service_role;
COMMENT ON FUNCTION public.place_sarvex_order(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,JSONB,TEXT) IS
'COD checkout is fail-closed for public clients until courier serviceability, cash collection and remittance are integrated and verified.';
COMMIT;
