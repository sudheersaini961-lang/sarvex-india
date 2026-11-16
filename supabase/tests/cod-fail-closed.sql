DO $$
BEGIN
 IF has_function_privilege('anon','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'anon can execute COD RPC'; END IF;
 IF has_function_privilege('authenticated','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'authenticated can execute legacy COD RPC'; END IF;
 IF has_function_privilege('authenticated','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)','EXECUTE') THEN RAISE EXCEPTION 'authenticated can execute idempotent COD RPC'; END IF;
 IF NOT has_function_privilege('service_role','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'service_role lost legacy trusted integration access'; END IF;
 IF NOT has_function_privilege('service_role','public.place_sarvex_order(text,text,text,text,text,text,text,jsonb,text)','EXECUTE') THEN RAISE EXCEPTION 'service_role lost trusted integration access'; END IF;
END $$;
