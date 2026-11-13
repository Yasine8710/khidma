import { describe, expect, it, vi } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Billing } from './Billing';
import { fakeApi, renderWith } from '../test-utils';
import type { SubscriptionRow } from '../lib/api';

const row = (over: Partial<SubscriptionRow> = {}): SubscriptionRow => ({
  user_id: 'u1', business_name: 'Alpha', plan_code: 'standard', status: 'active',
  current_period_end: '2026-12-01T00:00:00Z', amount_millimes: 20000, last_paid_at: '2026-11-01T00:00:00Z', ...over,
});
const summary = {
  mrr_millimes: 50000, active: 2, past_due: 1, expired: 1, cancelled: 0, orders_waiting: 3, orders_waiting_48h: 1,
};

describe('Billing', () => {
  it('shows MRR and past_due count; filters by status', async () => {
    const subscriptions = vi.fn().mockResolvedValue([row()]);
    renderWith(<Billing />, { api: fakeApi({ billingSummary: vi.fn().mockResolvedValue(summary), subscriptions }) });
    const mrr = await screen.findByText('50 TND');
    expect(mrr.closest('li')).toHaveTextContent('Monthly revenue (MRR)');
    expect(screen.getByText('Past due').closest('li')).toHaveTextContent('1');
    expect(subscriptions).toHaveBeenLastCalledWith(null, 0);
    await userEvent.setup().click(screen.getByRole('button', { name: 'past_due' }));
    await waitFor(() => expect(subscriptions).toHaveBeenLastCalledWith('past_due', 0));
  });

  it('extending grace needs a reason and reloads the summary', async () => {
    const billingSummary = vi.fn().mockResolvedValue(summary);
    const extendSubscription = vi.fn().mockResolvedValue('2026-12-08T00:00:00Z');
    renderWith(<Billing />, {
      api: fakeApi({ billingSummary, subscriptions: vi.fn().mockResolvedValue([row({ status: 'past_due' })]), extendSubscription }),
    });
    const user = userEvent.setup();
    const tr = (await screen.findByText('Alpha')).closest('tr')!;
    await user.click(within(tr).getByRole('button', { name: 'Extend grace 7 days' }));
    expect(screen.getByRole('button', { name: 'Confirm: Extend grace 7 days' })).toBeDisabled();
    await user.type(screen.getByLabelText('Reason (kept in the audit log)'), 'Panne D17');
    await user.click(screen.getByRole('button', { name: 'Confirm: Extend grace 7 days' }));
    await waitFor(() => expect(extendSubscription).toHaveBeenCalledWith('u1', 7, 'Panne D17'));
    await waitFor(() => expect(billingSummary).toHaveBeenCalledTimes(2));
  });

  it('a cancelled subscription offers reactivation; history loads on request', async () => {
    const setSubscriptionStatus = vi.fn().mockResolvedValue(undefined);
    const billingDetail = vi.fn().mockResolvedValue({
      subscription: null,
      orders: [{ id: 'o1', reference: 'KH-ABC123', plan_code: 'standard', method: 'd17', status: 'paid',
        amount_millimes: 20000, created_at: '2026-11-01T00:00:00Z', paid_at: '2026-11-01T00:00:00Z', admin_note: null }],
    });
    renderWith(<Billing />, {
      api: fakeApi({
        billingSummary: vi.fn().mockResolvedValue(summary),
        subscriptions: vi.fn().mockResolvedValue([row({ status: 'cancelled' })]),
        setSubscriptionStatus, billingDetail,
      }),
    });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Reactivate' }));
    await user.type(screen.getByLabelText('Reason (kept in the audit log)'), 'Resolu');
    await user.click(screen.getByRole('button', { name: 'Confirm: Reactivate' }));
    await waitFor(() => expect(setSubscriptionStatus).toHaveBeenCalledWith('u1', 'active', 'Resolu'));
    await user.click(screen.getByRole('button', { name: 'Payment history' }));
    expect(await screen.findByText(/KH-ABC123/)).toBeInTheDocument();
    expect(billingDetail).toHaveBeenCalledWith('u1');
  });

  it('the visibility rule needs a reason and valid days, then saves and reloads', async () => {
    const billingConfig = vi.fn().mockResolvedValue({ enforce_subscriptions: false, free_trial_days: 30 });
    const setBillingConfig = vi.fn().mockResolvedValue(undefined);
    renderWith(<Billing />, {
      api: fakeApi({ billingSummary: vi.fn().mockResolvedValue(summary), subscriptions: vi.fn().mockResolvedValue([]), billingConfig, setBillingConfig }),
    });
    const user = userEvent.setup();
    expect(await screen.findByText(/Off: every published profile is listed/)).toBeInTheDocument();
    await user.click(screen.getByLabelText('Hide unpaid profiles'));
    const save = screen.getByRole('button', { name: 'Save rule' });
    expect(save).toBeDisabled();
    await user.clear(screen.getByLabelText('Free trial (days)'));
    await user.type(screen.getByLabelText('Free trial (days)'), '400');
    await user.type(screen.getByLabelText('Why this change (audit log)'), 'Lancement');
    expect(save).toBeDisabled();
    await user.clear(screen.getByLabelText('Free trial (days)'));
    await user.type(screen.getByLabelText('Free trial (days)'), '14');
    await user.click(save);
    await waitFor(() => expect(setBillingConfig).toHaveBeenCalledWith(true, 14, 'Lancement'));
    await waitFor(() => expect(billingConfig).toHaveBeenCalledTimes(2));
  });
});
