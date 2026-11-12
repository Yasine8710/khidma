import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { newDb, createUser, makeAdmin, anon, user, anonymousAuthUser, denies, DENIED, CHECK } from './harness.mjs';

const verify = (db, id) =>
  db.query(`update public.professional_profiles set verification_status = 'verified', verified_at = now(), contact_phone = '+21620123456' where user_id = $1`, [id]);

async function freelancer(db, { verified = true, publish = true } = {}) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_freelancer()');
  if (verified) await verify(db, id);
  await user(db, id).query(
    `update public.freelancer_profiles
        set display_name = 'Sami Dev', headline = 'Développeur web full-stack',
            primary_category_id = 1, bio = 'Sites et applications web sur mesure depuis dix ans.',
            skills = array['Flutter', 'React', ' ', 'Flutter'], starting_price_millimes = 300000
      where user_id = $1`, [id]);
  if (publish) await user(db, id).query('update public.freelancer_profiles set is_published = true where user_id = $1', [id]);
  return id;
}
const addItem = (db, who, kind, extra = {}) => {
  const f = { title: 'Mon projet', description: null, path: null, url: null, ...extra };
  return user(db, who).query(
    'insert into public.freelancer_portfolio_items (freelancer_id, kind, title, description, path, url) values ($1, $2, $3, $4, $5, $6)',
    [who, kind, f.title, f.description, f.path, f.url]);
};
const visibleTo = async (client, id) =>
  (await client.query('select user_id from public.freelancer_profiles where user_id = $1', [id])).rows.length === 1;

describe('digital categories', () => {
  let db;
  before(async () => { db = await newDb(); });
  test('are public, seeded, and read-only for clients', async () => {
    const r = await anon(db).query('select slug from public.digital_categories order by sort_order');
    assert.ok(r.rows.length >= 7);
    assert.equal(r.rows[0].slug, 'web-development');
    const u = await createUser(db);
    await denies(user(db, u).query(`insert into public.digital_categories (slug, name_fr, name_ar, name_en) values ('x','x','x','x')`), DENIED);
    await denies(user(db, u).query(`update public.digital_categories set name_en = 'x'`), DENIED);
  });
  test('the local trades are untouched', async () => {
    const r = await db.query(`select count(*)::int n from public.service_categories where slug in ('web-development','video-editing')`);
    assert.equal(r.rows[0].n, 0);
  });
});

