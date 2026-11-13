import { useState } from 'react';
import type { AuditRow, ProfessionalRow, RequestRow, ReviewRow, UserRow } from '../lib/api';
import { usePaged } from '../lib/hooks';
import { useServices } from '../lib/services';
import { Badge, NoteAction, PagedTable, QuickAction, shortDate, shortId } from '../components/ui';

function Search({ value, onChange, label }: { value: string; onChange: (v: string) => void; label: string }) {
  const [draft, setDraft] = useState(value);
  return (
    <form
      className="row"
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        onChange(draft.trim());
      }}
    >
      <label>
        {label}
        <input value={draft} maxLength={80} onChange={(e) => setDraft(e.target.value)} />
      </label>
      <button type="submit">Search</button>
    </form>
  );
}

const FILTERS = ['all', 'published', 'unpublished', 'verified', 'pending', 'suspended'] as const;

export function Professionals() {
  const { api } = useServices();
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('all');
  const paged = usePaged((offset) => api.professionals(query, filter, offset), [api, query, filter]);
  return (
    <div>
      <h2>Professionals</h2>
      <Search label="Name or id" value={query} onChange={setQuery} />
      <div className="row" role="group" aria-label="Filter">
        {FILTERS.map((f) => (
          <button key={f} type="button" aria-pressed={filter === f} onClick={() => setFilter(f)}>
            {f}
          </button>
        ))}
      </div>
      <PagedTable<ProfessionalRow>
        paged={paged}
        rowKey={(r) => r.user_id}
        empty="No professionals."
        columns={[
          { header: 'Name', cell: (r) => r.business_name ?? shortId(r.user_id) },
          { header: 'Published', cell: (r) => (r.is_published ? 'yes' : 'no') },
          { header: 'Verification', cell: (r) => <Badge tone={r.verification_status === 'verified' ? 'good' : 'neutral'}>{r.verification_status}</Badge> },
          { header: 'Rating', cell: (r) => (r.review_count > 0 ? `${r.rating_avg} (${r.review_count})` : '—') },
          { header: 'Status', cell: (r) => (r.suspended ? <Badge tone="bad">suspended</Badge> : 'active') },
          {
            header: 'Actions',
            cell: (r) =>
              r.suspended ? (
                <QuickAction
                  label="Lift suspension"
                  onRun={async () => {
                    await api.setSuspended(r.user_id, false);
                    paged.reload();
                  }}
                />
              ) : (
                <div className="stack">
                  <NoteAction
                    label="Suspend"
                    prompt="Reason (shown to the professional, kept in the audit log)"
                    danger
                    required
                    onSubmit={async (note) => {
                      await api.setSuspended(r.user_id, true, note);
                      paged.reload();
                    }}
                  />
                  {r.verification_status === 'verified' && (
                    <NoteAction
                      label="Revoke badge"
                      prompt="Reason (kept in the audit log)"
                      danger
                      required
                      onSubmit={async (note) => {
                        await api.revokeVerification(r.user_id, note);
                        paged.reload();
                      }}
                    />
                  )}
                </div>
              ),
          },
        ]}
      />
    </div>
  );
}

export function Users() {
  const { api } = useServices();
  const [query, setQuery] = useState('');
  const paged = usePaged((offset) => api.users(query, offset), [api, query]);
  return (
    <div>
      <h2>Users</h2>
      <Search label="Name or id" value={query} onChange={setQuery} />
      <PagedTable<UserRow>
        paged={paged}
        rowKey={(r) => r.id}
        empty="No users."
        columns={[
          { header: 'Name', cell: (r) => r.full_name ?? '—' },
          { header: 'Id', cell: (r) => shortId(r.id) },
          { header: 'Roles', cell: (r) => [r.is_customer && 'customer', r.is_professional && 'professional', r.is_admin && 'admin'].filter(Boolean).join(', ') },
          { header: 'Joined', cell: (r) => shortDate(r.created_at) },
        ]}
      />
    </div>
  );
}

export function Requests() {
  const { api } = useServices();
  const [status, setStatus] = useState('');
  const paged = usePaged((offset) => api.requests(status, offset), [api, status]);
  return (
    <div>
      <h2>Requests</h2>
      <div className="row" role="group" aria-label="Status">
        {['', 'open', 'awarded', 'cancelled', 'expired'].map((s) => (
          <button key={s || 'all'} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {s || 'all'}
          </button>
        ))}
      </div>
      <PagedTable<RequestRow>
        paged={paged}
        rowKey={(r) => r.id}
        empty="No requests."
        columns={[
          { header: 'Title', cell: (r) => r.title },
          { header: 'Status', cell: (r) => r.status },
          { header: 'Offers', cell: (r) => r.offers },
          { header: 'Created', cell: (r) => shortDate(r.created_at) },
        ]}
      />
    </div>
  );
}

export function Reviews() {
  const { api } = useServices();
  const [status, setStatus] = useState<'published' | 'hidden'>('published');
  const paged = usePaged((offset) => api.reviews(status, offset), [api, status]);
  return (
    <div>
      <h2>Reviews</h2>
      <div className="row" role="group" aria-label="Status">
        {(['published', 'hidden'] as const).map((s) => (
          <button key={s} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {s}
          </button>
        ))}
      </div>
      <PagedTable<ReviewRow>
        paged={paged}
        rowKey={(r) => r.id}
        empty={`No ${status} reviews.`}
        columns={[
          { header: 'Rating', cell: (r) => `${r.rating} / 5` },
          { header: 'Comment', cell: (r) => r.comment ?? '—' },
          { header: 'About', cell: (r) => (r.about_professional ? 'professional' : 'customer (private)') },
          { header: 'Date', cell: (r) => shortDate(r.created_at) },
          {
            header: 'Actions',
            cell: (r) =>
              status === 'published' ? (
                <NoteAction
                  label="Hide"
                  prompt="Reason (kept in the audit log)"
                  danger
                  required
                  onSubmit={async (note) => {
                    await api.setReviewStatus(r.id, 'hidden', note);
                    paged.reload();
                  }}
                />
              ) : (
                <QuickAction
                  label="Publish again"
                  onRun={async () => {
                    await api.setReviewStatus(r.id, 'published');
                    paged.reload();
                  }}
                />
              ),
          },
        ]}
      />
    </div>
  );
}

export function Audit() {
  const { api } = useServices();
  const paged = usePaged((offset) => api.audit(offset), [api]);
  return (
    <div>
      <h2>Audit log</h2>
      <PagedTable<AuditRow>
        paged={paged}
        rowKey={(r) => String(r.id)}
        empty="Nothing logged yet."
        columns={[
          { header: 'When', cell: (r) => r.created_at.replace('T', ' ').slice(0, 16) },
          { header: 'Admin', cell: (r) => shortId(r.admin_id) },
          { header: 'Action', cell: (r) => r.action },
          { header: 'Target', cell: (r) => `${r.target_type} ${r.target_id.length > 12 ? shortId(r.target_id) : r.target_id}` },
          { header: 'Note', cell: (r) => r.detail ?? '—' },
        ]}
      />
    </div>
  );
}
