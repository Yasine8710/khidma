import { useState } from 'react';
import { errorMessage, type VerificationRow } from '../lib/api';
import { usePaged } from '../lib/hooks';
import { useServices } from '../lib/services';
import { Badge, ErrorBox, NoteAction, PagedTable, QuickAction, shortDate, shortId } from '../components/ui';

const STATUSES = ['pending', 'approved', 'rejected', 'cancelled'] as const;

function Documents({ requestId }: { requestId: string }) {
  const { media } = useServices();
  const [urls, setUrls] = useState<string[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  return (
    <div>
      {!urls && (
        <button
          type="button"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            setError(null);
            try {
              setUrls(await media.verificationDocuments(requestId));
            } catch (e) {
              setError(errorMessage(e));
            } finally {
              setBusy(false);
            }
          }}
        >
          View documents (logged)
        </button>
      )}
      {error && <ErrorBox message={error} />}
      {urls && urls.length === 0 && <p className="muted">No documents.</p>}
      {urls?.map((u, i) => (
        <a key={u} href={u} target="_blank" rel="noreferrer noopener" className="doc-link">
          Document {i + 1} (opens for 2 minutes)
        </a>
      ))}
    </div>
  );
}

export function Verification() {
  const { api } = useServices();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('pending');
  const paged = usePaged((offset) => api.verifications(status, offset), [api, status]);

  return (
    <div>
      <h2>Verification requests</h2>
      <div className="row" role="group" aria-label="Status">
        {STATUSES.map((s) => (
          <button key={s} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {s}
          </button>
        ))}
      </div>
      <PagedTable<VerificationRow>
        paged={paged}
        rowKey={(r) => r.id}
        empty={`No ${status} requests.`}
        columns={[
          { header: 'Professional', cell: (r) => r.business_name ?? shortId(r.professional_id) },
          { header: 'Submitted', cell: (r) => shortDate(r.submitted_at) },
          { header: 'Documents', cell: (r) => r.documents },
          { header: 'Status', cell: (r) => <Badge tone={r.status === 'approved' ? 'good' : r.status === 'pending' ? 'warn' : 'neutral'}>{r.status}</Badge> },
          {
            header: 'Actions',
            cell: (r) =>
              r.status === 'pending' ? (
                <div className="stack">
                  <Documents requestId={r.id} />
                  <QuickAction
                    label="Approve"
                    onRun={async () => {
                      await api.reviewVerification(r.id, true);
                      paged.reload();
                    }}
                  />
                  <NoteAction
                    label="Reject"
                    prompt="Reason shown to the professional"
                    required
                    danger
                    onSubmit={async (note) => {
                      await api.reviewVerification(r.id, false, note);
                      paged.reload();
                    }}
                  />
                </div>
              ) : (
                '—'
              ),
          },
        ]}
      />
    </div>
  );
}
