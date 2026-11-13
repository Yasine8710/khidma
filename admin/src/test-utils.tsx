import { render } from '@testing-library/react';
import type { ReactElement } from 'react';
import { vi } from 'vitest';
import type { Api, Media } from './lib/api';
import { ServicesProvider, type AuthService, type Services } from './lib/services';

/** A fake API where every method is a mock returning an empty list unless told otherwise. */
export function fakeApi(over: Partial<Record<keyof Api, unknown>> = {}): Api {
  const names = [
    'isAdmin', 'overview', 'stats', 'users', 'professionals', 'requests', 'reviews', 'verifications',
    'reports', 'reportContext', 'audit', 'reviewVerification', 'handleReport', 'setSuspended',
    'setReviewStatus', 'upsertCategory', 'paymentOrders', 'confirmPayment', 'rejectPayment', 'setPaymentSetting',
    'appeals', 'suspend', 'decideAppeal', 'revokeVerification', 'holdFreelancer', 'releaseFreelancer',
    'billingSummary', 'subscriptions', 'billingDetail', 'extendSubscription', 'setSubscriptionStatus',
  ] as const;
  const api: Record<string, unknown> = {};
  for (const n of names) {
    const given = over[n];
    api[n] = typeof given === 'function' ? given : vi.fn().mockResolvedValue(given ?? []);
  }
  return api as unknown as Api;
}

export function fakeMedia(over: Partial<Media> = {}): Media {
  return {
    verificationDocuments: vi.fn().mockResolvedValue([]),
    chatImages: vi.fn().mockResolvedValue([]),
    ...over,
  };
}

export function fakeAuth(over: Partial<AuthService> = {}): AuthService {
  return {
    signIn: vi.fn().mockResolvedValue(undefined),
    signOut: vi.fn().mockResolvedValue(undefined),
    hasSession: vi.fn().mockResolvedValue(true),
    mfaState: vi.fn().mockResolvedValue('verified'),
    enroll: vi.fn().mockResolvedValue({ factorId: 'f1', qrSvg: '<svg/>', secret: 'ABCD' }),
    verify: vi.fn().mockResolvedValue(undefined),
    ...over,
  };
}

export function renderWith(ui: ReactElement, services: Partial<Services> = {}) {
  const all: Services = {
    api: services.api ?? fakeApi(),
    media: services.media ?? fakeMedia(),
    auth: services.auth ?? fakeAuth(),
  };
  return { ...render(<ServicesProvider services={all}>{ui}</ServicesProvider>), services: all };
}
