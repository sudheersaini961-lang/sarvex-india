import { createClient, SupabaseClient, User as SupabaseUser } from '@supabase/supabase-js';

// Helper to validate UUID RFC4122
export function isUuid(value: string | undefined | null): boolean {
  if (!value) return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}

// Generate RFC4122 compliant UUID v4 using cryptographically secure randomness.
export function generateUuid(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  }
  throw new Error('Secure random number generation is unavailable. Use a supported HTTPS browser.');
}

// Accept only Supabase project hosts, never lookalike domains or arbitrary HTTPS URLs.
export function isValidSupabaseProjectUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    const hostSuffix = '.supabase.co';
    const projectRef = parsed.hostname.endsWith(hostSuffix)
      ? parsed.hostname.slice(0, -hostSuffix.length)
      : '';

    // Supabase project URLs have exactly one project-ref label before
    // supabase.co. Reject nested/lookalike subdomains and malformed refs.
    return parsed.protocol === 'https:' &&
      /^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$/.test(projectRef) &&
      parsed.hostname === `${projectRef}${hostSuffix}` &&
      parsed.username === '' &&
      parsed.password === '' &&
      parsed.port === '';
  } catch {
    return false;
  }
}

// Supabase publishable keys are safe by prefix. Legacy anon keys are JWTs
// whose decoded role must be exactly "anon"; secret/service-role JWTs fail closed.
export function isSafeSupabaseAnonKey(value: string): boolean {
  const key = value.trim();
  if (key.startsWith('sb_publishable_')) {
    const token = key.slice('sb_publishable_'.length);
    return /^[A-Za-z0-9_-]{16,}$/.test(token);
  }
  if (key.startsWith('sb_secret_')) return false;

  const parts = key.split('.');
  if (parts.length !== 3) return false;
  try {
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const decoded = atob(payload.padEnd(Math.ceil(payload.length / 4) * 4, '='));
    const claims = JSON.parse(decoded) as { role?: unknown };
    return claims.role === 'anon';
  } catch {
    return false;
  }
}

// Get credentials from Vite env or user runtime settings
export function getStoredSupabaseConfig() {
  const envUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
  const envKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

  const localUrl = typeof window !== 'undefined' ? localStorage.getItem('sarvex_supabase_url') : null;
  const localKey = typeof window !== 'undefined' ? localStorage.getItem('sarvex_supabase_key') : null;

  const url = (localUrl || envUrl || '').trim();
  const key = (localKey || envKey || '').trim();
  const isConfigured = isValidSupabaseProjectUrl(url) && isSafeSupabaseAnonKey(key);

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

  if (!isSafeSupabaseAnonKey(targetKey)) {
    return {
      success: false,
      message: 'Unsafe or unsupported API key. Use a Supabase publishable key or legacy anon JWT key only. Never use a secret/service_role key.'
    };
  }

  if (!isValidSupabaseProjectUrl(targetUrl)) {
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
