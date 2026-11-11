import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { Gate } from './Gate';
import { ApiError } from './lib/api';
import { fakeApi, fakeAuth, renderWith } from './test-utils';

const dash = () => <Gate>{() => <p>DASHBOARD</p>}</Gate>;

describe('Gate', () => {
  it('shows the dashboard only for a verified admin session', async () => {
    renderWith(dash(), { api: fakeApi({ isAdmin: vi.fn().mockResolvedValue(true) }) });
    expect(await screen.findByText('DASHBOARD')).toBeInTheDocument();
  });

  it('signed out: shows the form and does not render the dashboard', async () => {
    renderWith(dash(), { auth: fakeAuth({ hasSession: vi.fn().mockResolvedValue(false) }) });
    expect(await screen.findByRole('button', { name: 'Sign in' })).toBeInTheDocument();
    expect(screen.queryByText('DASHBOARD')).toBeNull();
  });

  it('a signed-in user who is not an admin sees no access', async () => {
    renderWith(dash(), { api: fakeApi({ isAdmin: vi.fn().mockResolvedValue(false) }) });
    expect(await screen.findByText('No access')).toBeInTheDocument();
    expect(screen.queryByText('DASHBOARD')).toBeNull();
  });

  it('never asks the server who is admin before the second step passed', async () => {
    const isAdmin = vi.fn().mockResolvedValue(true);
    renderWith(dash(), { api: fakeApi({ isAdmin }), auth: fakeAuth({ mfaState: vi.fn().mockResolvedValue('needs_code') }) });
    expect(await screen.findByLabelText('6-digit code')).toBeInTheDocument();
    expect(isAdmin).not.toHaveBeenCalled();
    expect(screen.queryByText('DASHBOARD')).toBeNull();
  });

  it('sign in: a wrong password gives one generic message; success continues', async () => {
    const signIn = vi.fn().mockRejectedValueOnce(new ApiError('forbidden')).mockResolvedValue(undefined);
    const hasSession = vi.fn().mockResolvedValueOnce(false).mockResolvedValue(true);
    renderWith(dash(), {
      auth: fakeAuth({ signIn, hasSession }),
      api: fakeApi({ isAdmin: vi.fn().mockResolvedValue(true) }),
    });
    const user = userEvent.setup();
    await user.type(await screen.findByLabelText('Email'), 'a@khidma.tn');
    await user.type(screen.getByLabelText('Password'), 'pw');
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByText('Email or password is wrong.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByText('DASHBOARD')).toBeInTheDocument();
    expect(signIn).toHaveBeenLastCalledWith('a@khidma.tn', 'pw');
  });

  it('code step: only six digits are sent; a wrong code stays on the step', async () => {
    const verify = vi.fn().mockRejectedValueOnce(new Error('no')).mockResolvedValue(undefined);
    const mfaState = vi.fn().mockResolvedValueOnce('needs_code').mockResolvedValue('verified');
    renderWith(dash(), { auth: fakeAuth({ verify, mfaState }), api: fakeApi({ isAdmin: vi.fn().mockResolvedValue(true) }) });
    const user = userEvent.setup();
    const input = await screen.findByLabelText('6-digit code');
    await user.type(input, '12ab');
    await user.click(screen.getByRole('button', { name: 'Verify' }));
    expect(screen.getByText('Enter the 6 digits from your authenticator app.')).toBeInTheDocument();
    expect(verify).not.toHaveBeenCalled();
    await user.clear(input);
    await user.type(input, '123456');
    await user.click(screen.getByRole('button', { name: 'Verify' }));
    expect(await screen.findByText('That code was not accepted. Try the next one.')).toBeInTheDocument();
    await user.type(screen.getByLabelText('6-digit code'), '654321');
    await user.click(screen.getByRole('button', { name: 'Verify' }));
    expect(await screen.findByText('DASHBOARD')).toBeInTheDocument();
    expect(verify).toHaveBeenLastCalledWith(null, '654321');
  });

  it('enrollment: shows the QR code only after asking, then verifies against the new factor', async () => {
    const verify = vi.fn().mockResolvedValue(undefined);
    const enroll = vi.fn().mockResolvedValue({ factorId: 'f9', qrSvg: '<svg/>', secret: 'SECRETKEY' });
    const mfaState = vi.fn().mockResolvedValueOnce('needs_enrollment').mockResolvedValue('verified');
    renderWith(dash(), { auth: fakeAuth({ verify, enroll, mfaState }), api: fakeApi({ isAdmin: vi.fn().mockResolvedValue(true) }) });
    const user = userEvent.setup();
    expect(enroll).not.toHaveBeenCalled();
    await user.click(await screen.findByRole('button', { name: 'Show the QR code' }));
    expect(await screen.findByText('SECRETKEY')).toBeInTheDocument();
    await user.type(screen.getByLabelText('6-digit code'), '111222');
    await user.click(screen.getByRole('button', { name: 'Verify' }));
    expect(await screen.findByText('DASHBOARD')).toBeInTheDocument();
    expect(verify).toHaveBeenCalledWith('f9', '111222');
  });

  it('a failing check shows a retry instead of the dashboard', async () => {
    const isAdmin = vi.fn().mockRejectedValueOnce(new ApiError('network')).mockResolvedValue(true);
    renderWith(dash(), { api: fakeApi({ isAdmin }) });
    expect(await screen.findByText('No connection. Try again.')).toBeInTheDocument();
    await userEvent.setup().click(screen.getByRole('button', { name: 'Retry' }));
    await waitFor(() => expect(screen.getByText('DASHBOARD')).toBeInTheDocument());
  });
});
