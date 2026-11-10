# Architecture (v1, after Codex review 2026-11-10)

## Client
Flutter (iOS first), feature-first clean architecture under `app/lib/`:
```
core/        theme, design tokens, l10n, router, errors, utils
shared/      reusable widgets
features/<f>/{presentation,application,domain,data}
infrastructure/  supabase client, fcm, storage, maps
```
- State: Riverpod (code-gen optional, decide after review). Navigation: GoRouter with auth/role redirects.
- Domain has no Flutter/Supabase imports. Data maps DTOs to entities. Repositories are interfaces in domain.
- L10n: ARB files fr (default), ar (RTL), en; `Directionality` driven by locale; logical `EdgeInsetsDirectional`.
- Offline: cached reads (categories, geo data, favorites) via a small local store; writes need network.

## Backend (Supabase)
Postgres + RLS on all user-data tables, SQL migrations in `backend/supabase/migrations`. Business-critical writes (offer accept, review eligibility, verification) via SECURITY DEFINER RPC or Edge Functions, never client-trusted. Roles: `customer`, `professional`, `admin`; role set server-side only, never from client metadata. Private storage buckets for verification docs; public bucket for portfolio only. Geo search via PostGIS (`geography` + GIST index).

## Admin
Separate web app in `admin/`, admin-role-gated by RLS and server checks.

## Decisions after Codex review (see AI_COLLABORATION.md)
- Riverpod: manual providers with `Notifier`/`AsyncNotifier`; no codegen until Freezed/json_serializable is justified.
- Layers: keep domain isolated; add repository interfaces only where they enforce a real boundary (avoid pass-through boilerplate).
- Roles: capability flags, not one exclusive role; a user may be customer and professional. `admin` set server-side only; role/verification columns not owner-updatable; never authorize from `user_metadata`.
- Job lifecycle (request -> offer -> accepted -> in_progress -> completed | cancelled | expired) as an explicit state machine in SQL with an atomic accept RPC (row lock + unique accepted-offer constraint). Specified in DATABASE_SCHEMA.md before Phase 5.
- Permission matrix (actor x operation x resource) is a Phase 2 deliverable, with RLS isolation tests.
- Privacy: public profile split from phone/exact address/verification records; competitor offers invisible; accepted terms frozen.
- Notifications: transactional outbox, dedup keys, retry; chat/offers survive missed pushes.
- Search: PostGIS + Arabic/French normalization and category aliases.
- Maps: Google Maps provisionally; benchmark on 50-100 Tunisian addresses before Phase 3; manual pin fallback.
- iOS: GitHub macOS CI only; physical-iPhone/signing/APNs validation is an open blocker needing a Mac (see AI_COLLABORATION.md).

## Open questions
Riverpod codegen vs manual; PostGIS availability on chosen Supabase plan; Maps provider (Google vs Mapbox); iOS CI on GitHub macOS runners.
