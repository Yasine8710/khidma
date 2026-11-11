import { createClient } from '@supabase/supabase-js';
import { ApiError, createApi, createMedia } from './api';
import type { AuthService, Services } from './services';

/** The real services, built from the two public values of the Supabase project
 * (URL and publishable key; never a service key). */
export function createServices(url: string, publishableKey: string): Services {
  const client = createClient(url, publishableKey, {
    // The session lives in memory and in sessionStorage only: closing the tab signs out.
    auth: { persistSession: true, storage: window.sessionStorage, autoRefreshToken: true },
  });

  const api = createApi(async (fn, args) => {
    const { data, error } = await client.rpc(fn, args);
    return { data, error: error ? { message: error.message, code: error.code } : null };
  });

  const token = async () => (await client.auth.getSession()).data.session?.access_token ?? null;
  const media = createMedia(url, token, (u, init) => fetch(u, init));

  const auth: AuthService = {
    async signIn(email, password) {
      const { error } = await client.auth.signInWithPassword({ email, password });
      if (error) throw new ApiError(/network|fetch/i.test(error.message) ? 'network' : 'forbidden');
    },
    async signOut() {
      // The SDK keeps the session when the network call fails, so the stored
      // session is removed here as well and the page reloads with a fresh
      // client: signing out must never leave admin access behind.
      try {
        await client.auth.signOut({ scope: 'local' });
      } catch {
        // handled below
      }
      try {
        for (const k of Object.keys(window.sessionStorage)) {
          if (k.startsWith('sb-')) window.sessionStorage.removeItem(k);
        }
      } finally {
        window.location.reload();
      }
    },
    async hasSession() {
      return (await token()) !== null;
    },
    async mfaState() {
      const { data, error } = await client.auth.mfa.getAuthenticatorAssuranceLevel();
      if (error || !data) throw new ApiError('unknown');
      if (data.currentLevel === 'aal2') return 'verified';
      return data.nextLevel === 'aal2' ? 'needs_code' : 'needs_enrollment';
    },
    async enroll() {
      const { data, error } = await client.auth.mfa.enroll({ factorType: 'totp' });
      if (error || !data) throw new ApiError('unknown');
      if (data.type !== 'totp') throw new ApiError('unknown');
      return { factorId: data.id, qrSvg: data.totp.qr_code, secret: data.totp.secret };
    },
    async verify(factorId, code) {
      let id = factorId;
      if (!id) {
        const { data, error } = await client.auth.mfa.listFactors();
        if (error) throw new ApiError('unknown');
        id = data.totp[0]?.id ?? null;
      }
      if (!id) throw new ApiError('unknown');
      const { error } = await client.auth.mfa.challengeAndVerify({ factorId: id, code });
      if (error) throw new ApiError('invalid_input');
    },
  };

  return { api, media, auth };
}
