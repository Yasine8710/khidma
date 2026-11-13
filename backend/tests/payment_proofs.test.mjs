import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, anon, user, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);
const notFound = (promise) => assert.rejects(promise, (e) => e.code === 'P0002', 'expected not found');

async function pro(db) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  return id;
}
const order = async (db, who, method = 'bank_transfer', plan = 'standard') =>
  (await user(db, who).query('select * from public.create_payment_order($1, $2)', [plan, method])).rows[0].id;
const upload = (db, who, name, owner = who) =>
  user(db, who).query(`insert into storage.objects (bucket_id, name, owner) values ('payment-proofs', $1, $2)`, [`${owner}/${name}`, who]);
const attach = (db, who, o, path) => user(db, who).query('select public.attach_payment_proof($1, $2)', [o, path]);
const outbox = async (db, who, kind) =>
  (await db.query('select payload from public.notification_outbox where user_id = $1 and kind = $2', [who, kind])).rows;

describe('payment proofs', () => {
  let db, admin, p, other, o;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    p = await pro(db);
    other = await pro(db);
    o = await order(db, p);
  });

  test('a professional uploads into their own folder and attaches it to their own order', async () => {
    await upload(db, p, 'recu.jpg');
    await attach(db, p, o, `${p}/recu.jpg`);
    assert.equal((await user(db, p).query('select public.my_payment_proof_count($1) as n', [o])).rows[0].n, 1);
    await attach(db, p, o, `${p}/recu.jpg`); // idempotent
    assert.equal((await user(db, p).query('select public.my_payment_proof_count($1) as n', [o])).rows[0].n, 1);
  });

  test('nobody else reads the file, attaches to the order, or uses someone else\'s file', async () => {
    assert.equal((await user(db, other).query(`select name from storage.objects where bucket_id = 'payment-proofs'`)).rows.length, 0);
    await denies(upload(db, other, 'x.jpg', p), DENIED);
    await notFound(attach(db, other, o, `${p}/recu.jpg`));
    const mine = await order(db, other);
    await tagged(attach(db, other, mine, `${p}/recu.jpg`), 'invalid_input');
    await tagged(attach(db, p, o, `${p}/missing.jpg`), 'invalid_input');
    assert.equal((await user(db, other).query('select public.my_payment_proof_count($1) as n', [o])).rows[0].n, 0);
    const plain = await createUser(db);
    await denies(user(db, plain).query(`insert into storage.objects (bucket_id, name, owner) values ('payment-proofs', $1, $2)`, [`${plain}/a.jpg`, plain]), DENIED);
    await denies(anon(db).query('select public.attach_payment_proof($1, $2)', [o, `${p}/recu.jpg`]), DENIED);
  });

  test('only manual unpaid orders take proofs, at most 3', async () => {
    const f = await order(db, p, 'flouci', 'plus');
    await upload(db, p, 'f.jpg');
    await tagged(attach(db, p, f, `${p}/f.jpg`), 'invalid_transition');
    for (const n of ['b.jpg', 'c.png']) {
      await upload(db, p, n);
      await attach(db, p, o, `${p}/${n}`);
    }
    await upload(db, p, 'd.pdf');
    await tagged(attach(db, p, o, `${p}/d.pdf`), 'limit_reached');
  });

  test('an attached proof cannot be deleted; a stray upload can', async () => {
    const del = await user(db, p).query(`delete from storage.objects where bucket_id = 'payment-proofs' and name = $1`, [`${p}/recu.jpg`]);
    assert.equal(del.affectedRows, 0);
    const stray = await user(db, p).query(`delete from storage.objects where bucket_id = 'payment-proofs' and name = $1`, [`${p}/d.pdf`]);
    assert.equal(stray.affectedRows, 1);
  });

  test('admins get the paths through the audited function; others are refused', async () => {
    await denies(user(db, p).query('select * from public.admin_payment_proofs($1)', [o]), DENIED);
    const rows = (await user(db, admin).query('select * from public.admin_payment_proofs($1)', [o])).rows;
    assert.deepEqual(rows.map((r) => r.path).sort(), [`${p}/b.jpg`, `${p}/c.png`, `${p}/recu.jpg`]);
    const n = (await db.query(`select count(*)::int as n from public.admin_audit_log where action = 'view_payment_proofs' and target_id = $1`, [o])).rows[0].n;
    assert.equal(n, 1);
  });

  test('confirming or rejecting sends exactly one notice; the owner reads the rejection note', async () => {
    await user(db, p).query('select public.mark_payment_sent($1)', [o]);
    await user(db, admin).query('select public.admin_confirm_payment($1)', [o]);
    await user(db, admin).query('select public.admin_confirm_payment($1)', [o]); // a second click
    const done = await outbox(db, p, 'payment_confirmed');
    assert.equal(done.length, 1);
    assert.deepEqual(done[0].payload, { order_id: o });
    await upload(db, p, 'late.jpg');
    await tagged(attach(db, p, o, `${p}/late.jpg`), 'invalid_transition');

    const r = await order(db, other, 'd17');
    await user(db, other).query('select public.mark_payment_sent($1)', [r]);
    await user(db, admin).query('select public.admin_reject_payment($1, $2)', [r, 'Montant different']);
    assert.equal((await outbox(db, other, 'payment_rejected')).length, 1);
    const note = (await user(db, other).query('select admin_note from public.payment_orders where id = $1', [r])).rows[0].admin_note;
    assert.equal(note, 'Montant different');
    assert.equal((await user(db, p).query('select admin_note from public.payment_orders where id = $1', [r])).rows.length, 0);
  });

  test('deleting the account queues the proofs for the cleanup worker', async () => {
    const q = await pro(db);
    await upload(db, q, 'z.jpg');
    await user(db, q).query('select public.delete_my_account()');
    const queued = (await db.query(`select count(*)::int as n from public.storage_cleanup_queue where bucket_id = 'payment-proofs' and name = $1`, [`${q}/z.jpg`])).rows[0].n;
    assert.equal(queued, 1);
  });
});
