import test, { describe, before } from 'node:test';
import assert from 'node:assert/strict';
import { newDb, createUser, makeAdmin, anon, user, denies, DENIED } from './harness.mjs';

const tagged = (promise, tag) =>
  assert.rejects(promise, (e) => e.code === 'P0001' && e.message === tag, `expected ${tag}`);

async function pro(db) {
  const id = await createUser(db);
  await user(db, id).query('select public.become_professional()');
  await user(db, id).query(`update public.professional_profiles set business_name = 'Pro ' || left($1::text, 4) where user_id = $1`, [id]);
  return id;
}
const sub = (db, who, plan, status, endSql) =>
  db.query(`insert into public.subscriptions (user_id, plan_code, status, current_period_end) values ($1, $2, $3, ${endSql})`, [who, plan, status]);
const audits = async (db, action, who) =>
  (await db.query('select count(*)::int as n from public.admin_audit_log where action = $1 and target_id = $2', [action, who])).rows[0].n;
const admin_ = (db, a, sql, ...args) => user(db, a).query(sql, args).then((r) => r.rows);

describe('admin billing', () => {
  let db, admin, pStd, pPlus, pLate, pGone, pNone;
  before(async () => {
    db = await newDb();
    admin = await createUser(db);
    await makeAdmin(db, admin);
    [pStd, pPlus, pLate, pGone, pNone] = [await pro(db), await pro(db), await pro(db), await pro(db), await pro(db)];
    await sub(db, pStd, 'standard', 'active', "now() + interval '10 days'");
    await sub(db, pPlus, 'plus', 'active', "now() + interval '20 days'");
    await sub(db, pLate, 'standard', 'active', "now() - interval '1 day'");
    await sub(db, pGone, 'plus', 'expired', "now() - interval '30 days'");
    const o = (await user(db, pNone).query('select * from public.create_payment_order($1, $2)', ['standard', 'd17'])).rows[0];
    await user(db, pNone).query('select public.mark_payment_sent($1)', [o.id]);
    await db.query(`update public.payment_orders set created_at = now() - interval '3 days' where id = $1`, [o.id]);
  });

  test('every billing function refuses non-admins and visitors', async () => {
    const calls = [
      ['select public.admin_billing_summary()', []],
      ['select * from public.admin_list_subscriptions()', []],
      ['select public.admin_billing_detail($1)', [pStd]],
      ['select public.admin_extend_subscription($1, 7, $2)', [pStd, 'x']],
      ['select public.admin_set_subscription_status($1, $2, $3)', [pStd, 'cancelled', 'x']],
    ];
    for (const [sql, args] of calls) {
      await denies(user(db, pStd).query(sql, args), DENIED);
      await denies(anon(db).query(sql, args), DENIED);
    }
  });

  test('summary: MRR counts running subscriptions only; a lapsed period is past_due', async () => {
    const s = (await admin_(db, admin, 'select public.admin_billing_summary() as s'))[0].s;
    assert.equal(Number(s.mrr_millimes), 20000 + 30000);
    assert.equal(Number(s.active), 2);
    assert.equal(Number(s.past_due), 1);
    assert.equal(Number(s.expired), 1);
    assert.equal(Number(s.orders_waiting), 1);
    assert.equal(Number(s.orders_waiting_48h), 1);
  });

  test('list filters by status, with plan amount and business name', async () => {
    const all = await admin_(db, admin, 'select * from public.admin_list_subscriptions()');
    assert.equal(all.length, 4);
    const late = await admin_(db, admin, `select * from public.admin_list_subscriptions('past_due')`);
    assert.deepEqual(late.map((r) => r.user_id), [pLate]);
    assert.equal(late[0].amount_millimes, 20000);
    assert.ok(late[0].business_name.startsWith('Pro '));
    await tagged(user(db, admin).query(`select * from public.admin_list_subscriptions('nope')`), 'invalid_input');
  });

  test('detail: subscription and payment history of one merchant', async () => {
    const d = (await admin_(db, admin, 'select public.admin_billing_detail($1) as d', pNone))[0].d;
    assert.equal(d.subscription, null);
    assert.equal(d.orders.length, 1);
    assert.equal(d.orders[0].status, 'awaiting_confirmation');
    await assert.rejects(user(db, admin).query('select public.admin_billing_detail($1)', [admin]), (e) => e.code === 'P0002');
  });

  test('extend grace: adds days from now for a lapsed one, reactivates it, needs a reason, audited', async () => {
    await tagged(user(db, admin).query('select public.admin_extend_subscription($1, 7, $2)', [pLate, ' ']), 'invalid_input');
    await tagged(user(db, admin).query('select public.admin_extend_subscription($1, 61, $2)', [pLate, 'trop']), 'invalid_input');
    const end = new Date((await admin_(db, admin, 'select public.admin_extend_subscription($1, 7, $2) as e', pLate, 'Panne D17'))[0].e);
    const days = (end - Date.now()) / 86400e3;
    assert.ok(days > 6.9 && days < 7.1, `${days}`);
    assert.equal((await db.query('select status from public.subscriptions where user_id = $1', [pLate])).rows[0].status, 'active');
    assert.equal(await audits(db, 'subscription_extended', pLate), 1);
  });

  test('comp a month: stacks on a running period; starts one when there is none', async () => {
    const before = (await db.query('select current_period_end as e from public.subscriptions where user_id = $1', [pStd])).rows[0].e;
    const after = new Date((await admin_(db, admin, 'select public.admin_extend_subscription($1, 30, $2) as e', pStd, 'Geste commercial'))[0].e);
    assert.equal(Math.round((after - before) / 86400e3), 30);
    await admin_(db, admin, 'select public.admin_extend_subscription($1, 30, $2) as e', pNone, 'Premier mois offert');
    const s = (await db.query('select plan_code, status from public.subscriptions where user_id = $1', [pNone])).rows[0];
    assert.deepEqual(s, { plan_code: 'standard', status: 'active' });
  });

  test('suspend and reactivate: reason required, audited; nothing to reactivate after the period', async () => {
    await admin_(db, admin, 'select public.admin_set_subscription_status($1, $2, $3)', pPlus, 'cancelled', 'Chargeback');
    assert.equal((await db.query('select status from public.subscriptions where user_id = $1', [pPlus])).rows[0].status, 'cancelled');
    await admin_(db, admin, 'select public.admin_set_subscription_status($1, $2, $3)', pPlus, 'active', 'Resolu');
    assert.equal(await audits(db, 'subscription_suspended', pPlus), 1);
    assert.equal(await audits(db, 'subscription_reactivated', pPlus), 1);
    await tagged(user(db, admin).query('select public.admin_set_subscription_status($1, $2, $3)', [pGone, 'active', 'x']), 'invalid_transition');
    await tagged(user(db, admin).query('select public.admin_set_subscription_status($1, $2, $3)', [pPlus, 'expired', 'x']), 'invalid_input');
  });
});
