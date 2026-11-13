import { describe, expect, it } from 'vitest';
import type { ErrorEvent } from '@sentry/react';
import { initMonitoring, scrubEvent, scrubText } from './monitoring';

describe('monitoring', () => {
  it('is off without a DSN', async () => {
    expect(await initMonitoring(undefined)).toBe(false);
    expect(await initMonitoring('')).toBe(false);
  });

  it('scrubs e-mails, numbers and tokens', () => {
    expect(scrubText('ali@example.tn +216 20 123 456 Bearer abc')).toBe('[email] [number] [token]');
    expect(scrubText('x'.repeat(400))).toHaveLength(301);
  });

  it('drops user, request, breadcrumbs and server name', () => {
    const e = scrubEvent({
      type: undefined,
      message: 'failed for ali@example.tn',
      user: { id: 'u1', email: 'ali@example.tn' },
      request: { url: 'https://x.supabase.co' },
      breadcrumbs: [{ message: 'click' }],
      server_name: 'laptop',
      exception: { values: [{ type: 'Error', value: 'phone 21620123456' }] },
    } as ErrorEvent);
    expect(e.user).toBeUndefined();
    expect(e.request).toBeUndefined();
    expect(e.breadcrumbs).toBeUndefined();
    expect(e.server_name).toBeUndefined();
    expect(e.message).toBe('failed for [email]');
    expect(e.exception?.values?.[0]?.value).toBe('phone [number]');
  });
});
