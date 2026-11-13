import { useState } from 'react';
import { errorMessage, formatTnd, type BillingDetail, type SubscriptionRow } from '../lib/api';
import { useLoad, usePaged } from '../lib/hooks';
import { useServices } from '../lib/services';
import { Badge, ErrorBox, NoteAction, PagedTable, shortDate } from '../components/ui';

const STATUSES = ['all', 'active', 'past_due', 'expired', 'cancelled'] as const;
const TONE: Record<string, 'good' | 'warn' | 'bad' | 'neutral'> = {
  active: 'good',
  past_due: 'warn',
  expired: 'bad',
  cancelled: 'neutral',
};

/** One merchant's subscription and payment history, on request. */
function Detail({ user }: { user: string }) {
  const { api } = useServices();
  const [detail, setDetail] = useState<BillingDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  if (!detail) {
    return (
      <div>
        <button
          type="button"
          onClick={async () => {
            setError(null);
            try {
              setDetail(await api.billingDetail(user));
            } catch (e) {
              setError(errorMessage(e));
            }
          }}
        >
          Payment history
        </button>
        {error && <ErrorBox message={error} />}
      </div>
    );
  }
  if (detail.orders.length === 0) return <p className="muted">No payments yet.</p>;
  return (
    <ol className="context">
      {detail.orders.map((o) => (
        <li key={o.id}>
          {shortDate(o.created_at)} · {o.reference} · {formatTnd(o.amount_millimes)} · {o.method} · <Badge>{o.status}</Badge>
        </li>
      ))}
    </ol>
  );
}

/** Subscriptions at a glance (MRR, late payers) and corrective actions. */
export function Billing() {
  const { api } = useServices();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('all');
  const summary = useLoad(() => api.billingSummary(), [api]);
  const paged = usePaged((offset) => api.subscriptions(status === 'all' ? null : status, offset), [api, status]);

  const after = () => {
    paged.reload();
    summary.reload();
  };
  const extend = (r: SubscriptionRow, days: number) => async (reason: string) => {
    await api.extendSubscription(r.user_id, days, reason);
    after();
  };
  const setSub = (r: SubscriptionRow, s: 'active' | 'cancelled') => async (reason: string) => {
    await api.setSubscriptionStatus(r.user_id, s, reason);
    after();
  };

  const s = summary.data;
  return (
    <div>
      <h2>Billing</h2>
      {summary.error && <ErrorBox message={summary.error} onRetry={summary.reload} />}
      {s && (
        <ul className="tiles">
          <li>
            <strong>{formatTnd(Number(s.mrr_millimes))}</strong>
            <span>Monthly revenue (MRR)</span>
          </li>
          <li>
            <strong>{s.active}</strong>
            <span>Active</span>
          </li>
          <li>
            <strong>{s.past_due}</strong>
            <span>Past due</span>
          </li>
          <li>
            <strong>{s.expired}</strong>
            <span>Expired</span>
          </li>
          <li>
            <strong>{s.orders_waiting}</strong>
            <span>Payments to confirm</span>
          </li>
          <li>
            <strong>{Number(s.orders_waiting_48h) > 0 ? <Badge tone="bad">{s.orders_waiting_48h}</Badge> : 0}</strong>
            <span>Waiting over 48 h</span>
          </li>
        </ul>
      )}
      <div className="row" role="group" aria-label="Status">
        {STATUSES.map((x) => (
          <button key={x} type="button" aria-pressed={status === x} onClick={() => setStatus(x)}>
            {x}
          </button>
        ))}
      </div>
      <PagedTable<SubscriptionRow>
        paged={paged}
        rowKey={(r) => r.user_id}
        empty="No subscriptions."
        columns={[
          { header: 'Merchant', cell: (r) => r.business_name ?? r.user_id.slice(0, 8) },
          { header: 'Plan', cell: (r) => `${r.plan_code} · ${formatTnd(r.amount_millimes)}` },
          { header: 'Status', cell: (r) => <Badge tone={TONE[r.status] ?? 'neutral'}>{r.status}</Badge> },
          { header: 'Paid until', cell: (r) => shortDate(r.current_period_end) },
          { header: 'Last payment', cell: (r) => (r.last_paid_at ? shortDate(r.last_paid_at) : '—') },
          {
            header: 'Actions',
            cell: (r) => (
              <div className="stack">
                <Detail user={r.user_id} />
                <NoteAction label="Extend grace 7 days" prompt="Reason (kept in the audit log)" required onSubmit={extend(r, 7)} />
                <NoteAction label="Comp 30 days" prompt="Reason (kept in the audit log)" required onSubmit={extend(r, 30)} />
                {r.status === 'cancelled' ? (
                  <NoteAction label="Reactivate" prompt="Reason (kept in the audit log)" required onSubmit={setSub(r, 'active')} />
                ) : (
                  <NoteAction label="Suspend subscription" prompt="Reason (kept in the audit log)" danger required onSubmit={setSub(r, 'cancelled')} />
                )}
              </div>
            ),
          },
        ]}
      />
    </div>
  );
}
