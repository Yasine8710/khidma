import { useState } from 'react';
import { errorMessage, type ReportRow } from '../lib/api';
import { usePaged } from '../lib/hooks';
import { useServices } from '../lib/services';
import { Badge, ErrorBox, NoteAction, PagedTable, QuickAction, shortDate, shortId } from '../components/ui';

const STATUSES = ['open', 'reviewing', 'actioned', 'dismissed'] as const;

/** What the admin needs to judge one report; opening a conversation is logged. */
function Context({ report }: { report: ReportRow }) {
  const { api, media } = useServices();
  const [ctx, setCtx] = useState<Record<string, unknown> | null>(null);
  const [images, setImages] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const isChat = report.target_type === 'conversation' || report.target_type === 'message';

  if (!ctx) {
    return (
      <div>
        <button
          type="button"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            setError(null);
            try {
              setCtx(await api.reportContext(report.id));
            } catch (e) {
              setError(errorMessage(e));
            } finally {
              setBusy(false);
            }
          }}
        >
          {isChat ? 'Read conversation (logged)' : 'Show details'}
        </button>
        {error && <ErrorBox message={error} />}
      </div>
    );
  }
  const messages = Array.isArray(ctx['messages']) ? (ctx['messages'] as Record<string, unknown>[]) : null;
  const held = report.target_type === 'freelancer' && typeof ctx['admin_hold_reason'] === 'string';
  return (
    <div className="context">
      {held && (
        <QuickAction
          label="Release listing"
          onRun={async () => {
            await api.releaseFreelancer(report.target_id);
            setCtx({ ...ctx, admin_hold_reason: null });
          }}
        />
      )}
      {messages ? (
        <ol>
          {messages.map((m, i) => (
            <li key={i}>
              {m['id'] === ctx['reported_message_id'] && <Badge tone="bad">reported</Badge>}{' '}
              <strong>{m['sender_is_customer'] ? 'Customer' : 'Professional'}:</strong>{' '}
              {typeof m['body'] === 'string' ? m['body'] : m['image_path'] ? '[image]' : ''}
            </li>
          ))}
        </ol>
      ) : (
        <dl>
          {Object.entries(ctx).map(([k, v]) => (
            <div key={k}>
              <dt>{k}</dt>
              <dd>{String(v ?? '—')}</dd>
            </div>
          ))}
        </dl>
      )}
      {messages?.some((m) => m['image_path']) && images.length === 0 && (
        <button
          type="button"
          onClick={async () => {
            try {
              setImages(await media.chatImages(report.id));
            } catch (e) {
              setError(errorMessage(e));
            }
          }}
        >
          View images (logged)
        </button>
      )}
      {error && <ErrorBox message={error} />}
      {images.map((u, i) => (
        <a key={u} href={u} target="_blank" rel="noreferrer noopener" className="doc-link">
          Image {i + 1} (opens for 2 minutes)
        </a>
      ))}
    </div>
  );
}

export function Reports() {
  const { api } = useServices();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('open');
  const paged = usePaged((offset) => api.reports(status, offset), [api, status]);

  const handle = (r: ReportRow, s: 'reviewing' | 'actioned' | 'dismissed') => async (note?: string) => {
    await api.handleReport(r.id, s, note);
    paged.reload();
  };
  const hold = (r: ReportRow) => async (reason: string) => {
    await api.holdFreelancer(r.target_id, reason, r.id);
    paged.reload();
  };
  // One step from the queue: suspends the person and closes all their open reports.
  const suspend = (r: ReportRow, days: number | null) => async (reason: string) => {
    await api.suspend(r.subject_id!, days, reason, r.id);
    paged.reload();
  };

  return (
    <div>
      <h2>Reports</h2>
      <div className="row" role="group" aria-label="Status">
        {STATUSES.map((s) => (
          <button key={s} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {s}
          </button>
        ))}
      </div>
      <PagedTable<ReportRow>
        paged={paged}
        rowKey={(r) => r.id}
        empty={`No ${status} reports.`}
        columns={[
          { header: 'About', cell: (r) => `${r.target_type} ${shortId(r.target_id)}${r.message_id ? ` #${r.message_id}` : ''}` },
          {
            header: 'Person',
            cell: (r) =>
              r.subject_id ? (
                <span className="stack">
                  {shortId(r.subject_id)}
                  {r.flagged && <Badge tone="bad">flagged: {r.subject_reporters_30d} reporters</Badge>}
                  {r.subject_suspended && <Badge tone="warn">suspended</Badge>}
                </span>
              ) : (
                '—'
              ),
          },
          { header: 'Reason', cell: (r) => r.reason },
          { header: 'Details', cell: (r) => r.details ?? '—' },
          { header: 'Reports on it', cell: (r) => (r.reports_on_target > 1 ? <Badge tone="warn">{r.reports_on_target}</Badge> : r.reports_on_target) },
          { header: 'Date', cell: (r) => shortDate(r.created_at) },
          {
            header: 'Actions',
            cell: (r) => (
              <div className="stack">
                <Context report={r} />
                {r.status === 'open' && <QuickAction label="Start review" onRun={() => handle(r, 'reviewing')()} />}
                {(r.status === 'open' || r.status === 'reviewing') && (
                  <>
                    <NoteAction label="Action taken" prompt="What was done (optional)" onSubmit={handle(r, 'actioned')} />
                    <NoteAction label="Dismiss" prompt="Why (optional)" onSubmit={handle(r, 'dismissed')} />
                    {r.target_type === 'freelancer' && (
                      <NoteAction label="Unpublish listing" prompt="Reason (shown to the freelancer)" danger required onSubmit={hold(r)} />
                    )}
                    {r.subject_id && r.subject_is_professional && !r.subject_suspended && (
                      <>
                        <NoteAction label="Suspend 7 days" prompt="Reason (shown to the professional)" danger required onSubmit={suspend(r, 7)} />
                        <NoteAction label="Suspend until lifted" prompt="Reason (shown to the professional)" danger required onSubmit={suspend(r, null)} />
                      </>
                    )}
                  </>
                )}
              </div>
            ),
          },
        ]}
      />
    </div>
  );
}
