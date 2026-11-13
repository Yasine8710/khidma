import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { ApiError, createApi, formatTnd, type PaymentOrderRow, type Rpc } from '../lib/api';
import { fakeApi, fakeMedia, renderWith } from '../test-utils';
import { Payments, validateSetting } from './Payments';

const order = (over: Partial<PaymentOrderRow> = {}): PaymentOrderRow => ({
  id: 'o1', reference: 'KH-A1B2C3', method: 'd17', status: 'awaiting_confirmation', plan_code: 'standard',
  amount_millimes: 20000, payer_note: 'Envoye le 12', business_name: 'Plomberie Ali', full_name: 'Ali B', created_at: '2026-11-10T10:00:00Z', ...over,
});

describe('payments api', () => {
  it('sends the right functions and arguments', async () => {
    const rpc: Rpc = vi.fn().mockResolvedValue({ data: null, error: null });
    const api = createApi(rpc);
    await api.paymentOrders('awaiting_confirmation', 0);
    expect(rpc).toHaveBeenLastCalledWith('admin_list_payment_orders', { p_status: 'awaiting_confirmation', p_limit: 25, p_offset: 0 });
    await api.confirmPayment('o1');
    expect(rpc).toHaveBeenLastCalledWith('admin_confirm_payment', { p_order: 'o1' });
    await api.rejectPayment('o1', ' flou ');
    expect(rpc).toHaveBeenLastCalledWith('admin_reject_payment', { p_order: 'o1', p_note: 'flou' });
    await api.rejectPayment('o1');
    expect(rpc).toHaveBeenLastCalledWith('admin_reject_payment', { p_order: 'o1', p_note: null });
    await api.setPaymentSetting('bank_rib', ' 123 ');
    expect(rpc).toHaveBeenLastCalledWith('admin_set_payment_setting', { p_key: 'bank_rib', p_value: '123' });
  });
  it('formats TND', () => {
    expect(formatTnd(20000)).toBe('20 TND');
    expect(formatTnd(25500)).toBe('25.5 TND');
  });
});

