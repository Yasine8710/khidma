import { useState, type FormEvent } from 'react';
import { errorMessage, formatTnd, type PaymentOrderRow, type PaymentSettingKey } from '../lib/api';
import { usePaged } from '../lib/hooks';
import { useServices } from '../lib/services';
import { Badge, ErrorBox, NoteAction, PagedTable, shortDate } from '../components/ui';

const STATUSES = ['awaiting_confirmation', 'pending', 'paid', 'rejected', 'cancelled', 'failed'] as const;

/** Confirming money received starts a subscription, so it asks first. */
function ConfirmPayment({ order, onDone }: { order: PaymentOrderRow; onDone: () => void }) {
  const { api } = useServices();
  const [asking, setAsking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  if (!asking) {
    return (
      <button type="button" onClick={() => setAsking(true)}>
        Confirm
      </button>
    );
  }
  return (
    <div className="note-action">
      <p>
        Confirm that {formatTnd(order.amount_millimes)} was received for {order.reference}? The subscription starts now.
      </p>
      {error && <ErrorBox message={error} />}
      <div className="row">
        <button
          type="button"
          className="primary"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            setError(null);
            try {
              await api.confirmPayment(order.id);
              onDone();
            } catch (e) {
              setError(errorMessage(e));
              setBusy(false);
            }
          }}
        >
          {busy ? 'Working…' : 'Yes, payment received'}
        </button>
        <button type="button" disabled={busy} onClick={() => setAsking(false)}>
          Cancel
        </button>
      </div>
    </div>
  );
}

const FIELDS: { key: PaymentSettingKey; label: string; hint?: string }[] = [
  { key: 'bank_name', label: 'Bank name' },
  { key: 'bank_holder', label: 'Account holder' },
  { key: 'bank_rib', label: 'RIB', hint: '20 digits' },
  { key: 'd17_number', label: 'D17 number', hint: '8 digits' },
  { key: 'd17_holder', label: 'D17 holder' },
];

const EMPTY: Record<PaymentSettingKey, string> = { bank_name: '', bank_holder: '', bank_rib: '', d17_number: '', d17_holder: '' };

/** Quick client check; the server is the real judge. */
export function validateSetting(key: PaymentSettingKey, value: string): string | null {
  const v = value.replace(/\s/g, '');
  if (value.trim() === '') return 'Enter a value.';
  if (key === 'bank_rib' && !/^[0-9]{20}$/.test(v)) return 'RIB must be 20 digits.';
  if (key === 'd17_number' && !/^[2-9][0-9]{7}$/.test(v)) return 'D17 number must be 8 digits.';
  return null;
}

function PaymentSettings() {
  const { api } = useServices();
  const [values, setValues] = useState(EMPTY);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (busy) return;
    setError(null);
    setDone(null);
    // Only filled fields are sent, so one value can change alone.
    const filled = FIELDS.filter((f) => values[f.key].trim() !== '');
    if (filled.length === 0) {
      setError('Enter at least one value.');
      return;
    }
    for (const f of filled) {
      const problem = validateSetting(f.key, values[f.key]);
      if (problem) {
        setError(problem);
        return;
      }
    }
    setBusy(true);
    try {
      for (const f of filled) await api.setPaymentSetting(f.key, values[f.key]);
      setDone(`Saved ${filled.length} value${filled.length === 1 ? '' : 's'}.`);
      setValues(EMPTY);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} className="stack" aria-label="Coordonnées de paiement">
      <h3>Coordonnées de paiement</h3>
      <p className="muted">Shown to professionals paying by D17 or bank transfer. Leave a field empty to keep its current value.</p>
      {FIELDS.map((f) => (
        <label key={f.key}>
          {f.label}
          {f.hint ? ` (${f.hint})` : ''}
          <input
            value={values[f.key]}
            inputMode={f.key === 'bank_rib' || f.key === 'd17_number' ? 'numeric' : 'text'}
            onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.value }))}
          />
        </label>
      ))}
      {error && <ErrorBox message={error} />}
      {done && <p role="status">{done}</p>}
      <button type="submit" className="primary" disabled={busy}>
        {busy ? 'Saving…' : 'Save payment details'}
      </button>
    </form>
  );
}

/** Receipts attached by the professional; each look is logged. */
function Proofs({ orderId }: { orderId: string }) {
  const { media } = useServices();
  const [urls, setUrls] = useState<string[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  if (urls === null) {
    return (
      <div>
        <button
          type="button"
          onClick={async () => {
            setError(null);
            try {
              setUrls(await media.paymentProofs(orderId));
            } catch (e) {
              setError(errorMessage(e));
            }
          }}
        >
          View receipts (logged)
        </button>
        {error && <ErrorBox message={error} />}
      </div>
    );
  }
  if (urls.length === 0) return <p className="muted">No receipt attached.</p>;
  return (
    <>
      {urls.map((u, i) => (
        <a key={u} href={u} target="_blank" rel="noreferrer noopener" className="doc-link">
          Receipt {i + 1} (opens for 2 minutes)
        </a>
      ))}
    </>
  );
}

export function Payments() {
  const { api } = useServices();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('awaiting_confirmation');
  const paged = usePaged((offset) => api.paymentOrders(status, offset), [api, status]);

  return (
    <div>
      <h2>Paiements</h2>
      <div className="row" role="group" aria-label="Status">
        {STATUSES.map((s) => (
          <button key={s} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {s}
          </button>
        ))}
      </div>
      <PagedTable<PaymentOrderRow>
        paged={paged}
        rowKey={(r) => r.id}
        empty={`No ${status} payments.`}
        columns={[
          { header: 'Reference', cell: (r) => <code>{r.reference}</code> },
          { header: 'Professional', cell: (r) => r.business_name ?? r.full_name ?? '—' },
          { header: 'Method', cell: (r) => r.method },
          { header: 'Plan', cell: (r) => r.plan_code },
          { header: 'Amount', cell: (r) => formatTnd(r.amount_millimes) },
          { header: 'Payer note', cell: (r) => r.payer_note ?? '—' },
          { header: 'Date', cell: (r) => shortDate(r.created_at) },
          {
            header: 'Actions',
            cell: (r) =>
              (r.status === 'awaiting_confirmation' || r.status === 'pending') && r.method !== 'flouci' ? (
                <div className="stack">
                  <Proofs orderId={r.id} />
                  <ConfirmPayment order={r} onDone={paged.reload} />
                  <NoteAction
                    label="Reject"
                    prompt="Note (optional)"
                    danger
                    onSubmit={async (note) => {
                      await api.rejectPayment(r.id, note);
                      paged.reload();
                    }}
                  />
                </div>
              ) : (
                <Badge tone={r.status === 'paid' ? 'good' : 'neutral'}>{r.status}</Badge>
              ),
          },
        ]}
      />
      <PaymentSettings />
    </div>
  );
}
