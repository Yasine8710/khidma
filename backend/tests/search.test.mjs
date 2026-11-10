import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, anon, user, denies, DENIED, CHECK } from './harness.mjs';

const call = (who, args = {}) => {
  const a = {
    q: null, cat: null, gov: null, city: null, minRating: null, avail: false,
    lat: null, lng: null, radius: null, sort: 'rating', limit: 20, offset: 0, ...args,
  };
  return who.query(
    `select * from public.search_professionals($1, $2::smallint, $3::smallint, $4::integer, $5::numeric, $6::boolean,
       $7::double precision, $8::double precision, $9::double precision, $10, $11, $12)`,
    [a.q, a.cat, a.gov, a.city, a.minRating, a.avail, a.lat, a.lng, a.radius, a.sort, a.limit, a.offset],
  );
};
const names = (r) => r.rows.map((x) => x.business_name);

async function addPro(db, { name, cat = 1, gov = 11, city = null, desc, lat = null, lng = null, rating = 0, reviews = 0, availability = 'available', services = [], areas = [], published = true }) {
  const id = await createUser(db);
  const u = user(db, id);
  await u.query('select public.become_professional()');
  await u.query(
    `update public.professional_profiles
        set business_name = $2, primary_category_id = $3, description = $4, governorate_id = $5,
            city_id = $6, latitude = $7, longitude = $8, contact_phone = '+21620123456',
            availability = $9, is_published = $10
      where user_id = $1`,
    [id, name, cat, desc ?? `${name}: services de qualité à votre disposition.`, gov, city, lat, lng, availability, published],
  );
  await db.query('update public.professional_profiles set rating_avg = $2, review_count = $3 where user_id = $1', [id, rating, reviews]);
  for (const c of services) await u.query('insert into public.professional_services (professional_id, category_id) values ($1, $2)', [id, c]);
  for (const [g, ci] of areas) await u.query('insert into public.service_areas (professional_id, governorate_id, city_id) values ($1, $2, $3)', [id, g, ci]);
  return id;
}

