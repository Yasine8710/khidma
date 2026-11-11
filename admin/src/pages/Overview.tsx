import { useServices } from '../lib/services';
import { useLoad } from '../lib/hooks';
import { ErrorBox } from '../components/ui';

export function Overview() {
  const { api } = useServices();
  const o = useLoad(() => api.overview(), [api]);
  const s = useLoad(() => api.stats(14), [api]);

  if (o.error) return <ErrorBox message={o.error} onRetry={o.reload} />;
  if (!o.data) return <p className="muted">Loading…</p>;
  const d = o.data;
  const tiles: [string, number | string][] = [
    ['Users', d.users],
    ['Professionals', d.professionals],
    ['Published', d.published],
    ['Verified', d.verified],
    ['Suspended', d.suspended],
    ['Verifications waiting', d.pending_verifications],
    ['Open reports', d.open_reports],
    ['Open requests', d.open_requests],
    ['Completed jobs', d.bookings['completed'] ?? 0],
    ['Jobs in progress', (d.bookings['scheduled'] ?? 0) + (d.bookings['in_progress'] ?? 0) + (d.bookings['pending_confirmation'] ?? 0)],
    ['Public reviews', d.reviews],
    ['Hidden reviews', d.hidden_reviews],
    ['Files waiting for cleanup', d.cleanup_queue],
  ];
  return (
    <div>
      <h2>Overview</h2>
      <ul className="tiles">
        {tiles.map(([label, value]) => (
          <li key={label}>
            <strong>{value}</strong>
            <span>{label}</span>
          </li>
        ))}
      </ul>
      <h3>Last 14 days</h3>
      {s.error && <ErrorBox message={s.error} onRetry={s.reload} />}
      {s.data && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th scope="col">Day (UTC)</th>
                <th scope="col">Sign-ups</th>
                <th scope="col">Requests</th>
                <th scope="col">Jobs completed</th>
              </tr>
            </thead>
            <tbody>
              {[...s.data].reverse().map((r) => (
                <tr key={r.day}>
                  <td>{r.day}</td>
                  <td>{r.signups}</td>
                  <td>{r.requests}</td>
                  <td>{r.completed_jobs}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
