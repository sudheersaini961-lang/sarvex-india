import { createClient, SupabaseClient, User as SupabaseUser } from '@supabase/supabase-js';
import { validateSupabaseClientConfig } from './supabaseConfigValidation';

// Helper to validate UUID RFC4122
export function isUuid(value: string | undefined | null): boolean {
  if (!value) return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(value);
}

// Generate RFC4122 compliant UUID v4 using cryptographically secure randomness.
// Never fall back to Math.random: identifiers may be used for security-sensitive
// ownership, idempotency, and database records.
export function generateUuid(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    const bytes = new Uint8Array(16);
    crypto.getRandomValues(bytes);
    // Set the RFC 4122 version (4) and variant bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0'));
    return [
      hex.slice(0, 4).join(''),
      hex.slice(4, 6).join(''),
      hex.slice(6, 8).join(''),
      hex.slice(8, 10).join(''),
      hex.slice(10, 16).join('')
    ].join('-');
  }

  throw new Error('Cryptographically secure random number generation is unavailable.');
}

// Get credentials from Vite env or user runtime settings
export function getStoredSupabaseConfig() {
  const envUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined;
  const envKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

  const localUrl = typeof window !== 'undefined' ? localStorage.getItem('sarvex_supabase_url') : null;
  const localKey = typeof window !== 'undefined' ? localStorage.getItem('sarvex_supabase_key') : null;

  const url = (localUrl || envUrl || '').trim();
  const key = (localKey || envKey || '').trim();

  const validation = validateSupabaseClientConfig(url, key);
  return {
    url: validation.normalizedUrl || url,
    key,
    isConfigured: validation.valid
  };
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
  const validation = validateSupabaseClientConfig(url, key);
  if (!validation.valid || !validation.normalizedUrl) {
    throw new Error(validation.message || 'Invalid Supabase client configuration.');
  }

  if (typeof window !== 'undefined') {
    localStorage.setItem('sarvex_supabase_url', validation.normalizedUrl);
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

  const validation = validateSupabaseClientConfig(targetUrl, targetKey);
  if (!validation.valid || !validation.normalizedUrl) {
    return { success: false, message: validation.message || 'Invalid Supabase client configuration.' };
  }

  try {
    const testClient = createClient(validation.normalizedUrl, targetKey);
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
