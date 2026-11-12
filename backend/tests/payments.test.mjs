import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { newDb, createUser, makeAdmin, as, anon, user, anonymousAuthUser, denies, DENIED } from './harness.mjs';

const service = (db) => as(db, 'service_role');
const order = async (db, who, plan = 'standard', method = 'bank_transfer') =>
  (await user(db, who).query('select * from public.create_payment_order($1, $2)', [plan, method])).rows[0];
const pro = async (db) => {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  return id;
};

describe('plans', () => {
  let db;
  before(async () => { db = await newDb(); });
  test('two plans in TND millimes, public, read-only', async () => {
    const r = await anon(db).query('select code, amount_millimes from public.subscription_plans order by sort_order');
    assert.deepEqual(r.rows, [{ code: 'standard', amount_millimes: 20000 }, { code: 'plus', amount_millimes: 30000 }]);
    const u = await createUser(db);
    await denies(user(db, u).query(`update public.subscription_plans set amount_millimes = 1`), DENIED);
  });
});

describe('creating and settling manual payments', () => {
  let db, p, admin;
  before(async () => {
    db = await newDb();
    p = await pro(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
  });

  test('an order has a reference, the plan amount and starts pending', async () => {
    const o = await order(db, p);
    assert.match(o.reference, /^KH-[0-9A-Z]{6}$/);
    assert.equal(o.amount_millimes, 20000);
    assert.equal(o.status, 'pending');
    assert.equal(o.method, 'bank_transfer');
  });

  test('asking again returns the same open order, not a duplicate', async () => {
    const a = await order(db, p);
    const b = await order(db, p);
    assert.equal(a.id, b.id);
    const c = await order(db, p, 'plus', 'bank_transfer');
    assert.notEqual(a.id, c.id);
    assert.equal(c.amount_millimes, 30000);
  });

  test('only professionals order; bad plan or method is refused; anon cannot', async () => {
    const plain = await createUser(db);
    await denies(user(db, plain).query('select * from public.create_payment_order($1, $2)', ['standard', 'd17']), DENIED);
    await denies(user(db, p).query('select * from public.create_payment_order($1, $2)', ['gold', 'd17']), 'P0001');
    await denies(user(db, p).query('select * from public.create_payment_order($1, $2)', ['standard', 'bitcoin']), 'P0001');
    await denies(anon(db).query('select * from public.create_payment_order($1, $2)', ['standard', 'd17']), DENIED);
    await denies(anonymousAuthUser(db, p).query('select * from public.create_payment_order($1, $2)', ['standard', 'd17']), DENIED);
  });

  test('I paid -> awaiting confirmation; an admin confirms; the subscription runs 30 days', async () => {
    const o = await order(db, p, 'standard', 'd17');
    await user(db, p).query('select public.mark_payment_sent($1, $2)', [o.id, 'virement 1234']);
    const q = await user(db, admin).query(`select * from public.admin_list_payment_orders('awaiting_confirmation')`);
    assert.ok(q.rows.some((x) => x.id === o.id && x.payer_note === 'virement 1234'));
    await user(db, admin).query('select public.admin_confirm_payment($1)', [o.id]);
    const s = (await user(db, p).query('select * from public.my_subscription()')).rows[0];
    assert.equal(s.plan_code, 'standard');
    assert.equal(s.status, 'active');
    assert.ok(s.days_left >= 29 && s.days_left <= 30);
    assert.equal((await db.query('select public.subscription_is_active($1) as a', [p])).rows[0].a, true);
    const paid = (await user(db, p).query('select status, paid_at from public.payment_orders where id = $1', [o.id])).rows[0];
    assert.equal(paid.status, 'paid');
    assert.ok(paid.paid_at);
  });

  test('confirming twice does not extend twice', async () => {
    const before = (await user(db, p).query('select current_period_end from public.my_subscription()')).rows[0].current_period_end;
    const id = (await db.query(`select id from public.payment_orders where user_id = $1 and status = 'paid' limit 1`, [p])).rows[0].id;
    await user(db, admin).query('select public.admin_confirm_payment($1)', [id]);
    const after = (await user(db, p).query('select current_period_end from public.my_subscription()')).rows[0].current_period_end;
    assert.equal(String(before), String(after));
  });

  test('a second paid order extends from the end of the current period', async () => {
    const before = (await user(db, p).query('select current_period_end from public.my_subscription()')).rows[0].current_period_end;
    const o = await order(db, p, 'plus', 'd17');
    await user(db, admin).query('select public.admin_confirm_payment($1)', [o.id]);
    const s = (await user(db, p).query('select * from public.my_subscription()')).rows[0];
    assert.equal(s.plan_code, 'plus');
    const diff = (new Date(s.current_period_end) - new Date(before)) / 86400000;
    assert.ok(Math.abs(diff - 30) < 0.01, `extended by ${diff} days`);
  });

  test('an admin rejects; a rejected or cancelled order cannot be confirmed', async () => {
    const o = await order(db, p, 'standard', 'bank_transfer');
    await user(db, admin).query(`select public.admin_reject_payment($1, 'pas reçu')`, [o.id]);
    await denies(user(db, admin).query('select public.admin_confirm_payment($1)', [o.id]), 'P0001');
    const c = await order(db, p, 'standard', 'bank_transfer');
    await user(db, p).query('select public.cancel_payment_order($1)', [c.id]);
    await denies(user(db, admin).query('select public.admin_confirm_payment($1)', [c.id]), 'P0001');
  });

  test('a person cannot confirm, reject, list or touch other people\'s orders', async () => {
    const other = await pro(db);
    const o = await order(db, other, 'standard', 'd17');
    await denies(user(db, other).query('select public.admin_confirm_payment($1)', [o.id]), DENIED);
    await denies(user(db, p).query('select public.admin_reject_payment($1)', [o.id]), DENIED);
    await denies(user(db, p).query('select * from public.admin_list_payment_orders()'), DENIED);
    await denies(user(db, p).query('select public.mark_payment_sent($1)', [o.id]), 'P0002');
    await denies(user(db, p).query('select public.cancel_payment_order($1)', [o.id]), 'P0002');
    assert.equal((await user(db, p).query('select count(*)::int n from public.payment_orders where id = $1', [o.id])).rows[0].n, 0);
  });

  test('no client can write a payment, subscription or setting table directly', async () => {
    await denies(user(db, p).query(`update public.payment_orders set status = 'paid'`), DENIED);
    await denies(user(db, p).query(`insert into public.subscriptions (user_id, plan_code, current_period_end) values ($1, 'plus', now() + interval '1 year')`, [p]), DENIED);
    await denies(user(db, p).query(`update public.subscriptions set current_period_end = now() + interval '10 years'`), DENIED);
    await denies(user(db, p).query('select * from public.payment_settings'), DENIED);
    await denies(user(db, p).query('select * from public.payment_events'), DENIED);
    await denies(anon(db).query('select * from public.payment_orders'), DENIED);
  });

  test('the payer note is limited to 200 characters', async () => {
    const o = await order(db, p, 'standard', 'd17');
    await denies(user(db, p).query('select public.mark_payment_sent($1, $2)', [o.id, 'x'.repeat(201)]), 'P0001');
  });
});

describe('payment instructions', () => {
  let db, p, admin;
  before(async () => {
    db = await newDb();
    p = await pro(db);
    admin = await createUser(db);
    await makeAdmin(db, admin);
  });
  test('empty until an admin sets them, then readable by signed-in users only', async () => {
    let r = (await user(db, p).query('select public.get_payment_instructions() as i')).rows[0].i;
    assert.deepEqual(r, { bank: null, d17: null });
    await user(db, admin).query(`select public.admin_set_payment_setting('bank_rib', '08 006 0123456789012 34')`);
    await user(db, admin).query(`select public.admin_set_payment_setting('bank_holder', 'Khidma SARL')`);
    await user(db, admin).query(`select public.admin_set_payment_setting('d17_number', '20 123 456')`);
    r = (await user(db, p).query('select public.get_payment_instructions() as i')).rows[0].i;
    assert.equal(r.bank.rib, '08006012345678901234');
    assert.equal(r.d17.number, '20123456');
    await denies(anon(db).query('select public.get_payment_instructions()'), DENIED);
  });
  test('settings are validated and admin only', async () => {
    await denies(user(db, admin).query(`select public.admin_set_payment_setting('bank_rib', '123')`), 'P0001');
    await denies(user(db, admin).query(`select public.admin_set_payment_setting('d17_number', '12345678')`), 'P0001');
    await denies(user(db, admin).query(`select public.admin_set_payment_setting('secret', 'x')`), 'P0001');
    await denies(user(db, p).query(`select public.admin_set_payment_setting('bank_holder', 'x')`), DENIED);
  });
});

describe('Flouci callbacks (service role)', () => {
  let db, p, o;
  before(async () => {
    db = await newDb();
    p = await pro(db);
    o = await order(db, p, 'standard', 'flouci');
    await service(db).query('select public.service_attach_provider_ref($1, $2)', [o.id, 'PAY123']);
  });
  const apply = (id, pay, ok, amount) =>
    service(db).query('select public.service_apply_flouci_event($1, $2, $3, $4) as r', [id, pay, ok, amount]);

  test('only the service role may call the callback functions', async () => {
    await denies(user(db, p).query('select public.service_apply_flouci_event($1, $2, true, 20000)', ['e0', 'PAY123']), DENIED);
    await denies(anon(db).query('select public.service_attach_provider_ref($1, $2)', [o.id, 'X']), DENIED);
    await denies(user(db, p).query('select public.service_expire_subscriptions()'), DENIED);
  });

  test('a wrong amount fails the order and never pays', async () => {
    const x = await order(db, p, 'plus', 'flouci');
    await service(db).query('select public.service_attach_provider_ref($1, $2)', [x.id, 'PAYX']);
    assert.equal((await apply('ev-bad', 'PAYX', true, 20000)).rows[0].r, 'amount_mismatch');
    assert.equal((await db.query('select status from public.payment_orders where id = $1', [x.id])).rows[0].status, 'failed');
    assert.equal((await db.query('select public.subscription_is_active($1) as a', [p])).rows[0].a, false);
  });

  test('a successful event pays once; replays and a second event id do nothing more', async () => {
    assert.equal((await apply('ev-1', 'PAY123', true, 20000)).rows[0].r, 'paid');
    const end = (await db.query('select current_period_end from public.subscriptions where user_id = $1', [p])).rows[0].current_period_end;
    assert.equal((await apply('ev-1', 'PAY123', true, 20000)).rows[0].r, 'duplicate');
    assert.equal((await apply('ev-2', 'PAY123', true, 20000)).rows[0].r, 'paid');
    const end2 = (await db.query('select current_period_end from public.subscriptions where user_id = $1', [p])).rows[0].current_period_end;
    assert.equal(String(end), String(end2), 'a paid order is not extended again');
  });

  test('a failed event marks the order failed; unknown payments are ignored', async () => {
    const y = await order(db, p, 'standard', 'flouci');
    await service(db).query('select public.service_attach_provider_ref($1, $2)', [y.id, 'PAYY']);
    assert.equal((await apply('ev-3', 'PAYY', false, 20000)).rows[0].r, 'failed');
    assert.equal((await apply('ev-4', 'NOPE', true, 20000)).rows[0].r, 'unknown_order');
  });

  test('a provider reference cannot be attached twice or reused', async () => {
    await denies(service(db).query('select public.service_attach_provider_ref($1, $2)', [o.id, 'OTHER']), 'P0002');
  });
});

describe('expiry and account deletion', () => {
  test('past periods become past_due, then expired after a week', async () => {
    const db = await newDb();
    const p = await pro(db);
    await db.query(`insert into public.subscriptions (user_id, plan_code, current_period_end) values ($1, 'standard', now() - interval '1 day')`, [p]);
    await service(db).query('select public.service_expire_subscriptions()');
    assert.equal((await db.query('select status from public.subscriptions where user_id = $1', [p])).rows[0].status, 'past_due');
    await db.query(`update public.subscriptions set current_period_end = now() - interval '8 days' where user_id = $1`, [p]);
    await service(db).query('select public.service_expire_subscriptions()');
    assert.equal((await db.query('select status from public.subscriptions where user_id = $1', [p])).rows[0].status, 'expired');
    assert.equal((await db.query('select public.subscription_is_active($1) as a', [p])).rows[0].a, false);
  });
  test('deleting the account removes subscriptions and orders', async () => {
    const db = await newDb();
    const p = await pro(db);
    await order(db, p);
    await user(db, p).query('select public.delete_my_account()');
    assert.equal((await db.query('select count(*)::int n from public.payment_orders')).rows[0].n, 0);
  });
});
