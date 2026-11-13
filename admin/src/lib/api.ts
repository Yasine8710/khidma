/** Typed access to the database functions behind the dashboard. Everything is
 * a call to an `admin_*` function: the dashboard has no table access, and the
 * server checks the caller is an admin on every call. */

export type RpcResult = { data: unknown; error: { message: string; code?: string } | null };
export type Rpc = (fn: string, args?: Record<string, unknown>) => Promise<RpcResult>;

export type ApiFailure =
  | 'forbidden'
  | 'not_signed_in'
  | 'invalid_input'
  | 'not_found'
  | 'invalid_transition'
  | 'network'
  | 'unknown';

export class ApiError extends Error {
  constructor(readonly failure: ApiFailure) {
    super(failure);
  }
}

/** Database errors become categories; no database text is ever displayed. */
export function mapError(e: { message: string; code?: string } | null | undefined): ApiError {
  if (!e) return new ApiError('unknown');
  switch (e.code) {
    case '42501':
      return new ApiError('forbidden');
    case 'PGRST301':
    case 'PGRST302':
    case '28000':
      return new ApiError('not_signed_in');
    case 'P0002':
      return new ApiError('not_found');
    case 'P0001':
      if (e.message.includes('invalid_transition')) return new ApiError('invalid_transition');
      if (e.message.includes('invalid_input')) return new ApiError('invalid_input');
      return new ApiError('unknown');
    case '23514':
    case '22023':
      return new ApiError('invalid_input');
  }
  if (/fetch|network|failed to/i.test(e.message)) return new ApiError('network');
  return new ApiError('unknown');
}

export const failureText: Record<ApiFailure, string> = {
  forbidden: 'You are not allowed to do this.',
  not_signed_in: 'Your session expired. Sign in again.',
  invalid_input: 'That value is not accepted.',
  not_found: 'It no longer exists.',
  invalid_transition: 'It was already handled by someone else.',
  network: 'No connection. Try again.',
  unknown: 'Something went wrong. Try again.',
};

export const errorMessage = (e: unknown): string =>
  failureText[e instanceof ApiError ? e.failure : 'unknown'];

// ---- row types (what the functions return) --------------------------------

export type Overview = {
  users: number;
  customers: number;
  professionals: number;
  published: number;
  verified: number;
  suspended: number;
  pending_verifications: number;
  open_reports: number;
  open_requests: number;
  bookings: Record<string, number>;
  reviews: number;
  hidden_reviews: number;
  cleanup_queue: number;
};
export type DayStat = { day: string; signups: number; requests: number; completed_jobs: number };
export type UserRow = {
  id: string;
  full_name: string | null;
  is_customer: boolean;
  is_professional: boolean;
  is_admin: boolean;
  created_at: string;
};
export type ProfessionalRow = {
  user_id: string;
  business_name: string | null;
  is_published: boolean;
  verification_status: string;
  suspended: boolean;
  rating_avg: number;
  review_count: number;
  created_at: string;
};
export type RequestRow = {
  id: string;
  title: string;
  status: string;
  category_id: number;
  governorate_id: number;
  offers: number;
  created_at: string;
};
export type ReviewRow = {
  id: string;
  subject_id: string;
  about_professional: boolean;
  rating: number;
  comment: string | null;
  status: string;
  created_at: string;
};
export type VerificationRow = {
  id: string;
  professional_id: string;
  business_name: string | null;
  submitted_at: string;
  documents: number;
  status: string;
};
export type ReportRow = {
  id: string;
  target_type: 'professional' | 'review' | 'conversation' | 'freelancer' | 'testimonial' | 'offer' | 'message';
  target_id: string;
  message_id: number | null;
  /** Who the report is about (null when unknown). */
  subject_id: string | null;
  reason: string;
  details: string | null;
  status: string;
  created_at: string;
  reports_on_target: number;
  /** Different people who reported the same subject in the last 30 days. */
  subject_reporters_30d: number;
  /** 3+ different reporters in 30 days: review first (never an automatic ban). */
  flagged: boolean;
  subject_is_professional: boolean;
  subject_suspended: boolean;
};
export type AppealRow = {
  id: string;
  professional_id: string;
  business_name: string | null;
  message: string;
  status: string;
  created_at: string;
  suspended_until: string | null;
  suspension_reason: string | null;
  decision_note: string | null;
};
export type PaymentOrderRow = {
  id: string;
  reference: string;
  method: string;
  status: string;
  plan_code: string;
  amount_millimes: number;
  payer_note: string | null;
  business_name: string | null;
  full_name: string | null;
  created_at: string;
};
export type PaymentSettingKey = 'bank_name' | 'bank_holder' | 'bank_rib' | 'd17_number' | 'd17_holder';

/** 20000 millimes -> "20 TND", 25500 -> "25.5 TND". */
export const formatTnd = (millimes: number): string => `${Number((millimes / 1000).toFixed(3))} TND`;

export type AuditRow = {
  id: number;
  admin_id: string;
  action: string;
  target_type: string;
  target_id: string;
  detail: string | null;
  created_at: string;
};
export type CategoryInput = {
  id: number | null;
  slug: string;
  name_fr: string;
  name_ar: string;
  name_en: string;
  icon: string;
  sort_order: number;
  active: boolean;
};

export const PAGE_SIZE = 25;

