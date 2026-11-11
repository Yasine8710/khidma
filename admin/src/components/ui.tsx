import { useState, type ReactNode } from 'react';
import { errorMessage } from '../lib/api';
import type { Paged } from '../lib/hooks';

export const shortDate = (iso: string) => iso.slice(0, 10);
export const shortId = (id: string) => id.slice(0, 8);

export function ErrorBox({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="error">
      <span>{message}</span>
      {onRetry && (
        <button type="button" onClick={onRetry}>
          Retry
        </button>
      )}
    </div>
  );
}

export function Badge({ tone = 'neutral', children }: { tone?: 'neutral' | 'good' | 'warn' | 'bad'; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

export type Column<T> = { header: string; cell: (row: T) => ReactNode };

/** A paged table with loading, empty and error states. */
export function PagedTable<T>({
  paged,
  columns,
  rowKey,
  empty,
}: {
  paged: Paged<T>;
  columns: Column<T>[];
  rowKey: (row: T) => string;
  empty: string;
}) {
  return (
    <div>
      {paged.error && <ErrorBox message={paged.error} onRetry={paged.reload} />}
      {paged.rows.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                {columns.map((c) => (
                  <th key={c.header} scope="col">
                    {c.header}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {paged.rows.map((r) => (
                <tr key={rowKey(r)}>
                  {columns.map((c) => (
                    <td key={c.header}>{c.cell(r)}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {!paged.loading && !paged.error && paged.rows.length === 0 && <p className="muted">{empty}</p>}
      {paged.loading && <p className="muted" aria-live="polite">Loading…</p>}
      {paged.more && !paged.loading && (
        <button type="button" onClick={paged.loadMore}>
          Load more
        </button>
      )}
    </div>
  );
}

/** A button that asks for a note first (required or optional) and runs [onSubmit]. */
export function NoteAction({
  label,
  prompt,
  required,
  danger,
  onSubmit,
}: {
  label: string;
  prompt: string;
  required?: boolean;
  danger?: boolean;
  onSubmit: (note: string) => Promise<void>;
}) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) {
    return (
      <button type="button" className={danger ? 'danger' : undefined} onClick={() => setOpen(true)}>
        {label}
      </button>
    );
  }
  const submit = async () => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await onSubmit(note.trim());
      setOpen(false);
      setNote('');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };
  const missing = required === true && note.trim() === '';
  return (
    <div className="note-action">
      <label>
        {prompt}
        <textarea value={note} maxLength={300} rows={2} onChange={(e) => setNote(e.target.value)} />
      </label>
      {error && <ErrorBox message={error} />}
      <div className="row">
        <button type="button" className={danger ? 'danger' : 'primary'} disabled={busy || missing} onClick={submit}>
          {busy ? 'Working…' : `Confirm: ${label}`}
        </button>
        <button type="button" onClick={() => setOpen(false)} disabled={busy}>
          Cancel
        </button>
      </div>
    </div>
  );
}

/** A plain button for an action that needs no note. Shows its own failure. */
export function QuickAction({ label, onRun }: { label: string; onRun: () => Promise<void> }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <span>
      <button
        type="button"
        disabled={busy}
        onClick={async () => {
          if (busy) return;
          setBusy(true);
          setError(null);
          try {
            await onRun();
          } catch (e) {
            setError(errorMessage(e));
          } finally {
            setBusy(false);
          }
        }}
      >
        {label}
      </button>
      {error && (
        <span role="alert" className="inline-error">
          {error}
        </span>
      )}
    </span>
  );
}
