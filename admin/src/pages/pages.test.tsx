import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { ApiError, PAGE_SIZE, type ReportRow, type VerificationRow } from '../lib/api';
import { fakeApi, fakeMedia, renderWith } from '../test-utils';
import { Categories, validateCategory } from './Categories';
import { Professionals, Reviews } from './Lists';
import { Reports } from './Reports';
import { Appeals } from './Appeals';
import { Verification } from './Verification';

const ver = (over: Partial<VerificationRow> = {}): VerificationRow => ({
  id: 'v1', professional_id: 'p1aaaaaaaa', business_name: 'Plomberie Ali', submitted_at: '2026-11-10T10:00:00Z', documents: 2, status: 'pending', ...over,
});
const rep = (over: Partial<ReportRow> = {}): ReportRow => ({
  id: 'r1', target_type: 'professional', target_id: 'p1aaaaaaaa', reason: 'scam', details: 'Demande un acompte', status: 'open',
  created_at: '2026-11-10T10:00:00Z', reports_on_target: 1, message_id: null, subject_id: 'p1aaaaaaaa',
  subject_reporters_30d: 1, flagged: false, subject_is_professional: true, subject_suspended: false, ...over,
});

describe('Verification', () => {
  it('lists pending requests; approving sends the review and reloads', async () => {
    const verifications = vi.fn().mockResolvedValueOnce([ver()]).mockResolvedValue([]);
    const reviewVerification = vi.fn().mockResolvedValue(undefined);
    renderWith(<Verification />, { api: fakeApi({ verifications, reviewVerification }) });
    expect(await screen.findByText('Plomberie Ali')).toBeInTheDocument();
    await userEvent.setup().click(screen.getByRole('button', { name: 'Approve' }));
    await waitFor(() => expect(reviewVerification).toHaveBeenCalledWith('v1', true));
    expect(await screen.findByText('No pending requests.')).toBeInTheDocument();
  });

  it('rejecting needs a reason first', async () => {
    const reviewVerification = vi.fn().mockResolvedValue(undefined);
    renderWith(<Verification />, { api: fakeApi({ verifications: vi.fn().mockResolvedValue([ver()]), reviewVerification }) });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Reject' }));
    const confirm = screen.getByRole('button', { name: 'Confirm: Reject' });
    expect(confirm).toBeDisabled();
    await user.type(screen.getByLabelText('Reason shown to the professional'), 'Photo illisible');
    expect(confirm).toBeEnabled();
    await user.click(confirm);
    await waitFor(() => expect(reviewVerification).toHaveBeenCalledWith('v1', false, 'Photo illisible'));
  });

  it('a decision someone else already made shows a clear message, not a crash', async () => {
    const reviewVerification = vi.fn().mockRejectedValue(new ApiError('invalid_transition'));
    renderWith(<Verification />, { api: fakeApi({ verifications: vi.fn().mockResolvedValue([ver()]), reviewVerification }) });
    await userEvent.setup().click(await screen.findByRole('button', { name: 'Approve' }));
    expect(await screen.findByText('It was already handled by someone else.')).toBeInTheDocument();
  });

  it('documents are fetched only on request and open in a new tab without referrer', async () => {
    const verificationDocuments = vi.fn().mockResolvedValue(['https://signed/1']);
    renderWith(<Verification />, {
      api: fakeApi({ verifications: vi.fn().mockResolvedValue([ver()]) }),
      media: fakeMedia({ verificationDocuments }),
    });
    expect(verificationDocuments).not.toHaveBeenCalled();
    await userEvent.setup().click(await screen.findByRole('button', { name: 'View documents (logged)' }));
    const link = await screen.findByRole('link', { name: /Document 1/ });
    expect(link).toHaveAttribute('href', 'https://signed/1');
    expect(link).toHaveAttribute('rel', 'noreferrer noopener');
    expect(link).toHaveAttribute('target', '_blank');
  });

  it('other statuses show no actions', async () => {
    renderWith(<Verification />, { api: fakeApi({ verifications: vi.fn().mockResolvedValue([ver({ status: 'approved' })]) }) });
    await screen.findByText('Plomberie Ali');
    expect(screen.queryByRole('button', { name: 'Approve' })).toBeNull();
  });

  it('shows an error with retry when loading fails', async () => {
    const verifications = vi.fn().mockRejectedValueOnce(new ApiError('network')).mockResolvedValue([ver()]);
    renderWith(<Verification />, { api: fakeApi({ verifications }) });
    expect(await screen.findByText('No connection. Try again.')).toBeInTheDocument();
    await userEvent.setup().click(screen.getByRole('button', { name: 'Retry' }));
    expect(await screen.findByText('Plomberie Ali')).toBeInTheDocument();
  });

  it('a full page offers Load more and appends the next one at the right offset', async () => {
    const full = Array.from({ length: PAGE_SIZE }, (_, i) => ver({ id: `v${i}`, business_name: `Pro ${i}` }));
    const verifications = vi.fn().mockResolvedValueOnce(full).mockResolvedValueOnce([ver({ id: 'last', business_name: 'The last one' })]);
    renderWith(<Verification />, { api: fakeApi({ verifications }) });
    await screen.findByText('Pro 0');
    await userEvent.setup().click(screen.getByRole('button', { name: 'Load more' }));
    expect(await screen.findByText('The last one')).toBeInTheDocument();
    expect(verifications).toHaveBeenLastCalledWith('pending', PAGE_SIZE);
    expect(screen.queryByRole('button', { name: 'Load more' })).toBeNull();
  });
});

