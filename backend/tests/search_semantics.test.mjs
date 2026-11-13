import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { newDb, createUser, anon } from './harness.mjs';

const vectors = JSON.parse(readFileSync(new URL('./vectors/search_normalize.json', import.meta.url))).vectors;

const call = (who, args = {}) => {
  const a = { q: null, cat: null, gov: null, city: null, lat: null, lng: null, radius: null, sort: 'rating', limit: 20, offset: 0, ...args };
  return who.query(
    `select * from public.search_professionals($1, $2::smallint, $3::smallint, $4::integer, null::numeric, false,
       $5::double precision, $6::double precision, $7::double precision, $8, $9, $10)`,
    [a.q, a.cat, a.gov, a.city, a.lat, a.lng, a.radius, a.sort, a.limit, a.offset],
  );
};
const names = (r) => r.rows.map((x) => x.business_name);

async function addPro(db, { name, cat = 1, gov = 11, city = null, lat = null, lng = null, rating = 0, reviews = 0, areas = [] }) {
  const id = await createUser(db);
  const u = (await import('./harness.mjs')).user(db, id);
  await u.query('select public.become_professional()');
  await u.query(
    `update public.professional_profiles set business_name = $2, primary_category_id = $3,
       description = $4, governorate_id = $5, city_id = $6, latitude = $7, longitude = $8,
       contact_phone = '+21620123456', is_published = true where user_id = $1`,
    [id, name, cat, `${name}: des services de qualité à votre disposition.`, gov, city, lat, lng],
  );
  await db.query('update public.professional_profiles set rating_avg = $2, review_count = $3 where user_id = $1', [id, rating, reviews]);
  for (const [g, c] of areas) await u.query('insert into public.service_areas (professional_id, governorate_id, city_id) values ($1, $2, $3)', [id, g, c]);
  return id;
}

describe('search_normalize on the shared vectors (the Dart mirror runs the same file)', () => {
  let db;
  before(async () => { db = await newDb(); });
  for (const [input, expected] of vectors) {
    test(JSON.stringify(input), async () => {
      const r = await db.query('select public.search_normalize($1) as v', [input]);
      assert.equal(r.rows[0].v, expected);
    });
  }
});

