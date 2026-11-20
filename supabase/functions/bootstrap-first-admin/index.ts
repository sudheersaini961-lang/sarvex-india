/// <reference lib="deno.ns" />
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond(405, { success: false, error: "Method not allowed." });

  const authorization = req.headers.get("Authorization") || "";
  const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);
  if (!tokenMatch) return respond(401, { success: false, error: "A valid signed-in session is required." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const allowedEmail = (Deno.env.get("SARVEX_FIRST_ADMIN_EMAIL") || "").trim().toLowerCase();

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !allowedEmail) {
    return respond(503, { success: false, error: "First-admin bootstrap is not configured by the project administrator." });
  }

  try {
    const authClient = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await authClient.auth.getUser(tokenMatch[1]);
    const user = userData.user;

    if (userError || !user || !user.email || !user.email_confirmed_at) {
      return respond(401, { success: false, error: "A verified SARVEX account is required." });
    }

    if (user.email.trim().toLowerCase() !== allowedEmail) {
      return respond(403, { success: false, error: "This account is not authorized for initial administrator setup." });
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await adminClient.rpc("bootstrap_first_admin_for_user", {
      p_user_id: user.id,
    });

    if (error) {
      console.error("First-admin bootstrap RPC failed:", error.message);
      return respond(500, { success: false, error: "Administrator setup failed. Check the database migration and function logs." });
    }

    if (!data?.success) {
      return respond(409, { success: false, error: data?.error || "Initial administrator setup is closed." });
    }

    return respond(200, {
      success: true,
      already_admin: Boolean(data.already_admin),
      message: data.message,
    });
  } catch (error) {
    console.error("First-admin bootstrap error:", error);
    return respond(500, { success: false, error: "Unexpected first-admin setup error." });
  }
});
