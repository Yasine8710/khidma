import { createContext, useContext, type ReactNode } from 'react';
import type { Api, Media } from './api';

export type MfaState = 'verified' | 'needs_code' | 'needs_enrollment';

/** Sign-in and second factor. The real one talks to Supabase Auth; tests use a fake. */
export interface AuthService {
  signIn(email: string, password: string): Promise<void>;
  signOut(): Promise<void>;
  hasSession(): Promise<boolean>;
  mfaState(): Promise<MfaState>;
  /** Starts a TOTP enrollment: the QR code (SVG markup) and the manual secret. */
  enroll(): Promise<{ factorId: string; qrSvg: string; secret: string }>;
  /** Checks a 6-digit code. [factorId] is null for the already enrolled factor. */
  verify(factorId: string | null, code: string): Promise<void>;
}

export type Services = { api: Api; media: Media; auth: AuthService };

const Ctx = createContext<Services | null>(null);

export function ServicesProvider({ services, children }: { services: Services; children: ReactNode }) {
  return <Ctx.Provider value={services}>{children}</Ctx.Provider>;
}

export function useServices(): Services {
  const s = useContext(Ctx);
  if (!s) throw new Error('ServicesProvider missing');
  return s;
}
