import { createClient, SupabaseClient, User as SupabaseUser } from '@supabase/supabase-js';

// Helper to validate UUID RFC4122
export function isUuid(value: string | undefined | null): boolean {
  if (!value) return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}

// Generate RFC4122 compliant UUID v4
export function generateUuid(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  // Fallback RFC4122 v4
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// Get credentials from Vite env or user runtime settings
export function getStoredSupabaseConfig() {
  const envUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
  const envKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

  const localUrl = typeof window !== 'undefined' ? localStorage.getItem('sarvex_supabase_url') : null;
  const localKey = typeof window !== 'undefined' ? localStorage.getItem('sarvex_supabase_key') : null;

  const url = (localUrl || envUrl || '').trim();
  const key = (localKey || envKey || '').trim();

  const isConfigured = Boolean(
    url &&
    key &&
    url.startsWith('https://') &&
    url.includes('.supabase.co') &&
    key.length > 20
  );

  return { url, key, isConfigured };
}

let supabaseInstance: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient | null {
  const { url, key, isConfigured } = getStoredSupabaseConfig();
  if (!isConfigured) return null;

  if (!supabaseInstance) {
    try {
      supabaseInstance = createClient(url, key, {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: true,
        },
      });
    } catch (err) {
      console.warn('Failed to initialize Supabase client:', err);
      return null;
    }
  }
  return supabaseInstance;
}

export function saveSupabaseConfig(url: string, key: string) {
  if (typeof window !== 'undefined') {
    localStorage.setItem('sarvex_supabase_url', url.trim());
    localStorage.setItem('sarvex_supabase_key', key.trim());
    supabaseInstance = null; // reset instance so next call uses new credentials
    window.dispatchEvent(new CustomEvent('sarvex:supabase_config_changed'));
  }
}

export function clearSupabaseConfig() {
  if (typeof window !== 'undefined') {
    localStorage.removeItem('sarvex_supabase_url');
    localStorage.removeItem('sarvex_supabase_key');
    supabaseInstance = null;
    window.dispatchEvent(new CustomEvent('sarvex:supabase_config_changed'));
  }
}

export async function testSupabaseConnection(url?: string, key?: string): Promise<{ success: boolean; message: string }> {
  const targetUrl = (url || getStoredSupabaseConfig().url).trim();
  const targetKey = (key || getStoredSupabaseConfig().key).trim();

  if (!targetUrl || !targetKey) {
    return { success: false, message: 'Please provide both Supabase Project URL and Anon Public Key.' };
  }

  // Prevent service_role key usage for security
  if (targetKey.toLowerCase().includes('service_role')) {
    return {
      success: false,
      message: 'Security Alert: Do NOT use the service_role secret key in a client browser! Use the safe "anon" public key from Supabase Project Settings → API.'
    };
  }

  if (!targetUrl.startsWith('https://') || !targetUrl.includes('.supabase.co')) {
    return {
      success: false,
      message: 'Invalid URL. Project URL must start with https:// and end with .supabase.co'
    };
  }

  try {
    const testClient = createClient(targetUrl, targetKey);
    // Real query test against user's existing products table
    const { error } = await testClient.from('products').select('id').limit(1);

    if (error) {
      if (error.code === 'PGRST116') {
        return { success: true, message: 'Supabase responded, but the products query returned no single row. This is not a full schema/security audit.' };
      }
      return { success: false, message: `Supabase returned error: ${error.message} (Code: ${error.code || 'UNKNOWN'})` };
    }

    return { success: true, message: 'Supabase responded and the products table SELECT query succeeded. Other tables, RPCs, and RLS policies are not verified.' };
  } catch (err: any) {
    return { success: false, message: `Network error connecting to Supabase: ${err?.message || 'Please check your internet and Project URL.'}` };
  }
}
