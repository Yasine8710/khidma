import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from 'react';
import { errorMessage } from './lib/api';
import { useServices } from './lib/services';
import { ErrorBox } from './components/ui';

type Stage = 'loading' | 'signed_out' | 'mfa_code' | 'mfa_enroll' | 'not_admin' | 'ready' | 'failed';

/**
 * Everything before the dashboard: sign in, second factor (TOTP, enrolled on
 * first use), and a server-side check that this account is an admin. The
 * dashboard renders only when all three pass. The server enforces the same
 * rules on every call; this only decides what to show.
 */
export function Gate({ children }: { children: (signOut: () => void) => ReactNode }) {
  const { auth, api } = useServices();
  const [stage, setStage] = useState<Stage>('loading');
  const [error, setError] = useState<string | null>(null);

  const evaluate = useCallback(async () => {
    try {
      if (!(await auth.hasSession())) return setStage('signed_out');
      const mfa = await auth.mfaState();
      if (mfa === 'needs_code') return setStage('mfa_code');
      if (mfa === 'needs_enrollment') return setStage('mfa_enroll');
      setStage((await api.isAdmin()) ? 'ready' : 'not_admin');
    } catch (e) {
      setError(errorMessage(e));
      setStage('failed');
    }
  }, [auth, api]);

  useEffect(() => {
    void evaluate();
  }, [evaluate]);

  const signOut = useCallback(async () => {
    await auth.signOut();
    setError(null);
    setStage('signed_out');
  }, [auth]);

  switch (stage) {
    case 'loading':
      return <p className="muted center">Loading…</p>;
    case 'signed_out':
      return <SignIn onDone={evaluate} />;
    case 'mfa_code':
      return <Code onDone={evaluate} onCancel={signOut} />;
    case 'mfa_enroll':
      return <Enroll onDone={evaluate} onCancel={signOut} />;
    case 'not_admin':
      return (
        <main className="card">
          <h1>No access</h1>
          <p>This account is not an administrator.</p>
          <button type="button" onClick={signOut}>
            Sign out
          </button>
        </main>
      );
    case 'failed':
      return (
        <main className="card">
          <ErrorBox message={error ?? 'Something went wrong.'} onRetry={evaluate} />
          <button type="button" onClick={signOut}>
            Sign out
          </button>
        </main>
      );
    case 'ready':
      return <>{children(() => void signOut())}</>;
  }
}

function SignIn({ onDone }: { onDone: () => void }) {
  const { auth } = useServices();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await auth.signIn(email.trim(), password);
      setPassword('');
      onDone();
    } catch (err) {
      // The same message for every refusal: no hint whether the account exists.
      setError(err instanceof Error && err.message === 'network' ? errorMessage(err) : 'Email or password is wrong.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="card">
      <h1>Khidma admin</h1>
      <form onSubmit={submit} className="form">
        <label>
          Email
          <input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          Password
          <input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        {error && <ErrorBox message={error} />}
        <button type="submit" className="primary" disabled={busy}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}

function CodeForm({ factorId, onDone, onCancel }: { factorId: string | null; onDone: () => void; onCancel: () => void }) {
  const { auth } = useServices();
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (busy) return;
    if (!/^[0-9]{6}$/.test(code)) {
      setError('Enter the 6 digits from your authenticator app.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await auth.verify(factorId, code);
      onDone();
    } catch {
      setError('That code was not accepted. Try the next one.');
      setCode('');
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} className="form">
      <label>
        6-digit code
        <input inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} />
      </label>
      {error && <ErrorBox message={error} />}
      <div className="row">
        <button type="submit" className="primary" disabled={busy}>
          {busy ? 'Checking…' : 'Verify'}
        </button>
        <button type="button" onClick={onCancel} disabled={busy}>
          Sign out
        </button>
      </div>
    </form>
  );
}

function Code({ onDone, onCancel }: { onDone: () => void; onCancel: () => void }) {
  return (
    <main className="card">
      <h1>Second step</h1>
      <p>Open your authenticator app and enter the current code.</p>
      <CodeForm factorId={null} onDone={onDone} onCancel={onCancel} />
    </main>
  );
}

function Enroll({ onDone, onCancel }: { onDone: () => void; onCancel: () => void }) {
  const { auth } = useServices();
  const [info, setInfo] = useState<{ factorId: string; qrSvg: string; secret: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const start = useCallback(() => {
    setError(null);
    auth.enroll().then(setInfo, (e) => setError(errorMessage(e)));
  }, [auth]);

  return (
    <main className="card">
      <h1>Set up the second step</h1>
      <p>Admin access needs an authenticator app (any TOTP app). Scan the code, then enter the 6 digits it shows.</p>
      {!info && (
        <button type="button" className="primary" onClick={start}>
          Show the QR code
        </button>
      )}
      {error && <ErrorBox message={error} />}
      {info && (
        <>
          <img alt="QR code to scan with the authenticator app" width={200} height={200} src={`data:image/svg+xml;utf8,${encodeURIComponent(info.qrSvg)}`} />
          <p className="muted">
            Or type this key: <code>{info.secret}</code>
          </p>
          <CodeForm factorId={info.factorId} onDone={onDone} onCancel={onCancel} />
        </>
      )}
    </main>
  );
}
