import { useState } from 'react';
import type { AppealRow } from '../lib/api';
import { usePaged } from '../lib/hooks';
import { useServices } from '../lib/services';
import { NoteAction, PagedTable, shortDate, shortId } from '../components/ui';

const STATUSES = ['open', 'rejected', 'lifted'] as const;

/** Appeals from suspended professionals: lift the suspension or keep it. */
export function Appeals() {
  const { api } = useServices();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('open');
  const paged = usePaged((offset) => api.appeals(status, offset), [api, status]);

  const decide = (a: AppealRow, lift: boolean) => async (note: string) => {
    await api.decideAppeal(a.id, lift, note);
    paged.reload();
  };

  return (
    <div>
      <h2>Appeals</h2>
      <div className="row" role="group" aria-label="Status">
        {STATUSES.map((s) => (
          <button key={s} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
            {s}
          </button>
        ))}
      </div>
      <PagedTable<AppealRow>
        paged={paged}
        rowKey={(a) => a.id}
        empty={`No ${status} appeals.`}
        columns={[
          { header: 'Professional', cell: (a) => a.business_name ?? shortId(a.professional_id) },
          { header: 'Suspended for', cell: (a) => a.suspension_reason ?? '—' },
          { header: 'Until', cell: (a) => (a.suspended_until ? shortDate(a.suspended_until) : 'until lifted') },
          { header: 'Appeal', cell: (a) => a.message },
          { header: 'Date', cell: (a) => shortDate(a.created_at) },
          {
            header: 'Decision',
            cell: (a) =>
              a.status === 'open' ? (
                <div className="stack">
                  <NoteAction label="Lift suspension" prompt="Note (optional)" onSubmit={decide(a, true)} />
                  <NoteAction label="Keep suspension" prompt="Why (optional)" danger onSubmit={decide(a, false)} />
                </div>
              ) : (
                a.decision_note ?? a.status
              ),
          },
        ]}
      />
    </div>
  );
}