describe('Reports', () => {
  it('a conversation is read only on request (and says it is logged)', async () => {
    const reportContext = vi.fn().mockResolvedValue({ messages: [{ sender_is_customer: true, body: 'Bonjour', image_path: null }, { sender_is_customer: false, body: null, image_path: 'x/a.jpg' }] });
    renderWith(<Reports />, { api: fakeApi({ reports: vi.fn().mockResolvedValue([rep({ target_type: 'conversation' })]), reportContext }) });
    await screen.findByText('conversation p1aaaaaa');
    expect(reportContext).not.toHaveBeenCalled();
    await userEvent.setup().click(screen.getByRole('button', { name: 'Read conversation (logged)' }));
    expect(await screen.findByText('Bonjour')).toBeInTheDocument();
    expect(screen.getByText('[image]')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'View images (logged)' })).toBeInTheDocument();
  });

  it('handling: start review, then action with a note; repeated reports are flagged', async () => {
    const handleReport = vi.fn().mockResolvedValue(undefined);
    renderWith(<Reports />, { api: fakeApi({ reports: vi.fn().mockResolvedValue([rep({ reports_on_target: 3 })]), handleReport }) });
    const user = userEvent.setup();
    expect(await screen.findByText('3')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Start review' }));
    await waitFor(() => expect(handleReport).toHaveBeenCalledWith('r1', 'reviewing', undefined));
    await user.click(screen.getByRole('button', { name: 'Action taken' }));
    await user.type(screen.getByLabelText('What was done (optional)'), 'Suspendu');
    await user.click(screen.getByRole('button', { name: 'Confirm: Action taken' }));
    await waitFor(() => expect(handleReport).toHaveBeenCalledWith('r1', 'actioned', 'Suspendu'));
  });
});