describe('freelancer profile', () => {
  let db, f, other;
  before(async () => {
    db = await newDb();
    f = await freelancer(db);
    other = await createUser(db);
  });

  test('become_freelancer needs a registered user and creates both rows once', async () => {
    const n = (await db.query('select count(*)::int n from public.freelancer_profiles where user_id = $1', [f])).rows[0].n;
    assert.equal(n, 1);
    await user(db, f).query('select public.become_freelancer()');
    assert.equal((await db.query('select count(*)::int n from public.freelancer_profiles where user_id = $1', [f])).rows[0].n, 1);
    assert.equal((await db.query('select is_professional from public.profiles where id = $1', [f])).rows[0].is_professional, true);
    await denies(anon(db).query('select public.become_freelancer()'), DENIED);
    await denies(anonymousAuthUser(db, other).query('select public.become_freelancer()'), DENIED);
  });

  test('skills are cleaned: trimmed, blank and duplicate ones dropped', async () => {
    const r = await user(db, f).query('select skills from public.freelancer_profiles where user_id = $1', [f]);
    assert.deepEqual([...r.rows[0].skills].sort(), ['Flutter', 'React']);
  });

  test('public sees a published, verified freelancer; contact phone is never a column', async () => {
    assert.equal(await visibleTo(anon(db), f), true);
    await denies(anon(db).query('select * from public.freelancer_profiles'), DENIED);
    const cols = (await anon(db).query('select display_name, headline, rating_avg from public.freelancer_profiles')).rows;
    assert.equal(cols.length, 1);
  });

  test('only the owner edits; nobody else changes or deletes it', async () => {
    await user(db, other).query(`update public.freelancer_profiles set headline = 'Pwned!!!' where user_id = $1`, [f]);
    assert.equal((await user(db, f).query('select headline from public.freelancer_profiles')).rows[0].headline, 'Développeur web full-stack');
    await denies(user(db, other).query('delete from public.freelancer_profiles where user_id = $1', [f]), DENIED);
    await denies(user(db, f).query('update public.freelancer_profiles set rating_avg = 5 where user_id = $1', [f]), DENIED);
  });

  test('publishing needs a verified identity', async () => {
    const u = await freelancer(db, { verified: false, publish: false });
    await denies(user(db, u).query('update public.freelancer_profiles set is_published = true where user_id = $1', [u]), 'P0001');
    assert.equal(await visibleTo(anon(db), u), false);
    await verify(db, u);
    await user(db, u).query('update public.freelancer_profiles set is_published = true where user_id = $1', [u]);
    assert.equal(await visibleTo(anon(db), u), true);
  });

  test('an incomplete profile cannot be published', async () => {
    const u = await createUser(db);
    await user(db, u).query('select public.become_freelancer()');
    await verify(db, u);
    await denies(user(db, u).query('update public.freelancer_profiles set is_published = true where user_id = $1', [u]), CHECK);
  });

  test('a freelancer who loses verification or is suspended disappears at once', async () => {
    const u = await freelancer(db);
    assert.equal(await visibleTo(anon(db), u), true);
    await db.query(`update public.professional_profiles set verification_status = 'rejected', verified_at = null where user_id = $1`, [u]);
    assert.equal(await visibleTo(anon(db), u), false);
    assert.equal(await visibleTo(user(db, u), u), true, 'the owner still sees their own');
    await verify(db, u);
    assert.equal(await visibleTo(anon(db), u), true);
    await db.query('update public.professional_profiles set suspended = true where user_id = $1', [u]);
    assert.equal(await visibleTo(anon(db), u), false);
  });

  test('price is bounded and the unit is one of project/hour/day', async () => {
    await denies(user(db, f).query('update public.freelancer_profiles set starting_price_millimes = -1 where user_id = $1', [f]), CHECK);
    await denies(user(db, f).query(`update public.freelancer_profiles set price_unit = 'week' where user_id = $1`, [f]), CHECK);
    await user(db, f).query(`update public.freelancer_profiles set price_unit = 'hour', starting_price_millimes = 45000 where user_id = $1`, [f]);
  });
});

describe('contact reveal', () => {
  let db, f, viewer;
  before(async () => {
    db = await newDb();
    f = await freelancer(db);
    viewer = await createUser(db);
  });
  test('registered users get the phone of a visible freelancer, anon and anonymous-auth do not', async () => {
    const r = await user(db, viewer).query('select public.reveal_freelancer_contact($1) as p', [f]);
    assert.equal(r.rows[0].p, '+21620123456');
    await denies(anon(db).query('select public.reveal_freelancer_contact($1)', [f]), DENIED);
    await denies(anonymousAuthUser(db, viewer).query('select public.reveal_freelancer_contact($1)', [f]), DENIED);
  });
  test('an unpublished or unverified freelancer is not found', async () => {
    const u = await freelancer(db, { publish: false });
    await denies(user(db, viewer).query('select public.reveal_freelancer_contact($1)', [u]), 'P0002');
  });
});