describe('Payments', () => {
  it('lists the awaiting queue with its columns', async () => {
    const paymentOrders = vi.fn().mockResolvedValue([order()]);
    renderWith(<Payments />, { api: fakeApi({ paymentOrders }) });
    expect(await screen.findByText('KH-A1B2C3')).toBeInTheDocument();
    expect(screen.getByText('Plomberie Ali')).toBeInTheDocument();
    expect(screen.getByText('20 TND')).toBeInTheDocument();
    expect(screen.getByText('Envoye le 12')).toBeInTheDocument();
    expect(paymentOrders).toHaveBeenCalledWith('awaiting_confirmation', 0);
  });

  it('receipts load only on request and open as short-lived links', async () => {
    const paymentProofs = vi.fn().mockResolvedValue(['https://x.supabase.co/sign/a', 'https://x.supabase.co/sign/b']);
    renderWith(<Payments />, { api: fakeApi({ paymentOrders: vi.fn().mockResolvedValue([order()]) }), media: fakeMedia({ paymentProofs }) });
    await screen.findByText('KH-A1B2C3');
    expect(paymentProofs).not.toHaveBeenCalled();
    await userEvent.setup().click(screen.getByRole('button', { name: 'View receipts (logged)' }));
    expect(await screen.findByRole('link', { name: 'Receipt 2 (opens for 2 minutes)' })).toHaveAttribute('href', 'https://x.supabase.co/sign/b');
    expect(paymentProofs).toHaveBeenCalledWith('o1');
  });

  it('an order without receipts says so', async () => {
    renderWith(<Payments />, { api: fakeApi({ paymentOrders: vi.fn().mockResolvedValue([order()]) }) });
    await userEvent.setup().click(await screen.findByRole('button', { name: 'View receipts (logged)' }));
    expect(await screen.findByText('No receipt attached.')).toBeInTheDocument();
  });

  it('confirming asks first, then calls the function and reloads', async () => {
    const paymentOrders = vi.fn().mockResolvedValueOnce([order()]).mockResolvedValue([]);
    const confirmPayment = vi.fn().mockResolvedValue(undefined);
    renderWith(<Payments />, { api: fakeApi({ paymentOrders, confirmPayment }) });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Confirm' }));
    expect(confirmPayment).not.toHaveBeenCalled();
    await user.click(screen.getByRole('button', { name: 'Yes, payment received' }));
    await waitFor(() => expect(confirmPayment).toHaveBeenCalledWith('o1'));
    expect(await screen.findByText('No awaiting_confirmation payments.')).toBeInTheDocument();
  });

  it('cancelling the prompt does nothing', async () => {
    const confirmPayment = vi.fn();
    renderWith(<Payments />, { api: fakeApi({ paymentOrders: vi.fn().mockResolvedValue([order()]), confirmPayment }) });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Confirm' }));
    await user.click(screen.getByRole('button', { name: 'Cancel' }));
    expect(confirmPayment).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Confirm' })).toBeInTheDocument();
  });

  it('rejecting takes an optional note', async () => {
    const rejectPayment = vi.fn().mockResolvedValue(undefined);
    renderWith(<Payments />, { api: fakeApi({ paymentOrders: vi.fn().mockResolvedValue([order()]), rejectPayment }) });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Reject' }));
    await user.type(screen.getByLabelText('Note (optional)'), 'Montant faux');
    await user.click(screen.getByRole('button', { name: 'Confirm: Reject' }));
    await waitFor(() => expect(rejectPayment).toHaveBeenCalledWith('o1', 'Montant faux'));
  });

  it('a payment already handled shows a clear message', async () => {
    const confirmPayment = vi.fn().mockRejectedValue(new ApiError('not_found'));
    renderWith(<Payments />, { api: fakeApi({ paymentOrders: vi.fn().mockResolvedValue([order()]), confirmPayment }) });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Confirm' }));
    await user.click(screen.getByRole('button', { name: 'Yes, payment received' }));
    expect(await screen.findByText('It no longer exists.')).toBeInTheDocument();
  });

  it('flouci orders have no manual actions', async () => {
    renderWith(<Payments />, { api: fakeApi({ paymentOrders: vi.fn().mockResolvedValue([order({ method: 'flouci', status: 'pending' })]) }) });
    await screen.findByText('KH-A1B2C3');
    expect(screen.queryByRole('button', { name: 'Confirm' })).toBeNull();
  });
});

describe('payment details form', () => {
  it('validates digits before sending', () => {
    expect(validateSetting('bank_rib', '1234')).not.toBeNull();
    expect(validateSetting('bank_rib', '12345 67890 12345 67890')).toBeNull();
    expect(validateSetting('d17_number', '1234567')).not.toBeNull();
    expect(validateSetting('d17_number', '22 123 456')).toBeNull();
    expect(validateSetting('bank_name', '  ')).not.toBeNull();
  });

  it('sends only the filled fields', async () => {
    const setPaymentSetting = vi.fn().mockResolvedValue(undefined);
    renderWith(<Payments />, { api: fakeApi({ setPaymentSetting }) });
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('Bank name'), 'BIAT');
    await user.type(screen.getByLabelText('D17 number (8 digits)'), '22123456');
    await user.click(screen.getByRole('button', { name: 'Save payment details' }));
    await waitFor(() => expect(setPaymentSetting).toHaveBeenCalledTimes(2));
    expect(setPaymentSetting).toHaveBeenCalledWith('bank_name', 'BIAT');
    expect(setPaymentSetting).toHaveBeenCalledWith('d17_number', '22123456');
    expect(await screen.findByRole('status')).toHaveTextContent('Saved 2 values.');
  });

  it('a bad RIB is refused without a call', async () => {
    const setPaymentSetting = vi.fn();
    renderWith(<Payments />, { api: fakeApi({ setPaymentSetting }) });
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('RIB (20 digits)'), '123');
    await user.click(screen.getByRole('button', { name: 'Save payment details' }));
    expect(await screen.findByText('RIB must be 20 digits.')).toBeInTheDocument();
    expect(setPaymentSetting).not.toHaveBeenCalled();
  });
});