describe('Reports: trust v2', () => {
  it('a flagged person is marked; suspending from the queue needs a reason and passes the report', async () => {
    const suspend = vi.fn().mockResolvedValue(undefined);
    const reports = vi.fn().mockResolvedValue([rep({ flagged: true, subject_reporters_30d: 4 })]);
    renderWith(<Reports />, { api: fakeApi({ reports, suspend }) });
    const user = userEvent.setup();
    expect(await screen.findByText('flagged: 4 reporters')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Suspend 7 days' }));
    expect(screen.getByRole('button', { name: 'Confirm: Suspend 7 days' })).toBeDisabled();
    await user.type(screen.getByLabelText('Reason (shown to the professional)'), 'Paiement hors app');
    await user.click(screen.getByRole('button', { name: 'Confirm: Suspend 7 days' }));
    await waitFor(() => expect(suspend).toHaveBeenCalledWith('p1aaaaaaaa', 7, 'Paiement hors app', 'r1'));
    expect(reports).toHaveBeenCalledTimes(2);
  });

  it('no suspend button for a customer, a testimonial or someone already suspended', async () => {
    const reports = vi.fn().mockResolvedValue([
      rep({ id: 'a', subject_is_professional: false }),
      rep({ id: 'b', target_type: 'testimonial', subject_id: null, subject_is_professional: false }),
      rep({ id: 'c', subject_suspended: true }),
    ]);
    renderWith(<Reports />, { api: fakeApi({ reports }) });
    expect(await screen.findAllByRole('button', { name: 'Dismiss' })).toHaveLength(3);
    expect(screen.queryByRole('button', { name: 'Suspend 7 days' })).toBeNull();
    expect(screen.getByText('suspended')).toBeInTheDocument();
  });

  it('a reported message is pointed out in its conversation', async () => {
    const reportContext = vi.fn().mockResolvedValue({
      reported_message_id: 9,
      messages: [{ id: 8, sender_is_customer: true, body: 'Bonjour' }, { id: 9, sender_is_customer: false, body: 'Payez d avance' }],
    });
    renderWith(<Reports />, { api: fakeApi({ reports: vi.fn().mockResolvedValue([rep({ target_type: 'message', message_id: 9 })]), reportContext }) });
    await screen.findByText('message p1aaaaaa #9');
    await userEvent.setup().click(screen.getByRole('button', { name: 'Read conversation (logged)' }));
    const li = (await screen.findByText('Payez d avance')).closest('li')!;
    expect(within(li).getByText('reported')).toBeInTheDocument();
  });
});

describe('Reports: freelance listings', () => {
  it('a reported listing can be unpublished with a reason, and released from its context', async () => {
    const holdFreelancer = vi.fn().mockResolvedValue(undefined);
    const releaseFreelancer = vi.fn().mockResolvedValue(undefined);
    const reportContext = vi.fn().mockResolvedValue({ display_name: 'Sami', admin_hold_reason: 'Plagiat' });
    const reports = vi.fn().mockResolvedValue([rep({ target_type: 'freelancer', target_id: 'f1aaaaaaaa' })]);
    renderWith(<Reports />, { api: fakeApi({ reports, holdFreelancer, releaseFreelancer, reportContext }) });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Unpublish listing' }));
    await user.type(screen.getByLabelText('Reason (shown to the freelancer)'), 'Plagiat');
    await user.click(screen.getByRole('button', { name: 'Confirm: Unpublish listing' }));
    await waitFor(() => expect(holdFreelancer).toHaveBeenCalledWith('f1aaaaaaaa', 'Plagiat', 'r1'));
    await user.click(screen.getByRole('button', { name: 'Show details' }));
    await user.click(await screen.findByRole('button', { name: 'Release listing' }));
    await waitFor(() => expect(releaseFreelancer).toHaveBeenCalledWith('f1aaaaaaaa'));
  });

  it('other targets have no unpublish button', async () => {
    renderWith(<Reports />, { api: fakeApi({ reports: vi.fn().mockResolvedValue([rep()]) }) });
    await screen.findByRole('button', { name: 'Dismiss' });
    expect(screen.queryByRole('button', { name: 'Unpublish listing' })).toBeNull();
  });
});

describe('Appeals', () => {
  it('lists open appeals; lifting or keeping sends the decision', async () => {
    const appeals = vi.fn().mockResolvedValue([
      { id: 'ap1', professional_id: 'p1', business_name: 'Alpha', message: 'Erreur, je n ai rien demande', status: 'open', created_at: '2026-11-12T10:00:00Z', suspended_until: null, suspension_reason: 'Paiement hors app', decision_note: null },
    ]);
    const decideAppeal = vi.fn().mockResolvedValue(undefined);
    renderWith(<Appeals />, { api: fakeApi({ appeals, decideAppeal }) });
    const user = userEvent.setup();
    expect(await screen.findByText('Erreur, je n ai rien demande')).toBeInTheDocument();
    expect(screen.getByText('until lifted')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Keep suspension' }));
    await user.type(screen.getByLabelText('Why (optional)'), 'Preuves claires');
    await user.click(screen.getByRole('button', { name: 'Confirm: Keep suspension' }));
    await waitFor(() => expect(decideAppeal).toHaveBeenCalledWith('ap1', false, 'Preuves claires'));
    expect(appeals).toHaveBeenCalledWith('open', 0);
  });
});

describe('Professionals and Reviews', () => {
  it('suspending needs a reason; a suspended one offers to lift it', async () => {
    const professionals = vi.fn().mockResolvedValue([
      { user_id: 'p1', business_name: 'Alpha', is_published: true, verification_status: 'unverified', suspended: false, rating_avg: 4.5, review_count: 2, created_at: '2026-11-01T00:00:00Z' },
      { user_id: 'p2', business_name: 'Beta', is_published: false, verification_status: 'verified', suspended: true, rating_avg: 0, review_count: 0, created_at: '2026-11-01T00:00:00Z' },
    ]);
    const setSuspended = vi.fn().mockResolvedValue(undefined);
    renderWith(<Professionals />, { api: fakeApi({ professionals, setSuspended }) });
    const user = userEvent.setup();
    const alpha = (await screen.findByText('Alpha')).closest('tr')!;
    await user.click(within(alpha).getByRole('button', { name: 'Suspend' }));
    expect(screen.getByRole('button', { name: 'Confirm: Suspend' })).toBeDisabled();
    await user.type(screen.getByLabelText('Reason (shown to the professional, kept in the audit log)'), 'Arnaque');
    await user.click(screen.getByRole('button', { name: 'Confirm: Suspend' }));
    await waitFor(() => expect(setSuspended).toHaveBeenCalledWith('p1', true, 'Arnaque'));
    const beta = screen.getByText('Beta').closest('tr')!;
    await user.click(within(beta).getByRole('button', { name: 'Lift suspension' }));
    await waitFor(() => expect(setSuspended).toHaveBeenCalledWith('p2', false));
  });

  it('search and filters reload from the first page', async () => {
    const professionals = vi.fn().mockResolvedValue([]);
    renderWith(<Professionals />, { api: fakeApi({ professionals }) });
    const user = userEvent.setup();
    await screen.findByText('No professionals.');
    await user.type(screen.getByLabelText('Name or id'), '100%');
    await user.click(screen.getByRole('button', { name: 'Search' }));
    await waitFor(() => expect(professionals).toHaveBeenLastCalledWith('100%', 'all', 0));
    await user.click(screen.getByRole('button', { name: 'suspended' }));
    await waitFor(() => expect(professionals).toHaveBeenLastCalledWith('100%', 'suspended', 0));
  });

  it('a hidden review can be published again; a public one needs a reason to hide', async () => {
    const reviews = vi.fn().mockImplementation(async (status: string) =>
      status === 'published'
        ? [{ id: 'rv1', subject_id: 's', about_professional: true, rating: 1, comment: 'Nul', status: 'published', created_at: '2026-11-05T00:00:00Z' }]
        : [{ id: 'rv2', subject_id: 's', about_professional: true, rating: 2, comment: 'Bof', status: 'hidden', created_at: '2026-11-05T00:00:00Z' }]);
    const setReviewStatus = vi.fn().mockResolvedValue(undefined);
    renderWith(<Reviews />, { api: fakeApi({ reviews, setReviewStatus }) });
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Hide' }));
    await user.type(screen.getByLabelText('Reason (kept in the audit log)'), 'Faux avis');
    await user.click(screen.getByRole('button', { name: 'Confirm: Hide' }));
    await waitFor(() => expect(setReviewStatus).toHaveBeenCalledWith('rv1', 'hidden', 'Faux avis'));
    await user.click(screen.getByRole('button', { name: 'hidden' }));
    await user.click(await screen.findByRole('button', { name: 'Publish again' }));
    await waitFor(() => expect(setReviewStatus).toHaveBeenCalledWith('rv2', 'published'));
  });
});

describe('Categories', () => {
  const valid = { id: null, slug: 'jardinage', name_fr: 'Jardinage', name_ar: 'بستنة', name_en: 'Gardening', icon: 'grass', sort_order: 1, active: true };

  it('validateCategory', () => {
    expect(validateCategory(valid)).toBeNull();
    expect(validateCategory({ ...valid, slug: 'Bad Slug' })).toMatch(/Slug/);
    expect(validateCategory({ ...valid, slug: '1abc' })).toMatch(/Slug/);
    expect(validateCategory({ ...valid, name_ar: ' ' })).toMatch(/names/);
    expect(validateCategory({ ...valid, name_en: 'x'.repeat(81) })).toMatch(/names/);
    expect(validateCategory({ ...valid, icon: '' })).toMatch(/Icon/);
  });

  it('saves a valid form once and clears it; an invalid one sends nothing', async () => {
    const upsertCategory = vi.fn().mockResolvedValue(12);
    renderWith(<Categories />, { api: fakeApi({ upsertCategory }) });
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Save category' }));
    expect(upsertCategory).not.toHaveBeenCalled();
    expect(screen.getByRole('alert')).toBeInTheDocument();
    await user.type(screen.getByLabelText('Slug'), 'jardinage');
    await user.type(screen.getByLabelText('Name (French)'), 'Jardinage');
    await user.type(screen.getByLabelText('Name (Arabic)'), 'بستنة');
    await user.type(screen.getByLabelText('Name (English)'), 'Gardening');
    await user.click(screen.getByRole('button', { name: 'Save category' }));
    expect(await screen.findByText('Saved (id 12).')).toBeInTheDocument();
    expect(upsertCategory).toHaveBeenCalledTimes(1);
    expect(upsertCategory.mock.calls[0]![0]).toMatchObject({ id: null, slug: 'jardinage', active: true });
    expect(screen.getByLabelText('Slug')).toHaveValue('');
  });

  it('a refused save shows the failure text', async () => {
    renderWith(<Categories />, { api: fakeApi({ upsertCategory: vi.fn().mockRejectedValue(new ApiError('invalid_input')) }) });
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('Slug'), 'dup');
    await user.type(screen.getByLabelText('Name (French)'), 'a');
    await user.type(screen.getByLabelText('Name (Arabic)'), 'b');
    await user.type(screen.getByLabelText('Name (English)'), 'c');
    await user.click(screen.getByRole('button', { name: 'Save category' }));
    expect(await screen.findByText('That value is not accepted.')).toBeInTheDocument();
  });
});