describe('freelance portfolio', () => {
  let db, f, g, draft;
  const img = (id) => `${id}/${randomUUID()}.jpg`;
  before(async () => {
    db = await newDb();
    f = await freelancer(db);
    g = await freelancer(db);
    draft = await freelancer(db, { publish: false });
  });

  test('an owner adds photos, clips, video links and links', async () => {
    await addItem(db, f, 'image', { path: img(f) });
    await addItem(db, f, 'video_file', { path: `${f}/${randomUUID()}.mp4` });
    await addItem(db, f, 'video_link', { url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' });
    await addItem(db, f, 'video_link', { url: 'https://youtu.be/dQw4w9WgXcQ' });
    await addItem(db, f, 'video_link', { url: 'https://vimeo.com/123456789' });
    await addItem(db, f, 'link', { url: 'https://github.com/sami/project' });
    assert.equal((await anon(db).query('select count(*)::int n from public.freelancer_portfolio_items where freelancer_id = $1', [f])).rows[0].n, 6);
  });

  test('bad kinds, hosts and paths are refused', async () => {
    await denies(addItem(db, f, 'video_link', { url: 'https://evil.example/watch?v=abcdefgh' }), CHECK);
    await denies(addItem(db, f, 'video_link', { url: 'http://www.youtube.com/watch?v=dQw4w9WgXcQ' }), CHECK);
    await denies(addItem(db, f, 'link', { url: 'javascript:alert(1)' }), CHECK);
    await denies(addItem(db, f, 'link', { url: 'https://exa mple.com/x y' }), CHECK);
    await denies(addItem(db, f, 'image', { path: `${f}/${randomUUID()}.mp4` }), CHECK);
    await denies(addItem(db, f, 'video_file', { path: `${f}/${randomUUID()}.jpg` }), CHECK);
    await denies(addItem(db, f, 'image', { path: `${g}/${randomUUID()}.jpg` }), CHECK);
    await denies(addItem(db, f, 'image', { path: `${f}/../x.jpg` }), CHECK);
    await denies(addItem(db, f, 'image', { path: img(f), url: 'https://example.com' }), CHECK);
    await denies(addItem(db, f, 'link', { url: 'https://example.com', title: 'x' }), CHECK);
  });

  test('nobody writes into someone else\'s portfolio', async () => {
    await denies(user(db, g).query(
      `insert into public.freelancer_portfolio_items (freelancer_id, kind, title, url) values ($1, 'link', 'Hack', 'https://example.com')`, [f]), DENIED);
    await user(db, g).query('delete from public.freelancer_portfolio_items where freelancer_id = $1', [f]);
    assert.equal((await db.query('select count(*)::int n from public.freelancer_portfolio_items where freelancer_id = $1', [f])).rows[0].n, 6);
    await denies(anon(db).query(
      `insert into public.freelancer_portfolio_items (freelancer_id, kind, title, url) values ($1, 'link', 'Hack', 'https://example.com')`, [f]), DENIED);
  });

  test('only title, description and order can change', async () => {
    await user(db, f).query(`update public.freelancer_portfolio_items set title = 'Renamed', sort_order = 3 where url = 'https://github.com/sami/project'`);
    await denies(user(db, f).query(`update public.freelancer_portfolio_items set url = 'https://example.com' where url = 'https://vimeo.com/123456789'`), DENIED);
  });

  test('an unpublished freelancer\'s portfolio is private', async () => {
    await addItem(db, draft, 'link', { url: 'https://example.com/me' });
    assert.equal((await anon(db).query('select count(*)::int n from public.freelancer_portfolio_items where freelancer_id = $1', [draft])).rows[0].n, 0);
    assert.equal((await user(db, draft).query('select count(*)::int n from public.freelancer_portfolio_items where freelancer_id = $1', [draft])).rows[0].n, 1);
  });

  test('at most 24 items', async () => {
    const h = await freelancer(db);
    for (let i = 0; i < 24; i++) await addItem(db, h, 'link', { url: `https://example.com/${i}` });
    await denies(addItem(db, h, 'link', { url: 'https://example.com/25' }), 'P0001');
  });

  test('files: owner folder only, freelancers only, anonymous-auth refused', async () => {
    const up = (who, name) => user(db, who).query(`insert into storage.objects (bucket_id, name, owner) values ('freelance-media', $1, $2)`, [name, who]);
    await up(f, `${f}/a.mp4`);
    await denies(up(f, `${g}/a.mp4`), DENIED);
    const plain = await createUser(db);
    await denies(up(plain, `${plain}/a.jpg`), DENIED);
    await denies(anonymousAuthUser(db, f).query(`insert into storage.objects (bucket_id, name) values ('freelance-media', $1)`, [`${f}/b.jpg`]), DENIED);
    await user(db, g).query(`delete from storage.objects where bucket_id = 'freelance-media' and name = $1`, [`${f}/a.mp4`]);
    assert.equal((await db.query(`select count(*)::int n from storage.objects where bucket_id = 'freelance-media'`)).rows[0].n, 1, 'g cannot delete f\'s file');
    await user(db, f).query(`delete from storage.objects where bucket_id = 'freelance-media' and name = $1`, [`${f}/a.mp4`]);
  });

  test('the bucket allows photos and short clips only', async () => {
    const b = (await db.query(`select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'freelance-media'`)).rows[0];
    assert.equal(b.public, true);
    assert.equal(b.file_size_limit, 26214400);
    assert.deepEqual([...b.allowed_mime_types].sort(), ['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm']);
  });
});

describe('testimonials by invite link', () => {
  let db, f, other, admin;
  const submit = (who, token, over = {}) => {
    const a = { name: 'Karim B.', rating: 5, body: 'Travail soigné, livré en avance.', project: null, ...over };
    return who.query('select public.submit_testimonial($1, $2, $3::smallint, $4, $5)', [token, a.name, a.rating, a.body, a.project]);
  };
  const invite = async (label = null) =>
    (await user(db, f).query('select public.create_testimonial_invite($1) as t', [label])).rows[0].t;
  before(async () => {
    db = await newDb();
    f = await freelancer(db);
    other = await freelancer(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
  });

  test('a past client with a valid link leaves feedback, once, with no account', async () => {
    const t = await invite('Site de la boulangerie');
    assert.match(t, /^[0-9a-f]{64}$/);
    await submit(anon(db), t);
    const r = await anon(db).query('select author_name, rating, project_title from public.testimonials where freelancer_id = $1', [f]);
    assert.deepEqual(r.rows, [{ author_name: 'Karim B.', rating: 5, project_title: 'Site de la boulangerie' }]);
    await denies(submit(anon(db), t), 'P0001');
  });

  test('the rating summary follows published testimonials', async () => {
    const t = await invite();
    await submit(anon(db), t, { rating: 3, body: 'Correct mais un peu lent à répondre.' });
    const p = (await anon(db).query('select rating_avg, review_count from public.freelancer_profiles where user_id = $1', [f])).rows[0];
    assert.equal(Number(p.rating_avg), 4);
    assert.equal(p.review_count, 2);
  });

  test('wrong, malformed, expired and foreign tokens all fail the same way', async () => {
    await denies(submit(anon(db), 'a'.repeat(64)), 'P0001');
    await denies(submit(anon(db), 'nope'), 'P0001');
    const t = await invite();
    await db.query(`update public.freelancer_invites set expires_at = now() - interval '1 minute' where token_hash = encode(sha256(convert_to($1, 'UTF8')), 'hex')`, [t]);
    await denies(submit(anon(db), t), 'P0001');
  });

  test('the token is stored only as a hash', async () => {
    const t = await invite();
    const stored = await db.query('select token_hash from public.freelancer_invites where token_hash = $1', [t]);
    assert.equal(stored.rows.length, 0);
    await denies(user(db, f).query('select token_hash from public.freelancer_invites'), DENIED);
  });

  test('input limits: rating 1-5, text 10-1000, name 2-60', async () => {
    const t = await invite();
    await denies(submit(anon(db), t, { rating: 6 }), 'P0001');
    await denies(submit(anon(db), t, { rating: 0 }), 'P0001');
    await denies(submit(anon(db), t, { body: 'trop court' .slice(0, 5) }), 'P0001');
    await denies(submit(anon(db), t, { body: 'x'.repeat(1001) }), 'P0001');
    await denies(submit(anon(db), t, { name: 'K' }), 'P0001');
    await denies(submit(anon(db), t, { project: 'p'.repeat(101) }), 'P0001');
    await submit(anon(db), t);
  });

  test('only a freelancer creates invites, at most 20 open ones', async () => {
    await denies(user(db, other).query('select public.create_testimonial_invite()').then(async () => {
      for (let i = 0; i < 20; i++) await user(db, other).query('select public.create_testimonial_invite()');
      await user(db, other).query('select public.create_testimonial_invite()');
    }), 'P0001');
    const plain = await createUser(db);
    await denies(user(db, plain).query('select public.create_testimonial_invite()'), DENIED);
    await denies(anon(db).query('select public.create_testimonial_invite()'), DENIED);
  });

  test('a freelancer can revoke an invite but cannot edit or delete testimonials', async () => {
    const t = await invite('à révoquer');
    const row = (await user(db, f).query(`select id from public.freelancer_invites where label = 'à révoquer'`)).rows[0];
    await user(db, f).query('delete from public.freelancer_invites where id = $1', [row.id]);
    await denies(submit(anon(db), t), 'P0001');
    await denies(user(db, f).query(`update public.testimonials set rating = 1 where freelancer_id = $1`, [f]), DENIED);
    await denies(user(db, f).query('delete from public.testimonials where freelancer_id = $1', [f]), DENIED);
  });

  test('an unpublished freelancer cannot collect testimonials', async () => {
    const t = await invite();
    await user(db, f).query('update public.freelancer_profiles set is_published = false where user_id = $1', [f]);
    await denies(submit(anon(db), t), 'P0001');
    await user(db, f).query('update public.freelancer_profiles set is_published = true where user_id = $1', [f]);
  });

  test('admins hide a testimonial: it leaves the public list and the rating', async () => {
    const id = (await db.query('select id from public.testimonials where freelancer_id = $1 and rating = 3', [f])).rows[0].id;
    await denies(user(db, f).query(`select public.admin_set_testimonial_status($1, 'hidden')`, [id]), DENIED);
    await user(db, admin).query(`select public.admin_set_testimonial_status($1, 'hidden', 'spam')`, [id]);
    assert.equal((await anon(db).query('select id from public.testimonials where id = $1', [id])).rows.length, 0);
    const p = (await anon(db).query('select rating_avg from public.freelancer_profiles where user_id = $1', [f])).rows[0];
    assert.ok(Number(p.rating_avg) >= 4.5);
    await user(db, admin).query(`select public.admin_set_testimonial_status($1, 'published')`, [id]);
  });
});

describe('reporting freelancers and testimonials', () => {
  let db, f, rep, admin, tid;
  before(async () => {
    db = await newDb();
    f = await freelancer(db);
    rep = await createUser(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
    const t = (await user(db, f).query('select public.create_testimonial_invite() as t')).rows[0].t;
    await anon(db).query(`select public.submit_testimonial($1, 'Client X', 4::smallint, 'Un bon travail, merci.', null)`, [t]);
    tid = (await db.query('select id from public.testimonials')).rows[0].id;
  });
  test('a visible freelancer and a published testimonial can be reported', async () => {
    await user(db, rep).query(`select public.report_content('freelancer', $1, 'scam', 'demande un acompte puis disparaît')`, [f]);
    await user(db, rep).query(`select public.report_content('testimonial', $1, 'fake')`, [tid]);
    const rid = (await db.query(`select id from public.reports where target_type = 'freelancer'`)).rows[0].id;
    const ctx = await user(db, admin).query('select public.admin_report_context($1) as c', [rid]);
    assert.equal(ctx.rows[0].c.headline, 'Développeur web full-stack');
  });
  test('not your own profile, not a hidden or unknown target', async () => {
    await denies(user(db, f).query(`select public.report_content('freelancer', $1, 'spam')`, [f]), 'P0002');
    await denies(user(db, rep).query(`select public.report_content('freelancer', $1, 'spam')`, [randomUUID()]), 'P0002');
    await denies(user(db, f).query(`select public.report_content('testimonial', $1, 'spam')`, [tid]), 'P0002');
    await denies(user(db, rep).query(`select public.report_content('freelancer', $1, 'nonsense')`, [f]), 'P0001');
  });
});

describe('account deletion', () => {
  test('queues the freelance files and removes the profile with the account', async () => {
    const db = await newDb();
    const f = await freelancer(db);
    await user(db, f).query(`insert into storage.objects (bucket_id, name, owner) values ('freelance-media', $1, $2)`, [`${f}/a.mp4`, f]);
    await addItem(db, f, 'link', { url: 'https://example.com/me' });
    await user(db, f).query('select public.delete_my_account()');
    const q = await db.query(`select bucket_id, name from public.storage_cleanup_queue where name = $1`, [`${f}/a.mp4`]);
    assert.deepEqual(q.rows, [{ bucket_id: 'freelance-media', name: `${f}/a.mp4` }]);
    assert.equal((await db.query('select count(*)::int n from public.freelancer_profiles')).rows[0].n, 0);
    assert.equal((await db.query('select count(*)::int n from public.freelancer_portfolio_items')).rows[0].n, 0);
  });
});
