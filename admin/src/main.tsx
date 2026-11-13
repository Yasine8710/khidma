import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { createServices } from './lib/supabase';
import { ServicesProvider } from './lib/services';
import { initMonitoring } from './lib/monitoring';
import './styles.css';

const url = import.meta.env['VITE_SUPABASE_URL'] as string | undefined;
const key = import.meta.env['VITE_SUPABASE_PUBLISHABLE_KEY'] as string | undefined;
const root = createRoot(document.getElementById('root')!);
void initMonitoring(import.meta.env['VITE_SENTRY_DSN'] as string | undefined);

if (!url || !key) {
  // Honest about a missing setup instead of a blank page.
  root.render(
    <main className="card">
      <h1>Khidma admin</h1>
      <p role="alert">
        Not configured: set <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_PUBLISHABLE_KEY</code> (see the README).
      </p>
    </main>,
  );
} else {
  root.render(
    <StrictMode>
      <ServicesProvider services={createServices(url, key)}>
        <App />
      </ServicesProvider>
    </StrictMode>,
  );
}