export function createApi(rpc: Rpc) {
  const call = async <T>(fn: string, args?: Record<string, unknown>): Promise<T> => {
    let r: RpcResult;
    try {
      r = await rpc(fn, args);
    } catch {
      throw new ApiError('network');
    }
    if (r.error) throw mapError(r.error);
    return r.data as T;
  };
  const page = (offset: number) => ({ p_limit: PAGE_SIZE, p_offset: offset });

  return {
    isAdmin: () => call<boolean>('is_admin'),
    overview: () => call<Overview>('admin_overview'),
    stats: (days = 30) => call<DayStat[]>('admin_stats_daily', { p_days: days }),
    users: (query: string, offset: number) =>
      call<UserRow[]>('admin_list_users', { p_query: query || null, ...page(offset) }),
    professionals: (query: string, filter: string, offset: number) =>
      call<ProfessionalRow[]>('admin_list_professionals', { p_query: query || null, p_filter: filter, ...page(offset) }),
    requests: (status: string, offset: number) =>
      call<RequestRow[]>('admin_list_requests', { p_status: status || null, ...page(offset) }),
    reviews: (status: string, offset: number) =>
      call<ReviewRow[]>('admin_list_reviews', { p_status: status, ...page(offset) }),
    verifications: (status: string, offset: number) =>
      call<VerificationRow[]>('admin_list_verifications', { p_status: status, ...page(offset) }),
    reports: (status: string, offset: number) =>
      call<ReportRow[]>('admin_list_reports', { p_status: status, ...page(offset) }),
    reportContext: (id: string) => call<Record<string, unknown>>('admin_report_context', { p_report: id }),
    appeals: (status: string, offset: number) =>
      call<AppealRow[]>('admin_list_appeals', { p_status: status, ...page(offset) }),
    paymentOrders: (status: string, offset: number) =>
      call<PaymentOrderRow[]>('admin_list_payment_orders', { p_status: status, ...page(offset) }),
    audit: (offset: number) => call<AuditRow[]>('admin_audit_log_page', page(offset)),

    confirmPayment: (id: string) => call<void>('admin_confirm_payment', { p_order: id }),
    rejectPayment: (id: string, note?: string) =>
      call<void>('admin_reject_payment', { p_order: id, p_note: note?.trim() || null }),
    setPaymentSetting: (key: PaymentSettingKey, value: string) =>
      call<void>('admin_set_payment_setting', { p_key: key, p_value: value.trim() }),

    reviewVerification: (id: string, approve: boolean, reason?: string) =>
      call<void>('admin_review_verification', { p_request: id, p_approve: approve, p_reason: reason?.trim() || null }),
    handleReport: (id: string, status: 'reviewing' | 'actioned' | 'dismissed', note?: string) =>
      call<void>('admin_handle_report', { p_report: id, p_status: status, p_note: note?.trim() || null }),
    setSuspended: (user: string, suspended: boolean, reason?: string) =>
      call<void>('admin_set_suspended', { p_user: user, p_suspended: suspended, p_reason: reason?.trim() || null }),
    /** Suspends for [days] (null = until lifted); from a report, closes every open report on the person. */
    suspend: (user: string, days: number | null, reason: string, report?: string) =>
      call<void>('admin_suspend', { p_user: user, p_days: days, p_reason: reason.trim(), p_report: report ?? null }),
    decideAppeal: (id: string, lift: boolean, note?: string) =>
      call<void>('admin_decide_appeal', { p_appeal: id, p_lift: lift, p_note: note?.trim() || null }),
    revokeVerification: (user: string, reason: string) =>
      call<void>('admin_revoke_verification', { p_user: user, p_reason: reason.trim() }),
    setReviewStatus: (id: string, status: 'published' | 'hidden', note?: string) =>
      call<void>('admin_set_review_status', { p_review: id, p_status: status, p_note: note?.trim() || null }),
    upsertCategory: (c: CategoryInput) =>
      call<number>('admin_upsert_category', {
        p_id: c.id,
        p_slug: c.slug.trim(),
        p_name_fr: c.name_fr,
        p_name_ar: c.name_ar,
        p_name_en: c.name_en,
        p_icon: c.icon.trim(),
        p_sort_order: c.sort_order,
        p_active: c.active,
      }),
  };
}

export type Api = ReturnType<typeof createApi>;

/** Short-lived links for identity documents or chat images. They come from a
 * server-side signer that first calls the audited database function. */
export type Media = {
  verificationDocuments: (requestId: string) => Promise<string[]>;
  chatImages: (reportId: string) => Promise<string[]>;
};

export type MediaFetch = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{
  ok: boolean;
  json: () => Promise<unknown>;
}>;

export function createMedia(baseUrl: string, token: () => Promise<string | null>, fetcher: MediaFetch): Media {
  const call = async (body: Record<string, string>): Promise<string[]> => {
    const t = await token();
    if (!t) throw new ApiError('not_signed_in');
    let res;
    try {
      res = await fetcher(`${baseUrl}/functions/v1/admin-media`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${t}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    } catch {
      throw new ApiError('network');
    }
    if (!res.ok) throw new ApiError('unknown');
    const data = (await res.json()) as { urls?: unknown };
    if (!Array.isArray(data.urls) || !data.urls.every((u) => typeof u === 'string')) throw new ApiError('unknown');
    return data.urls as string[];
  };
  return {
    verificationDocuments: (requestId) => call({ kind: 'verification', id: requestId }),
    chatImages: (reportId) => call({ kind: 'chat', id: reportId }),
  };
}
