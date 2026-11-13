// Cross-tenant pen-test of every table, column grant, storage bucket and
// id-taking function (#55). A world with one row in every table is built,
// then a stranger (registered, unrelated), an anonymous visitor and the
// owners try to read, write and call. Adding a table without classifying it
// here fails the suite.
import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import { newDb, createUser, makeAdmin, as, anon, user, DENIED } from './harness.mjs';

/** How each public table may be read. */
const TABLES = {
  // every row public
  governorates: 'reference', cities: 'reference', neighborhoods: 'reference',
  service_categories: 'reference', digital_categories: 'reference', subscription_plans: 'reference',
  // published rows public, the rest only to the owner
  professional_profiles: 'public', professional_services: 'public', service_areas: 'public',
  portfolio_items: 'public', reviews: 'public', freelancer_profiles: 'public',
  freelancer_portfolio_items: 'public', testimonials: 'public',
  // only the owner or the parties
  profiles: 'private', customer_profiles: 'private', favorites: 'private', quote_requests: 'private',
  quote_offers: 'private', bookings: 'private', request_photos: 'private', conversations: 'private',
  messages: 'private', notification_preferences: 'private', payment_orders: 'private',
  subscriptions: 'private', freelancer_invites: 'private',
  // no client role reads them at all (functions only)
  contact_reveals: 'closed', device_tokens: 'closed', notification_outbox: 'closed',
  storage_cleanup_queue: 'closed', admin_audit_log: 'closed', admin_users: 'closed',
  verification_requests: 'closed', verification_documents: 'closed', reports: 'closed',
  admin_config: 'closed', payment_events: 'closed', payment_settings: 'closed', suspension_appeals: 'closed',
  payment_proofs: 'closed', job_deliveries: 'closed', delivery_files: 'closed',
};

/** For "public" tables: the column naming the owner, to look for a hidden owner's rows. */
const OWNER_COL = {
  professional_profiles: 'user_id', professional_services: 'professional_id', service_areas: 'professional_id',
  portfolio_items: 'professional_id', reviews: 'subject_id', freelancer_profiles: 'user_id',
  freelancer_portfolio_items: 'freelancer_id', testimonials: 'freelancer_id',
};

/** Every column a client role may read or write, reviewed in #55. A new or
 * widened grant fails here until it is reviewed and added. */
