import { useState, type ReactElement } from 'react';
import { Gate } from './Gate';
import { Overview } from './pages/Overview';
import { Verification } from './pages/Verification';
import { Reports } from './pages/Reports';
import { Appeals } from './pages/Appeals';
import { Audit, Professionals, Requests, Reviews, Users } from './pages/Lists';
import { Categories } from './pages/Categories';
import { Payments } from './pages/Payments';
import { Billing } from './pages/Billing';

const PAGES: { id: string; label: string; render: () => ReactElement }[] = [
  { id: 'overview', label: 'Overview', render: () => <Overview /> },
  { id: 'verification', label: 'Verification', render: () => <Verification /> },
  { id: 'payments', label: 'Paiements', render: () => <Payments /> },
  { id: 'billing', label: 'Billing', render: () => <Billing /> },
  { id: 'reports', label: 'Reports', render: () => <Reports /> },
  { id: 'appeals', label: 'Appeals', render: () => <Appeals /> },
  { id: 'professionals', label: 'Professionals', render: () => <Professionals /> },
  { id: 'users', label: 'Users', render: () => <Users /> },
  { id: 'reviews', label: 'Reviews', render: () => <Reviews /> },
  { id: 'requests', label: 'Requests', render: () => <Requests /> },
  { id: 'categories', label: 'Categories', render: () => <Categories /> },
  { id: 'audit', label: 'Audit log', render: () => <Audit /> },
];

function Shell({ signOut }: { signOut: () => void }) {
  const [page, setPage] = useState(PAGES[0]!.id);
  const current = PAGES.find((p) => p.id === page) ?? PAGES[0]!;
  return (
    <div className="shell">
      <header>
        <strong>Khidma admin</strong>
        <button type="button" onClick={signOut}>
          Sign out
        </button>
      </header>
      <nav aria-label="Sections">
        {PAGES.map((p) => (
          <button key={p.id} type="button" aria-current={p.id === page ? 'page' : undefined} onClick={() => setPage(p.id)}>
            {p.label}
          </button>
        ))}
      </nav>
      <main>{current.render()}</main>
    </div>
  );
}

export function App() {
  return <Gate>{(signOut) => <Shell signOut={signOut} />}</Gate>;
}