describe('search_professionals', () => {
  let db, ids, marsa, ariana, anyUser;
  before(async () => {
    db = await newDb();
    marsa = (await db.query(`select id from public.cities where name_fr = 'La Marsa'`)).rows[0].id;
    ariana = (await db.query(`select id from public.cities where name_fr = 'Ariana'`)).rows[0].id;
    ids = {};
    ids.karim = await addPro(db, { name: 'Karim Plomberie', cat: 1, gov: 11, city: marsa, lat: 36.88, lng: 10.32, rating: 4.8, reviews: 40, desc: 'Plombier expérimenté: fuites, chauffe-eau et sanitaires.' });
    ids.meriem = await addPro(db, { name: 'Meriem Électricité', cat: 2, gov: 12, city: ariana, lat: 36.86, lng: 10.19, rating: 4.5, reviews: 120, desc: 'Électricienne agréée pour installations et dépannages.' });
    ids.samir = await addPro(db, { name: 'Samir Clim Sfax', cat: 3, gov: 61, lat: 34.74, lng: 10.76, rating: 4.9, reviews: 12, availability: 'busy', desc: 'Installation et entretien de climatiseurs à Sfax.' });
    ids.leila = await addPro(db, { name: 'Leila Nettoyage', cat: 7, gov: 11, lat: 36.80, lng: 10.18, rating: 0, reviews: 0, availability: 'offline', desc: 'Nettoyage de maisons et de bureaux sur Tunis.', services: [1], areas: [[12, null], [13, null]] });
    ids.khaled = await addPro(db, { name: 'خالد للسباكة', cat: 1, gov: 11, lat: 36.81, lng: 10.17, rating: 4.2, reviews: 9, desc: 'سباك محترف لإصلاح التسربات وتركيب الأدوات الصحية.' });
    ids.draft = await addPro(db, { name: 'Brouillon Plomberie', cat: 1, gov: 11, rating: 5, reviews: 99, published: false });
    anyUser = await createUser(db);
  });

  test('returns only published professionals, same for visitors and signed-in users', async () => {
    const a = await call(anon(db), { limit: 50 });
    const b = await call(user(db, anyUser), { limit: 50 });
    assert.equal(a.rows.length, 5);
    assert.deepEqual(names(a), names(b));
    assert.ok(!names(a).includes('Brouillon Plomberie'));
  });

  test("an owner's own draft does not appear in their search results", async () => {
    const r = await call(user(db, ids.draft), { limit: 50 });
    assert.ok(!names(r).includes('Brouillon Plomberie'));
  });

  test('never exposes contact phones or private columns', async () => {
    const r = await call(anon(db));
    const cols = Object.keys(r.rows[0]);
    assert.ok(!cols.includes('contact_phone'));
    assert.ok(!cols.includes('verified_at'));
    assert.deepEqual(cols.sort(), [
      'availability', 'business_name', 'city_id', 'description', 'distance_km', 'governorate_id', 'latitude',
      'longitude', 'neighborhood_id', 'primary_category_id', 'rating_avg', 'review_count', 'user_id',
      'verification_status', 'years_experience',
    ].sort());
  });

  describe('text search', () => {
    test('matches the business name, case- and accent-insensitively', async () => {
      assert.deepEqual(names(await call(anon(db), { q: 'karim' })), ['Karim Plomberie']);
      assert.deepEqual(names(await call(anon(db), { q: 'ELECTRICITE' })), ['Meriem Électricité']);
      assert.deepEqual(names(await call(anon(db), { q: 'électricité' })), ['Meriem Électricité']);
    });

    test('matches the description (keywords)', async () => {
      assert.deepEqual(names(await call(anon(db), { q: 'chauffe-eau' })), ['Karim Plomberie']);
      assert.deepEqual(names(await call(anon(db), { q: 'climatiseurs' })), ['Samir Clim Sfax']);
    });

    test('matches the profession in any language, including secondary services', async () => {
      const fr = names(await call(anon(db), { q: 'plomberie' }));
      assert.deepEqual(fr.sort(), ['Karim Plomberie', 'Leila Nettoyage', 'خالد للسباكة'].sort(), 'Leila also offers plumbing');
      const ar = names(await call(anon(db), { q: 'السباكة' }));
      assert.deepEqual(ar.sort(), ['Karim Plomberie', 'Leila Nettoyage', 'خالد للسباكة'].sort());
      const en = names(await call(anon(db), { q: 'air conditioning' }));
      assert.deepEqual(en, ['Samir Clim Sfax']);
    });

    test('matches governorate, city and neighborhood names in any language', async () => {
      assert.ok(names(await call(anon(db), { q: 'sfax' })).includes('Samir Clim Sfax'));
      assert.ok(names(await call(anon(db), { q: 'صفاقس' })).includes('Samir Clim Sfax'));
      assert.ok(names(await call(anon(db), { q: 'la marsa' })).includes('Karim Plomberie'));
      assert.ok(names(await call(anon(db), { q: 'المرسى' })).includes('Karim Plomberie'));
      assert.ok(names(await call(anon(db), { q: 'ariana' })).includes('Meriem Électricité'));
    });

    test('Arabic spelling variants match: alef forms, taa marbuta, diacritics', async () => {
      // السباكة (taa marbuta) typed as السباكه; with a diacritic on the baa
      assert.ok(names(await call(anon(db), { q: 'السباكه' })).includes('خالد للسباكة'));
      assert.ok(names(await call(anon(db), { q: 'السِّباكة' })).includes('خالد للسباكة'));
      assert.ok(names(await call(anon(db), { q: 'سباك' })).includes('خالد للسباكة'));
      assert.ok(names(await call(anon(db), { q: 'أريانة' })).includes('Meriem Électricité'));
      assert.ok(names(await call(anon(db), { q: 'اريانه' })).includes('Meriem Électricité'));
    });

    test('LIKE wildcards in the query are literal, not patterns', async () => {
      for (const q of ['%', '_', 'k%m', 'k_rim', '\\', '%%']) {
        assert.deepEqual(names(await call(anon(db), { q })), [], q);
      }
    });

    test('blank and whitespace-only queries mean "no text filter"', async () => {
      assert.equal((await call(anon(db), { q: '   ', limit: 50 })).rows.length, 5);
      assert.equal((await call(anon(db), { q: '', limit: 50 })).rows.length, 5);
    });

    test('hostile text is harmless (injection, very long, odd characters)', async () => {
      for (const q of ["'; drop table public.profiles; --", 'x'.repeat(10000), '\u0000'.replace('\u0000', ''), '🙂', "') or 1=1 --"]) {
        const r = await call(anon(db), { q });
        assert.ok(Array.isArray(r.rows));
      }
      assert.equal((await db.query(`select count(*)::int as n from public.profiles`)).rows[0].n > 0, true);
    });
  });

  describe('filters', () => {
    test('category: primary category or a secondary service', async () => {
      assert.deepEqual(names(await call(anon(db), { cat: 1 })).sort(), ['Karim Plomberie', 'Leila Nettoyage', 'خالد للسباكة'].sort());
      assert.deepEqual(names(await call(anon(db), { cat: 7 })), ['Leila Nettoyage']);
      assert.deepEqual(names(await call(anon(db), { cat: 9 })), []);
    });

    test('governorate: where they are based, or a working area', async () => {
      const g12 = names(await call(anon(db), { gov: 12 })).sort();
      assert.deepEqual(g12, ['Leila Nettoyage', 'Meriem Électricité'].sort(), 'Leila serves Ariana (12)');
      assert.deepEqual(names(await call(anon(db), { gov: 61 })), ['Samir Clim Sfax']);
    });

    test('city: based there, or a working area in that city', async () => {
      await db.query('insert into public.service_areas (professional_id, governorate_id, city_id) values ($1, 11, $2)', [ids.samir, marsa]);
      assert.deepEqual(names(await call(anon(db), { city: marsa })).sort(), ['Karim Plomberie', 'Samir Clim Sfax'].sort());
      await db.query('delete from public.service_areas where professional_id = $1', [ids.samir]);
    });

    test('minimum rating', async () => {
      assert.deepEqual(names(await call(anon(db), { minRating: 4.5, sort: 'rating' })), ['Samir Clim Sfax', 'Karim Plomberie', 'Meriem Électricité']);
      assert.deepEqual(names(await call(anon(db), { minRating: 5 })), []);
      assert.ok(!names(await call(anon(db), { minRating: 0.1 })).includes('Leila Nettoyage'), 'no reviews, no rating');
    });

    test('availability', async () => {
      const r = await call(anon(db), { avail: true, limit: 50 });
      assert.ok(r.rows.every((x) => x.availability === 'available'));
      assert.equal(r.rows.length, 3);
    });

    test('filters combine (AND)', async () => {
      assert.deepEqual(names(await call(anon(db), { cat: 1, gov: 11, minRating: 4.5, avail: true })), ['Karim Plomberie']);
      assert.deepEqual(names(await call(anon(db), { q: 'plomb', gov: 61 })), []);
    });
  });

  describe('sorting and paging', () => {
    test('rating (default): best rating first, then most reviews', async () => {
      assert.deepEqual(names(await call(anon(db), { limit: 50 })), [
        'Samir Clim Sfax', 'Karim Plomberie', 'Meriem Électricité', 'خالد للسباكة', 'Leila Nettoyage',
      ]);
    });

    test('most reviewed', async () => {
      assert.deepEqual(names(await call(anon(db), { sort: 'reviews', limit: 3 })), ['Meriem Électricité', 'Karim Plomberie', 'Samir Clim Sfax']);
    });

    test('nearest: distance ascending, unknown positions last, distances are realistic', async () => {
      const r = await call(anon(db), { sort: 'nearest', lat: 36.8065, lng: 10.1815, limit: 50 });
      assert.equal(r.rows[0].business_name, 'Leila Nettoyage', 'about 0.7 km away');
      const sfax = r.rows.find((x) => x.business_name === 'Samir Clim Sfax');
      assert.ok(sfax.distance_km > 225 && sfax.distance_km < 245, `Tunis-Sfax straight line ~236 km, got ${sfax.distance_km}`);
      const d = r.rows.map((x) => x.distance_km);
      assert.deepEqual([...d].sort((a, b) => a - b), d, 'ascending');
    });

    test('radius keeps only professionals within it (and needs a position)', async () => {
      const near = await call(anon(db), { lat: 36.8065, lng: 10.1815, radius: 25, sort: 'nearest', limit: 50 });
      assert.ok(!names(near).includes('Samir Clim Sfax'));
      assert.ok(names(near).includes('Leila Nettoyage'));
      const noPos = await call(anon(db), { radius: 25, limit: 50 });
      assert.equal(noPos.rows.length, 5, 'a radius without a position is ignored');
    });

    test('without a position, distance is null', async () => {
      assert.ok((await call(anon(db))).rows.every((x) => x.distance_km === null));
    });

    test('an unknown or removed sort ("recent") falls back to rating', async () => {
      const a = names(await call(anon(db), { sort: 'recent', limit: 50 }));
      const b = names(await call(anon(db), { sort: 'rating', limit: 50 }));
      assert.deepEqual(a, b);
    });

    test('paging is stable: no duplicates, no gaps, clamped limits', async () => {
      const all = names(await call(anon(db), { limit: 50 }));
      const p1 = names(await call(anon(db), { limit: 2, offset: 0 }));
      const p2 = names(await call(anon(db), { limit: 2, offset: 2 }));
      const p3 = names(await call(anon(db), { limit: 2, offset: 4 }));
      assert.deepEqual([...p1, ...p2, ...p3], all);
      assert.equal((await call(anon(db), { limit: 0 })).rows.length, 1, 'limit is at least 1');
      assert.equal((await call(anon(db), { limit: 10000 })).rows.length, 5, 'and at most 50');
      assert.equal((await call(anon(db), { offset: -5, limit: 2 })).rows.length, 2, 'negative offset is 0');
      assert.equal((await call(anon(db), { offset: 100 })).rows.length, 0);
    });

    test('ties are broken deterministically', async () => {
      const a = await addPro(db, { name: 'Tie A', cat: 5, rating: 3, reviews: 3 });
      const b = await addPro(db, { name: 'Tie B', cat: 5, rating: 3, reviews: 3 });
      const first = (await call(anon(db), { cat: 5 })).rows.map((x) => x.user_id);
      const again = (await call(anon(db), { cat: 5 })).rows.map((x) => x.user_id);
      assert.deepEqual(first, again);
      assert.deepEqual(first, [a, b].sort());
    });
  });

  describe('visibility changes take effect immediately', () => {
    test('unpublishing hides, republishing shows', async () => {
      await user(db, ids.karim).query('update public.professional_profiles set is_published = false where user_id = $1', [ids.karim]);
      assert.ok(!names(await call(anon(db), { limit: 50 })).includes('Karim Plomberie'));
      await user(db, ids.karim).query('update public.professional_profiles set is_published = true where user_id = $1', [ids.karim]);
      assert.ok(names(await call(anon(db), { limit: 50 })).includes('Karim Plomberie'));
    });

    test('deleting an account removes the professional from search', async () => {
      const gone = await addPro(db, { name: 'Éphémère', cat: 6 });
      assert.deepEqual(names(await call(anon(db), { q: 'ephemere' })), ['Éphémère']);
      await user(db, gone).query('select public.delete_my_account()');
      assert.deepEqual(names(await call(anon(db), { q: 'ephemere' })), []);
    });

    test('an admin sees the same public results (drafts are not search results)', async () => {
      const admin = await createUser(db);
      await makeAdmin(db, admin);
      const r = await call(user(db, admin), { limit: 50 });
      assert.ok(!names(r).includes('Brouillon Plomberie'));
    });
  });

  test('a published profile must have a public name', async () => {
    const id = await createUser(db);
    await user(db, id).query('select public.become_professional()');
    await denies(
      user(db, id).query(
        `update public.professional_profiles set primary_category_id = 1, governorate_id = 11,
           description = 'Description suffisamment longue.', contact_phone = '+21620123456', is_published = true
         where user_id = $1`, [id]),
      CHECK,
    );
    await denies(
      user(db, id).query(
        `update public.professional_profiles set business_name = 'X', primary_category_id = 1, governorate_id = 11,
           description = 'Description suffisamment longue.', contact_phone = '+21620123456', is_published = true
         where user_id = $1`, [id]),
      CHECK,
    );
  });

  test('search_normalize behaves as documented', async () => {
    const n = async (s) => (await db.query('select public.search_normalize($1) as v', [s])).rows[0].v;
    assert.equal(await n('Électricité À Côté'), 'electricite a cote');
    assert.equal(await n('Œuvre'), 'ouvre', 'the oe ligature maps to o');
    assert.equal(await n('مَدْرَسَة'), 'مدرسه');
    assert.equal(await n('أحمد إبراهيم آمنة'), 'احمد ابراهيم امنه');
    assert.equal(await n('كتابى'), 'كتابي');
    assert.equal(await n(null), '');
  });

  test('visitors cannot run it against hidden columns: still no access to private tables', async () => {
    await denies(anon(db).query('select * from public.profiles'), DENIED);
  });
});
