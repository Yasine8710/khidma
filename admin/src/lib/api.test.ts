import { describe, expect, it, vi } from 'vitest';
import { ApiError, createApi, createMedia, mapError, PAGE_SIZE, type Rpc } from './api';

describe('mapError', () => {
  it.each([
    [{ code: '42501', message: 'x' }, 'forbidden'],
    [{ code: 'PGRST301', message: 'x' }, 'not_signed_in'],
    [{ code: 'P0002', message: 'not found' }, 'not_found'],
    [{ code: 'P0001', message: 'invalid_transition' }, 'invalid_transition'],
    [{ code: 'P0001', message: 'invalid_input' }, 'invalid_input'],
    [{ code: 'P0001', message: 'something else' }, 'unknown'],
    [{ code: '23514', message: 'x' }, 'invalid_input'],
    [{ message: 'TypeError: Failed to fetch' }, 'network'],
    [{ code: 'XX000', message: 'secret internals' }, 'unknown'],
  ])('%j -> %s', (e, failure) => {
    expect(mapError(e).failure).toBe(failure);
  });
  it('never carries the database text', () => {
    expect(mapError({ code: 'XX000', message: 'relation "x" does not exist' }).message).toBe('unknown');
  });
});

describe('createApi', () => {
  const ok = (data: unknown = null): Rpc => vi.fn().mockResolvedValue({ data, error: null });

  it('sends the right function and arguments', async () => {
    const rpc = ok([]);
    const api = createApi(rpc);
    await api.professionals('ali', 'verified', 50);
    expect(rpc).toHaveBeenCalledWith('admin_list_professionals', { p_query: 'ali', p_filter: 'verified', p_limit: PAGE_SIZE, p_offset: 50 });
    await api.users('', 0);
    expect(rpc).toHaveBeenLastCalledWith('admin_list_users', { p_query: null, p_limit: PAGE_SIZE, p_offset: 0 });
    await api.requests('', 0);
    expect(rpc).toHaveBeenLastCalledWith('admin_list_requests', { p_status: null, p_limit: PAGE_SIZE, p_offset: 0 });
  });

  it('trims notes and sends null for an empty one', async () => {
    const rpc = ok();
    const api = createApi(rpc);
    await api.reviewVerification('r1', false, '  illisible ');
    expect(rpc).toHaveBeenLastCalledWith('admin_review_verification', { p_request: 'r1', p_approve: false, p_reason: 'illisible' });
    await api.reviewVerification('r1', true);
    expect(rpc).toHaveBeenLastCalledWith('admin_review_verification', { p_request: 'r1', p_approve: true, p_reason: null });
    await api.setSuspended('u1', true, '   ');
    expect(rpc).toHaveBeenLastCalledWith('admin_set_suspended', { p_user: 'u1', p_suspended: true, p_reason: null });
  });

  it('turns an error answer into an ApiError and a thrown fetch into network', async () => {
    const bad: Rpc = vi.fn().mockResolvedValue({ data: null, error: { code: '42501', message: 'x' } });
    await expect(createApi(bad).overview()).rejects.toMatchObject({ failure: 'forbidden' });
    const down: Rpc = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));
    await expect(createApi(down).overview()).rejects.toMatchObject({ failure: 'network' });
  });

  it('upsertCategory maps every field', async () => {
    const rpc = ok(7);
    const id = await createApi(rpc).upsertCategory({ id: null, slug: ' jardin ', name_fr: 'a', name_ar: 'b', name_en: 'c', icon: ' grass ', sort_order: 3, active: false });
    expect(id).toBe(7);
    expect(rpc).toHaveBeenCalledWith('admin_upsert_category', {
      p_id: null, p_slug: 'jardin', p_name_fr: 'a', p_name_ar: 'b', p_name_en: 'c', p_icon: 'grass', p_sort_order: 3, p_active: false,
    });
  });
});

describe('createMedia', () => {
  const res = (body: unknown, ok = true) => ({ ok, json: async () => body });

  it('posts the kind and id with the session token', async () => {
    const fetcher = vi.fn().mockResolvedValue(res({ urls: ['https://x/a'] }));
    const media = createMedia('https://p.supabase.co', async () => 'tok', fetcher);
    expect(await media.verificationDocuments('req1')).toEqual(['https://x/a']);
    const [url, init] = fetcher.mock.calls[0]!;
    expect(url).toBe('https://p.supabase.co/functions/v1/admin-media');
    expect(init.headers.Authorization).toBe('Bearer tok');
    expect(JSON.parse(init.body)).toEqual({ kind: 'verification', id: 'req1' });
    await media.chatImages('rep1');
    expect(JSON.parse(fetcher.mock.calls[1]![1].body)).toEqual({ kind: 'chat', id: 'rep1' });
  });

  it('refuses without a session, and on bad or failed answers', async () => {
    const f = vi.fn();
    await expect(createMedia('u', async () => null, f).chatImages('x')).rejects.toBeInstanceOf(ApiError);
    expect(f).not.toHaveBeenCalled();
    await expect(createMedia('u', async () => 't', vi.fn().mockResolvedValue(res({}, false))).chatImages('x')).rejects.toBeInstanceOf(ApiError);
    await expect(createMedia('u', async () => 't', vi.fn().mockResolvedValue(res({ urls: [1] }))).chatImages('x')).rejects.toBeInstanceOf(ApiError);
    await expect(createMedia('u', async () => 't', vi.fn().mockRejectedValue(new Error('x'))).chatImages('x')).rejects.toMatchObject({ failure: 'network' });
  });
});
