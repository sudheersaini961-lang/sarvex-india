export interface SupabaseConfigValidation {
  valid: boolean;
  normalizedUrl?: string;
  message?: string;
}

function isSafePublicKey(key: string): boolean {
  const normalized = key.trim();

  // Supabase's newer secret keys must never be sent to a browser.
  if (/^sb_secret_/i.test(normalized) || /service_role/i.test(normalized)) {
    return false;
  }

  // New publishable keys are explicitly designed for client-side use.
  if (/^sb_publishable_[A-Za-z0-9_-]{20,}$/i.test(normalized)) {
    return true;
  }

  // Legacy anon keys are JWTs. Only accept the anon role; reject service_role
  // and unknown JWT roles before a key can be persisted or used by the client.
  const parts = normalized.split('.');
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

export function validateSupabaseClientConfig(url: string, key: string): SupabaseConfigValidation {
  const trimmedUrl = url.trim();
  const trimmedKey = key.trim();

  if (!trimmedUrl || !trimmedKey) {
    return { valid: false, message: 'Please provide both Supabase Project URL and a public anon/publishable API key.' };
  }

  let parsed: URL;
  try {
    parsed = new URL(trimmedUrl);
  } catch {
    return { valid: false, message: 'Invalid Supabase Project URL.' };
  }

  // Restrict credentials to the official project hostname. A substring check
  // would incorrectly accept attacker.supabase.co.example.com.
  if (
    parsed.protocol !== 'https:' ||
    !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.supabase\.co$/i.test(parsed.hostname) ||
    parsed.username ||
    parsed.password ||
    parsed.port ||
    (parsed.pathname !== '/' && parsed.pathname !== '') ||
    parsed.search ||
    parsed.hash
  ) {
    return { valid: false, message: 'Invalid URL. Use the HTTPS Project URL ending exactly in .supabase.co, without extra paths or parameters.' };
  }

  if (!isSafePublicKey(trimmedKey)) {
    return {
      valid: false,
      message: 'Unsafe or unsupported API key. Use only the Supabase anon JWT key or sb_publishable_ key. Never use service_role or sb_secret_ keys in the app.'
    };
  }

  return { valid: true, normalizedUrl: parsed.origin };
}