describe('search semantics found in review', () => {
  let db, ids, marsa, tunisCity, ariana, raoued;
  before(async () => {
    db = await newDb();
    const city = async (n) => (await db.query(`select id from public.cities where name_fr = $1`, [n])).rows[0].id;
    marsa = await city('La Marsa');
    tunisCity = await city('Tunis');
    ariana = await city('Ariana');
    raoued = await city('Raoued');
    ids = {};
    ids.basedMarsa = await addPro(db, { name: 'Basé La Marsa', gov: 11, city: marsa, lat: 36.88, lng: 10.32, rating: 4, reviews: 5 });
    ids.servesArianaCity = await addPro(db, { name: 'Sert la ville Ariana', gov: 11, city: tunisCity, areas: [[12, ariana]], rating: 4.5, reviews: 6 });
    ids.servesArianaGov = await addPro(db, { name: 'Sert tout le gouvernorat Ariana', gov: 11, city: tunisCity, areas: [[12, null]], rating: 3, reviews: 2 });
    ids.basedRaoued = await addPro(db, { name: 'Basé Raoued', gov: 12, city: raoued, rating: 2, reviews: 1 });
  });

  test('a governorate-wide service area satisfies a city request inside that governorate', async () => {
    const r = names(await call(anon(db), { city: raoued })).sort();
    assert.deepEqual(r, ['Basé Raoued', 'Sert tout le gouvernorat Ariana'].sort());
  });

  test('a city service area matches only that city', async () => {
    const r = names(await call(anon(db), { city: ariana })).sort();
    assert.deepEqual(r, ['Sert la ville Ariana', 'Sert tout le gouvernorat Ariana'].sort());
    assert.ok(!names(await call(anon(db), { city: marsa })).includes('Sert la ville Ariana'));
  });

  test('governorate and city must belong together; otherwise nothing matches', async () => {
    // Raoued is in Ariana (12), not Tunis (11)
    assert.deepEqual(names(await call(anon(db), { gov: 11, city: raoued })), []);
    // the consistent pair works
    assert.deepEqual(names(await call(anon(db), { gov: 12, city: raoued })).sort(), ['Basé Raoued', 'Sert tout le gouvernorat Ariana'].sort());
  });

  test("a Tunis-based professional who serves Ariana is NOT a match for 'Tunis city + Ariana governorate'", async () => {
    const r = names(await call(anon(db), { gov: 12, city: tunisCity }));
    assert.deepEqual(r, [], 'the pair is inconsistent (Tunis city is in governorate 11)');
  });

  test('governorate alone: based there or serving it', async () => {
    const r = names(await call(anon(db), { gov: 12 })).sort();
    assert.deepEqual(r, ['Basé Raoued', 'Sert la ville Ariana', 'Sert tout le gouvernorat Ariana'].sort());
  });

  test('query length is capped; very long text is cheap and harmless', async () => {
    const started = Date.now();
    const r = await call(anon(db), { q: 'a'.repeat(100000) });
    assert.ok(Array.isArray(r.rows));
    assert.ok(Date.now() - started < 3000, 'no pathological cost');
    // The cap means a match that only exists beyond 100 characters is not used.
    const q = 'basé la marsa' + ' '.repeat(100) + 'zzz';
    assert.deepEqual(names(await call(anon(db), { q })), ['Basé La Marsa'], 'only the first 100 characters count');
  });

  test('whitespace of any kind is collapsed; tab/space-only means no filter', async () => {
    assert.equal((await call(anon(db), { q: '\t \n ', limit: 50 })).rows.length, 4);
    assert.deepEqual(names(await call(anon(db), { q: 'basé\t\t  la   marsa' })), ['Basé La Marsa']);
  });

  test('offset is capped, so deep paging cannot be abused', async () => {
    const r = await call(anon(db), { offset: 10 ** 9 });
    assert.equal(r.rows.length, 0);
  });

  test('the offset cap is part of the function (its effect needs >5000 rows to observe)', async () => {
    const src = (await db.query(`select pg_get_functiondef(p.oid) as d from pg_proc p where p.proname = 'search_professionals'`)).rows[0].d;
    assert.match(src, /least\(coalesce\(p_offset, 0\), 5000\)/);
    assert.match(src, /least\(coalesce\(p_limit, 20\), 50\)/);
    assert.match(src, /left\(p_query, 100\)/);
  });

  test('an explicit position wins; everyone else is placed at their governorate (migration 1600)', async () => {
    const r = await call(anon(db), { sort: 'nearest', lat: 36.88, lng: 10.32, limit: 50 });
    assert.equal(r.rows[0].business_name, 'Basé La Marsa');
    assert.ok(r.rows.every((x) => x.distance_km !== null), 'a published profile always has a position now');
  });

  test('more than 50 matches: the page is capped at 50 and paging continues', async () => {
    for (let i = 0; i < 52; i++) await addPro(db, { name: `Bulk ${String(i).padStart(2, '0')}`, cat: 9, rating: 1, reviews: 1 });
    const p1 = await call(anon(db), { cat: 9, limit: 1000 });
    assert.equal(p1.rows.length, 50);
    const p2 = await call(anon(db), { cat: 9, limit: 1000, offset: 50 });
    assert.equal(p2.rows.length, 2);
    const all = [...p1.rows, ...p2.rows].map((x) => x.user_id);
    assert.equal(new Set(all).size, 52, 'no duplicates across pages');
  });

  test('a literal backslash or percent in a name can be found by searching for it', async () => {
    await addPro(db, { name: 'Remise 50% C:\\Atelier', cat: 11 });
    assert.deepEqual(names(await call(anon(db), { q: '50%' })), ['Remise 50% C:\\Atelier']);
    assert.deepEqual(names(await call(anon(db), { q: 'c:\\atelier' })), ['Remise 50% C:\\Atelier']);
    assert.deepEqual(names(await call(anon(db), { q: '5_%' })), [], 'underscore is literal, not a wildcard');
  });

  test('text fields are matched one by one: no match across the boundary of two fields', async () => {
    // "Basé La Marsa" + description starts with "Basé La Marsa:" ; a query spanning name end and
    // category start must not match.
    assert.deepEqual(names(await call(anon(db), { q: 'marsa plomberie' })), []);
  });
});