const COLUMN_GRANTS = {
  'bookings authenticated SELECT': 'cancelled_at cancelled_by completed_at created_at customer_id done_at id offer_id price_tnd professional_id request_id revisions_used started_at status updated_at',
  'cities anon SELECT': 'governorate_id id latitude longitude name_ar name_en name_fr',
  'cities authenticated SELECT': 'governorate_id id latitude longitude name_ar name_en name_fr',
  'conversations authenticated SELECT': 'created_at id last_message_at offer_id',
  'customer_profiles authenticated SELECT': 'created_at default_city_id default_governorate_id file_alias updated_at user_id',
  'customer_profiles authenticated UPDATE': 'default_city_id default_governorate_id',
  'digital_categories anon SELECT': 'icon id is_active name_ar name_en name_fr slug sort_order',
  'digital_categories authenticated SELECT': 'icon id is_active name_ar name_en name_fr slug sort_order',
  'favorites authenticated INSERT': 'created_at professional_id user_id',
  'favorites authenticated SELECT': 'created_at professional_id user_id',
  'freelancer_invites authenticated SELECT': 'created_at expires_at freelancer_id id label used_at',
  'freelancer_portfolio_items anon SELECT': 'created_at description freelancer_id id kind path sort_order title url',
  'freelancer_portfolio_items authenticated INSERT': 'created_at description freelancer_id id kind path sort_order title url',
  'freelancer_portfolio_items authenticated SELECT': 'created_at description freelancer_id id kind path sort_order title url',
  'freelancer_portfolio_items authenticated UPDATE': 'description sort_order title',
  'freelancer_profiles anon SELECT': 'availability bio created_at display_name headline is_published languages price_unit primary_category_id rating_avg review_count skills starting_price_millimes user_id years_experience',
  'freelancer_profiles authenticated SELECT': 'admin_hold_reason availability bio created_at display_name headline is_published languages price_unit primary_category_id rating_avg review_count skills starting_price_millimes user_id years_experience',
  'freelancer_profiles authenticated UPDATE': 'availability bio display_name headline is_published languages price_unit primary_category_id skills starting_price_millimes years_experience',
  'governorates anon SELECT': 'code id latitude longitude name_ar name_en name_fr',
  'governorates authenticated SELECT': 'code id latitude longitude name_ar name_en name_fr',
  'messages authenticated SELECT': 'body conversation_id created_at id image_path sender_is_customer',
  'neighborhoods anon SELECT': 'city_id id name_ar name_en name_fr',
  'neighborhoods authenticated SELECT': 'city_id id name_ar name_en name_fr',
  'notification_preferences authenticated SELECT': 'jobs messages offers updated_at user_id',
  'payment_orders authenticated SELECT': 'admin_note amount_millimes created_at currency id method paid_at payer_note plan_code reference status',
  'portfolio_items anon SELECT': 'caption created_at id path professional_id',
  'portfolio_items authenticated INSERT': 'caption created_at id path professional_id',
  'portfolio_items authenticated SELECT': 'caption created_at id path professional_id',
  'portfolio_items authenticated UPDATE': 'caption',
  'professional_profiles anon SELECT': 'availability avatar_path business_name city_id created_at description governorate_id is_published latitude longitude neighborhood_id primary_category_id rating_avg review_count user_id verification_status verified_until years_experience',
  'professional_profiles authenticated SELECT': 'availability avatar_path business_name city_id created_at description governorate_id is_published latitude longitude neighborhood_id primary_category_id rating_avg review_count user_id verification_status verified_until years_experience',
  'professional_profiles authenticated UPDATE': 'availability avatar_path business_name city_id contact_phone description governorate_id is_published latitude longitude neighborhood_id primary_category_id years_experience',
  'professional_services anon SELECT': 'category_id created_at professional_id',
  'professional_services authenticated INSERT': 'category_id created_at professional_id',
  'professional_services authenticated SELECT': 'category_id created_at professional_id',
  'profiles authenticated SELECT': 'avatar_path avatar_url created_at full_name id is_customer is_professional phone preferred_language updated_at',
  'profiles authenticated UPDATE': 'avatar_path avatar_url full_name phone preferred_language',
  'quote_offers authenticated SELECT': 'created_at estimated_days id message price_tnd professional_id request_id revisions status updated_at',
  'quote_requests authenticated SELECT': 'budget_max_tnd budget_tnd category_id city_id created_at deliverables description digital_category_id expires_at governorate_id id kind needed_by reference_links status title updated_at',
  'request_photos authenticated INSERT': 'created_at id path request_id',
  'request_photos authenticated SELECT': 'created_at id path request_id',
  'reviews anon SELECT': 'comment id rating reviewed_month seq status subject_id',
  'reviews authenticated SELECT': 'comment id rating reviewed_month seq status subject_id',
  'service_areas anon SELECT': 'city_id created_at governorate_id id professional_id',
  'service_areas authenticated INSERT': 'city_id created_at governorate_id id professional_id',
  'service_areas authenticated SELECT': 'city_id created_at governorate_id id professional_id',
  'service_categories anon SELECT': 'created_at description_ar description_en description_fr icon id is_active name_ar name_en name_fr slug sort_order updated_at',
  'service_categories authenticated SELECT': 'created_at description_ar description_en description_fr icon id is_active name_ar name_en name_fr slug sort_order updated_at',
  'subscription_plans anon SELECT': 'amount_millimes code is_active name_ar name_en name_fr period_days sort_order',
  'subscription_plans authenticated SELECT': 'amount_millimes code is_active name_ar name_en name_fr period_days sort_order',
  'subscriptions authenticated SELECT': 'created_at current_period_end plan_code status updated_at user_id',
  'testimonials anon SELECT': 'author_name body created_at freelancer_id id project_title rating status',
  'testimonials authenticated SELECT': 'author_name body created_at freelancer_id id project_title rating status',
};

