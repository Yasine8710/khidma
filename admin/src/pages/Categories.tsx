import { useState, type FormEvent } from 'react';
import { errorMessage, type CategoryInput } from '../lib/api';
import { useServices } from '../lib/services';
import { ErrorBox } from '../components/ui';

const EMPTY: CategoryInput = { id: null, slug: '', name_fr: '', name_ar: '', name_en: '', icon: 'build', sort_order: 0, active: true };
const SLUG = /^[a-z][a-z0-9-]*$/;

/** Checks the form before it is sent; the database checks again. */
export function validateCategory(c: CategoryInput): string | null {
  if (!SLUG.test(c.slug) || c.slug.length > 60) return 'Slug: lowercase letters, digits and dashes, starting with a letter.';
  for (const n of [c.name_fr, c.name_ar, c.name_en]) {
    if (n.trim() === '' || n.length > 80) return 'All three names are required (80 characters at most).';
  }
  if (c.icon.trim() === '' || c.icon.length > 40) return 'Icon name is required.';
  return null;
}

/** Adds or changes a service category (the list itself is public data in the app). */
export function Categories() {
  const { api } = useServices();
  const [form, setForm] = useState<CategoryInput>(EMPTY);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const set = <K extends keyof CategoryInput>(k: K, v: CategoryInput[K]) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (busy) return;
    const problem = validateCategory(form);
    if (problem) {
      setError(problem);
      return;
    }
    setBusy(true);
    setError(null);
    setDone(null);
    try {
      const id = await api.upsertCategory(form);
      setDone(`Saved (id ${id}).`);
      setForm(EMPTY);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      <h2>Add a category</h2>
      <p className="muted">To change an existing one, enter its id; leave the id empty to add a new category.</p>
      <form onSubmit={submit} className="form">
        <label>
          Id (to change one)
          <input
            inputMode="numeric"
            value={form.id ?? ''}
            onChange={(e) => set('id', e.target.value === '' ? null : Number.parseInt(e.target.value, 10) || null)}
          />
        </label>
        <label>
          Slug
          <input value={form.slug} onChange={(e) => set('slug', e.target.value)} />
        </label>
        <label>
          Name (French)
          <input value={form.name_fr} onChange={(e) => set('name_fr', e.target.value)} />
        </label>
        <label>
          Name (Arabic)
          <input value={form.name_ar} dir="rtl" onChange={(e) => set('name_ar', e.target.value)} />
        </label>
        <label>
          Name (English)
          <input value={form.name_en} onChange={(e) => set('name_en', e.target.value)} />
        </label>
        <label>
          Icon name
          <input value={form.icon} onChange={(e) => set('icon', e.target.value)} />
        </label>
        <label>
          Sort order
          <input inputMode="numeric" value={form.sort_order} onChange={(e) => set('sort_order', Number.parseInt(e.target.value, 10) || 0)} />
        </label>
        <label className="check">
          <input type="checkbox" checked={form.active} onChange={(e) => set('active', e.target.checked)} />
          Active
        </label>
        {error && <ErrorBox message={error} />}
        {done && <p role="status">{done}</p>}
        <button type="submit" className="primary" disabled={busy}>
          {busy ? 'Saving…' : 'Save category'}
        </button>
      </form>
    </div>
  );
}
