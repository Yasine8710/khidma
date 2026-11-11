import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import {
  newDb, createUser, makeAdmin, anon, user, denies, DENIED, CHECK, UNIQUE, FK,
} from './harness.mjs';

const GOOD = {
  cat: 1,
  desc: 'Plombier avec dix ans d expérience à Tunis.',
  gov: 11,
  phone: '+21620123456',
};

async function becomePro(db, id) {
  await user(db, id).query('select public.become_professional()');
}
async function publish(db, id, extra = '') {
  return user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Karim Plomberie', primary_category_id = $2, description = $3,
            governorate_id = $4, contact_phone = $5, is_published = true ${extra}
      where user_id = $1`,
    [id, GOOD.cat, GOOD.desc, GOOD.gov, GOOD.phone],
  );
}

describe('become_professional', () => {
  let db, a, b;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
    b = await createUser(db);
  });

  test('creates an unpublished professional profile and flips the flag', async () => {
    await becomePro(db, a);
    const p = await user(db, a).query('select is_professional, is_customer from public.profiles');
    assert.deepEqual(p.rows[0], { is_professional: true, is_customer: true });
    const pp = await user(db, a).query('select is_published, verification_status from public.professional_profiles');
    assert.deepEqual(pp.rows[0], { is_published: false, verification_status: 'unverified' });
  });

  test('is idempotent', async () => {
    await becomePro(db, a);
    const n = await db.query('select count(*)::int as n from public.professional_profiles where user_id = $1', [a]);
    assert.equal(n.rows[0].n, 1);
  });

  test('only affects the caller', async () => {
    const r = await user(db, b).query('select is_professional from public.profiles');
    assert.equal(r.rows[0].is_professional, false);
  });

  test('anonymous callers cannot execute it', async () => {
    await denies(anon(db).query('select public.become_professional()'), DENIED);
  });

  test('an authenticated role with no user id is refused', async () => {
    await denies(user(db, null).query('select public.become_professional()'), '28000');
  });
});

describe('professional profile visibility', () => {
  let db, pub, draft, viewer, admin;
  before(async () => {
    db = await newDb();
    pub = await createUser(db);
    draft = await createUser(db);
    viewer = await createUser(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
    await becomePro(db, pub);
    await becomePro(db, draft);
    await publish(db, pub);
  });

  test('anonymous sees published profiles only', async () => {
    const r = await anon(db).query('select user_id from public.professional_profiles');
    assert.deepEqual(r.rows.map((x) => x.user_id), [pub]);
  });

  test('signed-in users see published profiles, not other people\'s drafts', async () => {
    const r = await user(db, viewer).query('select user_id from public.professional_profiles');
    assert.deepEqual(r.rows.map((x) => x.user_id), [pub]);
  });

  test('owners always see their own draft', async () => {
    const r = await user(db, draft).query('select user_id from public.professional_profiles');
    // their own draft plus the one published profile
    assert.deepEqual(r.rows.map((x) => x.user_id).sort(), [pub, draft].sort());
  });

  test('admins can see drafts too', async () => {
    const r = await user(db, admin).query('select user_id from public.professional_profiles');
    assert.equal(r.rows.length, 2);
  });

  test('the contact phone is not selectable by anyone, signed in or not', async () => {
    for (const who of [anon(db), user(db, viewer), user(db, pub)]) {
      await denies(who.query('select contact_phone from public.professional_profiles'), DENIED);
      await denies(who.query('select * from public.professional_profiles'), DENIED);
      await denies(who.query('select verified_at from public.professional_profiles'), DENIED);
    }
    const ok = await anon(db).query('select user_id, business_name, rating_avg from public.professional_profiles');
    assert.equal(ok.rows.length, 1);
  });

  test('a signed-in user reveals a published phone through the function', async () => {
    const r = await user(db, viewer).query('select public.reveal_professional_contact($1) as phone', [pub]);
    assert.equal(r.rows[0].phone, GOOD.phone);
  });

  test('a draft\'s phone cannot be revealed to others, but the owner can read it', async () => {
    await user(db, draft).query(`update public.professional_profiles set contact_phone = '+21671123456' where user_id = $1`, [draft]);
    await denies(user(db, viewer).query('select public.reveal_professional_contact($1)', [draft]), 'P0002');
    const own = await user(db, draft).query('select public.get_my_professional_contact() as phone');
    assert.equal(own.rows[0].phone, '+21671123456');
  });
});

describe('professional profile writes', () => {
  let db, a, b;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
    b = await createUser(db);
    await becomePro(db, a);
    await becomePro(db, b);
  });

  test('cannot publish an incomplete profile', async () => {
    await denies(
      user(db, a).query('update public.professional_profiles set is_published = true where user_id = $1', [a]),
      CHECK,
    );
    await denies(
      user(db, a).query(
        `update public.professional_profiles set is_published = true, primary_category_id = 1,
           description = 'trop court', governorate_id = 11, contact_phone = '+21620123456' where user_id = $1`, [a]),
      CHECK,
    );
  });

  test('a complete profile can be published and unpublished', async () => {
    assert.equal((await publish(db, a)).affectedRows, 1);
    const off = await user(db, a).query('update public.professional_profiles set is_published = false where user_id = $1', [a]);
    assert.equal(off.affectedRows, 1);
  });

  test('owners cannot touch verification, rating or review counters', async () => {
    for (const set of [`verification_status = 'verified'`, 'verified_at = now()', 'rating_avg = 5',
                       'review_count = 100', 'user_id = gen_random_uuid()', 'created_at = now()']) {
      await denies(user(db, a).query(`update public.professional_profiles set ${set} where user_id = $1`, [a]), DENIED);
    }
  });

  test('cannot edit another professional (0 rows)', async () => {
    const r = await user(db, a).query(`update public.professional_profiles set description = 'hijack hijack hijack' where user_id = $1`, [b]);
    assert.equal(r.affectedRows, 0);
  });

  test('anonymous cannot write; nobody can insert or delete directly', async () => {
    await denies(anon(db).query(`update public.professional_profiles set business_name = 'x'`), DENIED);
    await denies(user(db, a).query('insert into public.professional_profiles (user_id) values ($1)', [a]), DENIED);
    await denies(user(db, a).query('delete from public.professional_profiles where user_id = $1', [a]), DENIED);
  });

  test('location is rounded to ~1.1 km and must come as a pair', async () => {
    await user(db, a).query('update public.professional_profiles set latitude = 36.874321, longitude = 10.324567 where user_id = $1', [a]);
    const r = await user(db, a).query('select latitude, longitude from public.professional_profiles where user_id = $1', [a]);
    assert.equal(r.rows[0].latitude, 36.87);
    assert.equal(r.rows[0].longitude, 10.32);
    await denies(user(db, a).query('update public.professional_profiles set latitude = 36.8, longitude = null where user_id = $1', [a]), CHECK);
    await denies(user(db, a).query('update public.professional_profiles set latitude = 95, longitude = 10 where user_id = $1', [a]), CHECK);
  });

  test('city must belong to the governorate; neighborhood to the city', async () => {
    const ariana = (await db.query(`select id from public.cities where name_fr = 'Ariana'`)).rows[0].id; // gov 12
    const marsa = (await db.query(`select id from public.cities where name_fr = 'La Marsa'`)).rows[0].id; // gov 11
    const gammarth = (await db.query(`select id from public.neighborhoods where name_fr = 'Gammarth'`)).rows[0].id; // marsa
    await denies(user(db, a).query('update public.professional_profiles set governorate_id = 11, city_id = $1 where user_id = $2', [ariana, a]), FK);
    await denies(user(db, a).query('update public.professional_profiles set governorate_id = null, city_id = $1 where user_id = $2', [marsa, a]), CHECK);
    await denies(user(db, a).query('update public.professional_profiles set governorate_id = 12, city_id = $1, neighborhood_id = $2 where user_id = $3', [ariana, gammarth, a]), FK);
    const ok = await user(db, a).query('update public.professional_profiles set governorate_id = 11, city_id = $1, neighborhood_id = $2 where user_id = $3', [marsa, gammarth, a]);
    assert.equal(ok.affectedRows, 1);
  });

  test('value limits and phone format are enforced', async () => {
    await denies(user(db, a).query('update public.professional_profiles set years_experience = 61 where user_id = $1', [a]), CHECK);
    await denies(user(db, a).query(`update public.professional_profiles set availability = 'sleeping' where user_id = $1`, [a]), CHECK);
    await denies(user(db, a).query(`update public.professional_profiles set contact_phone = '12345' where user_id = $1`, [a]), CHECK);
    await denies(user(db, a).query('update public.professional_profiles set description = $1 where user_id = $2', ['x'.repeat(2001), a]), CHECK);
  });
});

describe('admin verification', () => {
  let db, pro, other, admin;
  before(async () => {
    db = await newDb();
    pro = await createUser(db);
    other = await createUser(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
    await becomePro(db, pro);
    await publish(db, pro);
  });

  const submit = async () => {
    const name = `${pro}/${Math.random().toString(16).slice(2)}.jpg`;
    await db.query(`insert into storage.objects (bucket_id, name, owner) values ('verification-docs', $1, $2)`, [name, pro]);
    return (await user(db, pro).query('select public.submit_verification($1::text[]) as id', [[name]])).rows[0].id;
  };

  test('nobody can set the verification status directly, not even an admin', async () => {
    for (const who of [user(db, pro), user(db, other), user(db, admin), anon(db)]) {
      await denies(who.query(`select public.admin_set_verification($1, 'verified')`, [pro]), DENIED);
    }
  });

  test('an admin verifies through the review; the badge becomes public; timestamp set', async () => {
    await user(db, admin).query('select public.admin_review_verification($1, true)', [await submit()]);
    const r = await anon(db).query('select verification_status from public.professional_profiles');
    assert.equal(r.rows[0].verification_status, 'verified');
    const t = await db.query('select verified_at from public.professional_profiles where user_id = $1', [pro]);
    assert.ok(t.rows[0].verified_at);
  });

  test('rejecting clears the timestamp', async () => {
    await db.query(`update public.professional_profiles set verification_status = 'unverified', verified_at = null where user_id = $1`, [pro]);
    await user(db, admin).query('select public.admin_review_verification($1, false, $2)', [await submit(), 'Photo illisible']);
    const t = await db.query('select verified_at, verification_status from public.professional_profiles where user_id = $1', [pro]);
    assert.equal(t.rows[0].verified_at, null);
    assert.equal(t.rows[0].verification_status, 'rejected');
  });
});

describe('services and working areas', () => {
  let db, a, b;
  before(async () => {
    db = await newDb();
    a = await createUser(db);
    b = await createUser(db);
    await becomePro(db, a);
    await becomePro(db, b);
    await publish(db, a);
  });

  test('owners manage their own services; duplicates are rejected', async () => {
    await user(db, a).query('insert into public.professional_services (professional_id, category_id) values ($1, 1), ($1, 2)', [a]);
    await denies(user(db, a).query('insert into public.professional_services (professional_id, category_id) values ($1, 1)', [a]), UNIQUE);
    const del = await user(db, a).query('delete from public.professional_services where professional_id = $1 and category_id = 2', [a]);
    assert.equal(del.affectedRows, 1);
  });

  test('nobody can add or remove services for someone else', async () => {
    await denies(user(db, b).query('insert into public.professional_services (professional_id, category_id) values ($1, 3)', [a]), DENIED);
    const del = await user(db, b).query('delete from public.professional_services where professional_id = $1', [a]);
    assert.equal(del.affectedRows, 0);
    await denies(anon(db).query('insert into public.professional_services (professional_id, category_id) values ($1, 3)', [a]), DENIED);
  });

  test('services are public only while the profile is published', async () => {
    await user(db, b).query('insert into public.professional_services (professional_id, category_id) values ($1, 4)', [b]);
    const r = await anon(db).query('select professional_id from public.professional_services');
    assert.ok(r.rows.every((x) => x.professional_id === a));
    const own = await user(db, b).query('select professional_id from public.professional_services where professional_id = $1', [b]);
    assert.equal(own.rows.length, 1);
  });

  test('working areas: unique per place, city must match governorate', async () => {
    await user(db, a).query('insert into public.service_areas (professional_id, governorate_id) values ($1, 11)', [a]);
    await denies(user(db, a).query('insert into public.service_areas (professional_id, governorate_id) values ($1, 11)', [a]), UNIQUE);
    const marsa = (await db.query(`select id from public.cities where name_fr = 'La Marsa'`)).rows[0].id;
    await user(db, a).query('insert into public.service_areas (professional_id, governorate_id, city_id) values ($1, 11, $2)', [a, marsa]);
    await denies(user(db, a).query('insert into public.service_areas (professional_id, governorate_id, city_id) values ($1, 12, $2)', [a, marsa]), FK);
    await denies(user(db, b).query('insert into public.service_areas (professional_id, governorate_id) values ($1, 12)', [a]), DENIED);
  });

  test('deleting a professional profile removes their services and areas', async () => {
    await db.query('delete from auth.users where id = $1', [a]);
    for (const t of ['professional_services', 'service_areas']) {
      const r = await db.query(`select count(*)::int as n from public.${t} where professional_id = $1`, [a]);
      assert.equal(r.rows[0].n, 0, t);
    }
  });
});
