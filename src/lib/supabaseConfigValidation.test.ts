import test from 'node:test';
import assert from 'node:assert/strict';
import { validateSupabaseClientConfig } from './supabaseConfigValidation';

function jwt(payload: object): string {
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(payload)}.signature`;
}

test('accepts official HTTPS Supabase project URLs and anon JWT keys', () => {
  const result = validateSupabaseClientConfig(' https://lgeoxxvmsssazorubsvr.supabase.co/ ', jwt({ role: 'anon' }));
  assert.equal(result.valid, true);
  assert.equal(result.normalizedUrl, 'https://lgeoxxvmsssazorubsvr.supabase.co');
});

test('accepts Supabase publishable keys', () => {
  assert.equal(validateSupabaseClientConfig('https://project-ref.supabase.co', 'sb_publishable_12345678901234567890').valid, true);
});

test('rejects service_role JWTs and secret keys', () => {
  assert.equal(validateSupabaseClientConfig('https://project-ref.supabase.co', jwt({ role: 'service_role' })).valid, false);
  assert.equal(validateSupabaseClientConfig('https://project-ref.supabase.co', 'sb_secret_12345678901234567890').valid, false);
});

test('rejects malformed, non-HTTPS, and lookalike project hosts', () => {
  const key = jwt({ role: 'anon' });
  for (const url of [
    'http://project-ref.supabase.co',
    'https://project-ref.supabase.co.attacker.example',
    'https://supabase.co',
    'https://user:pass@project-ref.supabase.co',
    'https://project-ref.supabase.co:8443',
    'https://project-ref.supabase.co/extra',
    'https://project-ref.supabase.co/?redirect=evil'
  ]) {
    assert.equal(validateSupabaseClientConfig(url, key).valid, false, url);
  }
});

test('rejects unknown key formats and malformed JWTs', () => {
  assert.equal(validateSupabaseClientConfig('https://project-ref.supabase.co', 'not-a-valid-public-key-123').valid, false);
  assert.equal(validateSupabaseClientConfig('https://project-ref.supabase.co', 'a.b.c').valid, false);
});