const count = async (client, sql, args = []) => Number((await client.query(sql, args)).rows[0].n);
const outcome = (promise) =>
  promise.then((r) => ({ ok: true, rows: r.affectedRows ?? r.rows.length }), (e) => ({ ok: false, code: e.code }));

async function pro(db, publish = true) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(
    `update public.professional_profiles
        set business_name = 'Pro ' || left($1::text, 4), primary_category_id = 1,
            description = 'Plombier avec dix ans d experience.', governorate_id = 11,
            contact_phone = '+21620123456', is_published = $2
      where user_id = $1`, [id, publish]);
  return id;
}

describe('RLS and API pen-test across every table', () => {
  let db, admin, p, c, s, hidden, ids;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    p = await pro(db); // the professional owner
    c = await createUser(db); // their customer
    s = await createUser(db); // a stranger
    hidden = await pro(db, false); // an unpublished professional
    const call = (who, sql, ...args) => user(db, who).query(sql, args).then((r) => r.rows[0]);
    ids = {};

    // marketplace rows of p, and the same kinds of rows for the hidden pro
    for (const who of [p, hidden]) {
      await user(db, who).query('insert into public.professional_services (professional_id, category_id) values ($1, 2)', [who]);
      await user(db, who).query('insert into public.service_areas (professional_id, governorate_id) values ($1, 12)', [who]);
      await user(db, who).query(`insert into storage.objects (bucket_id, name, owner) values ('portfolio', $1, $2)`, [`${who}/w.jpg`, who]);
      await user(db, who).query('insert into public.portfolio_items (professional_id, path) values ($1, $2)', [who, `${who}/w.jpg`]);
    }
    // freelance: p is a visible freelancer, hidden is not
    await db.query(`update public.professional_profiles set verification_status = 'verified', verified_at = now() where user_id = $1`, [p]);
    for (const who of [p, hidden]) {
      await user(db, who).query('select public.become_freelancer()');
      await user(db, who).query(
        `update public.freelancer_profiles set display_name = 'Sami', headline = 'Developpeur web',
           primary_category_id = 1, bio = 'Sites et applications web depuis dix ans.' where user_id = $1`, [who]);
      await user(db, who).query(
        `insert into public.freelancer_portfolio_items (freelancer_id, kind, title, url) values ($1, 'link', 'Site', 'https://example.tn')`, [who]);
    }
    await user(db, p).query('update public.freelancer_profiles set is_published = true where user_id = $1', [p]);
    const token = (await call(p, 'select public.create_testimonial_invite($1) as t', 'client')).t;
    await anon(db).query('select public.submit_testimonial($1, $2, 5::smallint, $3, null)', [token, 'Client', 'Tres bon travail, merci.']);
    // invisible freelancers cannot collect testimonials; one is planted to check it stays hidden
    await db.query(`insert into public.testimonials (freelancer_id, author_name, rating, body) values ($1, 'Client', 4, 'Un autre bon travail.')`, [hidden]);
    for (const who of [p, hidden]) await call(who, 'select public.create_testimonial_invite($1) as t', 'unused');

    // a full job between c and p: request, offer, booking, chat, review
    ids.request = (await call(c, `select public.create_quote_request('Fuite sous évier', 'Une fuite sous le lavabo.', 1::smallint, 11::smallint) as id`)).id;
    ids.offer = (await call(p, 'select public.submit_offer($1, 100::numeric) as id', ids.request)).id;
    ids.conversation = (await call(c, 'select public.start_conversation($1) as id', ids.offer)).id;
    ids.message = (await call(p, 'select public.send_message($1, $2) as id', ids.conversation, 'Bonjour')).id;
    ids.booking = (await call(c, 'select public.accept_offer($1) as id', ids.offer)).id;
    await call(p, 'select public.start_booking($1)', ids.booking);
    await call(p, 'select public.mark_booking_done($1)', ids.booking);
    await call(c, 'select public.confirm_booking_completed($1)', ids.booking);
    ids.review = (await call(c, 'select public.submit_review($1, 5::smallint, $2) as id', ids.booking, 'Tres bien')).id;
    ids.remote = (await call(c, `select public.create_remote_request('Logo', 'Un logo pour ma boutique.', 1::smallint, 'Fichiers PNG et SVG') as id`)).id;
    ids.remoteOffer = (await call(p, 'select public.submit_remote_offer($1, 300::numeric, 5::smallint, 2::smallint) as id', ids.remote)).id;
    ids.remoteBooking = (await call(c, 'select public.accept_offer($1) as id', ids.remoteOffer)).id;
    await call(p, 'select public.start_booking($1)', ids.remoteBooking);
    await user(db, p).query(`insert into storage.objects (bucket_id, name, owner) values ('deliveries', $1, $2)`, [`${ids.remoteBooking}/logo.png`, p]);
    await call(p, 'select public.deliver_booking($1, $2, null, $3::text[])', ids.remoteBooking, 'Voici le logo', [`${ids.remoteBooking}/logo.png`]);
    ids.photoRequest = (await call(c, `select public.create_quote_request('Peinture', 'Repeindre une chambre.', 1::smallint, 11::smallint) as id`)).id;
    await db.query(`insert into public.request_photos (request_id, path) values ($1, $2)`, [ids.photoRequest, `${randomUUID()}/p.jpg`]);

    // personal rows
    await user(db, c).query('insert into public.favorites (user_id, professional_id) values ($1, $2)', [c, p]);
    await call(c, 'select public.set_notification_preferences(true, true, false)');
    await call(c, 'select public.register_device_token($1, $2)', 'a'.repeat(64), 'ios');
    await call(c, 'select public.reveal_professional_contact($1)', p);
    await call(c, 'select public.report_content($1, $2, $3)', 'professional', p, 'spam');
    ids.order = (await call(p, 'select * from public.create_payment_order($1, $2)', 'standard', 'bank_transfer')).id;
    await user(db, p).query(`insert into storage.objects (bucket_id, name, owner) values ('payment-proofs', $1, $2)`, [`${p}/proof.jpg`, p]);
    await call(p, 'select public.attach_payment_proof($1, $2)', ids.order, `${p}/proof.jpg`);
    await db.query(`insert into public.subscriptions (user_id, plan_code, status, current_period_end) values ($1, 'standard', 'active', now() + interval '30 days')`, [p]);
    await db.query(`insert into public.payment_events (provider, event_id) values ('test', $1)`, [randomUUID()]);
    await db.query(`insert into public.storage_cleanup_queue (bucket_id, name) values ('portfolio', 'gone.jpg')`);
    await db.query(`insert into public.payment_settings (key, value) values ('d17_number', '12345678')`);
    // verification request with a document, and a suspension appeal
    const v = await pro(db);
    await user(db, v).query(`insert into storage.objects (bucket_id, name, owner) values ('verification-docs', $1, $2)`, [`${v}/id.jpg`, v]);
    await call(v, 'select public.submit_verification($1::text[])', [`${v}/id.jpg`]);
    await user(db, admin).query('select public.admin_suspend($1, 7, $2)', [hidden, 'Test']);
    await call(hidden, 'select public.submit_appeal($1)', 'Je conteste cette suspension.');
    ids.hidden = hidden;
  });

  test('every public table is classified here (a new table must be added on purpose)', async () => {
    const r = await db.query(`select tablename from pg_tables where schemaname = 'public' order by 1`);
    assert.deepEqual(r.rows.map((x) => x.tablename).sort(), Object.keys(TABLES).sort());
  });

  test('column grants of anon and authenticated match the reviewed snapshot exactly', async () => {
    const r = await db.query(
      `select table_name, grantee, privilege_type, string_agg(column_name, ' ' order by column_name) as cols
         from information_schema.column_privileges
        where table_schema = 'public' and grantee in ('anon', 'authenticated')
        group by 1, 2, 3`);
    const got = Object.fromEntries(r.rows.map((x) => [`${x.table_name} ${x.grantee} ${x.privilege_type}`, x.cols]));
    assert.deepEqual(got, COLUMN_GRANTS);
  });

  test('the world has rows in every table, so no check below is empty', async () => {
    const empty = [];
    for (const t of Object.keys(TABLES)) {
      if ((await count(db, `select count(*) as n from public.${t}`)) === 0) empty.push(t);
    }
    assert.deepEqual(empty, []);
  });

  test('reference tables: visitors and strangers read the same, non-empty rows', async () => {
    for (const [t, kind] of Object.entries(TABLES)) {
      if (kind !== 'reference') continue;
      const a = await count(anon(db), `select count(*) as n from public.${t}`);
      assert.ok(a > 0, t);
      assert.equal(await count(user(db, s), `select count(*) as n from public.${t}`), a, t);
    }
  });

  test('public tables: a stranger sees exactly what a visitor sees, and nothing of a hidden owner', async () => {
    for (const [t, kind] of Object.entries(TABLES)) {
      if (kind !== 'public') continue;
      const q = `select count(*) as n from public.${t}`;
      const a = await count(anon(db), q);
      assert.ok(a > 0, `${t}: the published owner's rows are public`);
      assert.equal(await count(user(db, s), q), a, `${t}: no extra rows for registered strangers`);
      const h = `select count(*) as n from public.${t} where ${OWNER_COL[t]} = $1`;
      assert.equal(await count(anon(db), h, [hidden]), 0, `${t}: hidden owner invisible to visitors`);
      assert.equal(await count(user(db, s), h, [hidden]), 0, `${t}: hidden owner invisible to strangers`);
    }
    assert.equal(await count(anon(db), `select count(*) as n from public.reviews where status <> 'published'`), 0);
  });

  test('private tables: strangers and visitors read nothing; the owner or a party does', async () => {
    const owners = {
      profiles: c, customer_profiles: c, favorites: c, quote_requests: c, quote_offers: p, bookings: c,
      request_photos: c, conversations: p, messages: c, notification_preferences: c, payment_orders: p,
      subscriptions: p, freelancer_invites: p,
    };
    for (const [t, kind] of Object.entries(TABLES)) {
      if (kind !== 'private') continue;
      const q = `select count(*) as n from public.${t}`;
      // the stranger's own account rows are theirs; everything else must be invisible
      const mine = { profiles: 'id', customer_profiles: 'user_id', notification_preferences: 'user_id' }[t];
      const others = mine ? `${q} where ${mine} <> $1` : q;
      assert.equal(await count(user(db, s), others, mine ? [s] : []), 0, `${t}: stranger`);
      const v = await outcome(anon(db).query(q));
      assert.ok(!v.ok ? v.code === DENIED : Number((await anon(db).query(q)).rows[0].n) === 0, `${t}: visitor`);
      assert.ok(await count(user(db, owners[t]), q) > 0, `${t}: owner ${owners[t] === c ? 'customer' : 'professional'}`);
    }
  });

  test('closed tables: no client role reads them, not even their subject or an admin session', async () => {
    for (const [t, kind] of Object.entries(TABLES)) {
      if (kind !== 'closed') continue;
      for (const [who, client] of [['visitor', anon(db)], ['stranger', user(db, s)], ['owner', user(db, p)], ['admin', user(db, admin)]]) {
        const r = await outcome(client.query(`select count(*) as n from public.${t}`));
        assert.equal(r.code, DENIED, `${t} as ${who}`);
      }
    }
  });

  test('strangers change nothing: every granted update and delete touches zero rows', async () => {
    const before = {};
    for (const t of Object.keys(TABLES)) before[t] = await count(db, `select count(*) as n from public.${t}`);
    const grants = (await db.query(
      `select table_name, privilege_type, string_agg(column_name, ',') as cols
         from information_schema.column_privileges
        where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'UPDATE'
        group by 1, 2`)).rows;
    for (const g of grants) {
      for (const col of g.cols.split(',')) {
        // the stranger's own account rows are theirs to edit
        const self = { profiles: 'id', customer_profiles: 'user_id' }[g.table_name];
        const where = self ? ` where ${self} <> $1` : '';
        const r = await outcome(user(db, s).query(`update public.${g.table_name} set ${col} = ${col}${where}`, self ? [s] : []));
        assert.ok(r.ok ? r.rows === 0 : r.code === DENIED, `${g.table_name}.${col}: ${JSON.stringify(r)}`);
      }
    }
    const deletable = (await db.query(
      `select table_name from information_schema.table_privileges
        where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'DELETE'`)).rows;
    assert.ok(deletable.length > 0);
    for (const { table_name: t } of deletable) {
      const r = await outcome(user(db, s).query(`delete from public.${t}`));
      assert.ok(r.ok ? r.rows === 0 : r.code === DENIED, `${t}: ${JSON.stringify(r)}`);
    }
    for (const t of Object.keys(TABLES)) {
      assert.equal(await count(db, `select count(*) as n from public.${t}`), before[t], `${t} unchanged`);
    }
  });

  test('strangers cannot insert rows in someone else\'s name', async () => {
    const tries = [
      ['favorites', 'insert into public.favorites (user_id, professional_id) values ($1, $2)', [c, p]],
      ['portfolio_items', 'insert into public.portfolio_items (professional_id, path) values ($1, $2)', [p, `${p}/x.jpg`]],
      ['professional_services', 'insert into public.professional_services (professional_id, category_id) values ($1, 3)', [p]],
      ['service_areas', 'insert into public.service_areas (professional_id, governorate_id) values ($1, 13)', [p]],
      ['freelancer_portfolio_items', `insert into public.freelancer_portfolio_items (freelancer_id, kind, title, url) values ($1, 'link', 'x', 'https://x.tn')`, [p]],
      ['request_photos', 'insert into public.request_photos (request_id, path) values ($1, $2)', [ids.photoRequest, `${randomUUID()}/x.jpg`]],
    ];
    for (const [t, sql, args] of tries) {
      const r = await outcome(user(db, s).query(sql, args));
      assert.equal(r.code, DENIED, `${t}: ${JSON.stringify(r)}`);
    }
  });

  test('owners cannot mass-assign any column outside their grant (badge, rating, status, roles)', async () => {
    const tables = (await db.query(
      `select distinct table_name from information_schema.column_privileges
        where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'UPDATE'`)).rows.map((x) => x.table_name);
    const owner = { profiles: p, customer_profiles: c, professional_profiles: p, portfolio_items: p, freelancer_profiles: p, freelancer_portfolio_items: p };
    assert.deepEqual(tables.sort(), Object.keys(owner).sort(), 'owner map covers every updatable table');
    for (const t of tables) {
      const cols = (await db.query(
        `select c.column_name,
                has_column_privilege('authenticated', format('public.%I', $1::text), c.column_name, 'UPDATE') as ok
           from information_schema.columns c where c.table_schema = 'public' and c.table_name = $1`, [t])).rows;
      const forbidden = cols.filter((x) => !x.ok).map((x) => x.column_name);
      assert.ok(forbidden.length > 0, t);
      for (const col of forbidden) {
        const r = await outcome(user(db, owner[t]).query(`update public.${t} set ${col} = ${col}`));
        assert.equal(r.code, DENIED, `${t}.${col} must not be client-writable`);
      }
    }
  });

  test('storage: strangers list nothing private and cannot write into anyone\'s folder', async () => {
    const buckets = (await db.query('select id, public from storage.buckets order by id')).rows;
    for (const b of buckets) {
      const theirs = await count(db, 'select count(*) as n from storage.objects where bucket_id = $1', [b.id]);
      const seen = await count(user(db, s), 'select count(*) as n from storage.objects where bucket_id = $1', [b.id]);
      assert.equal(seen, 0, `${b.id}: listing (${theirs} files exist)`);
      for (const folder of [p, c, ids.conversation, ids.request]) {
        const r = await outcome(user(db, s).query(
          'insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)', [b.id, `${folder}/guess.jpg`, s]));
        assert.equal(r.code, DENIED, `${b.id}/${folder}`);
      }
    }
  });

  test('every admin function refuses non-admins before doing anything', async () => {
    const fns = (await db.query(
      `select p.proname, pg_get_function_identity_arguments(p.oid) as args,
              array(select format_type(t, null) from unnest(p.proargtypes) t) as types
         from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname like 'admin\\_%'
          and has_function_privilege('authenticated', p.oid, 'execute')`)).rows;
    assert.ok(fns.length >= 20, `found ${fns.length}`);
    for (const f of fns) {
      const callArgs = f.types.map((t) => `null::${t}`).join(', ');
      for (const who of [s, p]) {
        const r = await outcome(user(db, who).query(`select public.${f.proname}(${callArgs})`));
        assert.equal(r.code, DENIED, `${f.proname}(${f.args}) as non-admin: ${JSON.stringify(r)}`);
      }
      const v = await outcome(anon(db).query(`select public.${f.proname}(${callArgs})`));
      assert.equal(v.code, DENIED, `${f.proname} as visitor`);
    }
  });

  test('IDOR: a stranger calling id-taking functions with real ids gets nothing and changes nothing', async () => {
    // Predicates and public lookups that may answer (false/null/public data) instead of failing.
    const answers = new Set([
      'freelancer_is_visible', 'listing_allowed', 'has_offered_on', 'is_request_owner', 'owns_open_request', 'can_view_request_photos',
      'is_conversation_member', 'chat_folder_member', 'chat_folder_writable', 'chat_image_count',
      'reveal_professional_contact', 'reveal_freelancer_contact', 'request_photo_is_locked',
    ]);
    const fns = (await db.query(
      `select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and p.proname not like 'admin\\_%' and p.pronargs = 1
          and p.proargtypes[0] = 'uuid'::regtype
          and has_function_privilege('authenticated', p.oid, 'execute')`)).rows.map((x) => x.proname).sort();
    const targets = [ids.request, ids.offer, ids.booking, ids.conversation, ids.order, ids.review, ids.photoRequest, ids.remote, ids.remoteBooking, p, c];
    const snapshot = async () => JSON.stringify((await db.query(
      `select (select json_agg(r order by r.id) from public.quote_requests r) as r,
              (select json_agg(o order by o.id) from public.quote_offers o) as o,
              (select json_agg(b order by b.id) from public.bookings b) as b,
              (select json_agg(x order by x.id) from public.payment_orders x) as x`)).rows[0]);
    const before = await snapshot();
    const leaks = [];
    for (const fn of fns) {
      for (const id of targets) {
        const r = await outcome(user(db, s).query(`select * from public.${fn}($1)`, [id]));
        if (!r.ok) continue;
        const rows = (await user(db, s).query(`select * from public.${fn}($1)`, [id]).catch(() => ({ rows: [] }))).rows;
        const values = rows.flatMap((row) => Object.values(row)).filter((v) => v !== null && v !== false && v !== 0 && v !== '');
        if (values.length > 0 && !answers.has(fn)) leaks.push(`${fn}(${id === p ? 'p' : id === c ? 'c' : 'id'}) -> ${JSON.stringify(rows)}`);
        // membership predicates must say no to a stranger (visibility and reveals are public by design)
        if (answers.has(fn) && !['freelancer_is_visible', 'listing_allowed', 'reveal_professional_contact', 'reveal_freelancer_contact'].includes(fn) && values.length > 0) {
          leaks.push(`${fn} answered true for a stranger`);
        }
      }
    }
    assert.deepEqual(leaks, []);
    assert.equal(await snapshot(), before, 'no request, offer, booking or payment changed');
  });
});
