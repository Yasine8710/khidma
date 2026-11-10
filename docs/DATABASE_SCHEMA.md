# Database schema

Postgres on Supabase. SQL migrations live in `backend/supabase/migrations` (timestamp-ordered) and are the source of truth; this page explains the intent. Security rules: [SECURITY.md](SECURITY.md).

## Implemented (Phase 2.2)
```
auth.users (Supabase)
  └─ profiles 1:1            id, full_name, avatar_url, phone (private), preferred_language,
  │                          is_customer, is_professional, timestamps
  ├─ customer_profiles 1:1   default_governorate_id, default_city_id
  ├─ admin_users 0..1        membership row; no client access
  ├─ contact_reveals N       rate-limit/audit log of phone reveals; no client access
  ├─ favorites N             saved professionals (user_id, professional_id), private, max 200
  └─ professional_profiles 0..1
       business_name, primary_category_id, description, years_experience,
       governorate_id / city_id / neighborhood_id, latitude/longitude (rounded to ~1.1 km),
       contact_phone (not selectable; revealed by RPC), availability, is_published,
       verification_status, verified_at, rating_avg, review_count
       ├─ professional_services  (professional_id, category_id)   N:M
       └─ service_areas          (professional_id, governorate_id, city_id?)

governorates (24, ISO 3166-2:TN) ─< cities ─< neighborhoods
service_categories (12 seeded, 3 languages, admin-managed)
```

Design notes:
- **Capability flags, not a role column.** A person can be a customer and a professional.
- **Geography integrity.** Composite foreign keys keep a city inside its governorate and a neighborhood inside its city.
- **Names in three languages** (`name_fr/ar/en`) on reference data; the app picks by locale.
- **Constraints do real work:** phone format (`+216` + 8 digits, first digit 2-5, 7 or 9), value limits, "no half-empty public profile", "verified implies a verification time".
- **Indexes:** foreign keys, a partial index for published profiles by governorate/category, and a unique index for service areas.
- `updated_at` is maintained by a trigger.

## Marketplace search (Phase 3.1)
`public.search_professionals(...)` is the only way the app lists professionals. One function filters, matches text, measures distance and sorts, so there is one tested definition instead of one per client.
- **Visibility:** `SECURITY INVOKER`, so Row Level Security and column grants apply; also explicitly `is_published`, so an owner never sees their own draft in public results. Returns only public columns (never `contact_phone`).
- **Text** (query capped at 100 characters, whitespace collapsed): matched field by field (never across two fields) against name, description, profession (3 languages + slug) and governorate / city / neighborhood names (3 languages), accent- and Arabic-variant-insensitive via `search_normalize` (French accents; alef forms, alef maqsura, taa marbuta, Persian ya/kaf, hamza on waw/ya; diacritics and tatweel dropped). The Dart mirror is tested on the same vector file.
- **Filters** (AND): category (primary or secondary service), governorate, city, minimum rating, available only, radius. Place semantics: a city request is met by being based in the city, serving it, or serving its whole governorate (a service area with no city); a governorate request by being based there or serving it; a city given with a governorate must belong to it, otherwise nothing matches.
- **Sorts:** `rating` (default), `reviews`, `nearest` (unknown positions last). Ties break on id. `recent` was removed: profile edits are not an activity signal (they can be repeated to climb the list); it returns when a real signal exists (Phase 5 responses).
- **Paging:** limit clamped to 1-50, offset capped at 5000. Offset paging can show a gap or duplicate if profiles change between requests; switch to cursor paging if that matters.
- **Distance** is computed from the already-rounded coordinates (~1.1 km), so it reveals nothing finer than the stored location.
- **Performance (not done):** the text match normalizes per row and cannot use an index. Fine for hundreds of professionals; before thousands, add a generated normalized search column with a trigram index and benchmark on realistic data.
- Not yet filterable: price range (no price field yet; Phase 4 adds a starting-price field).

## Planned
| Phase | Tables |
|---|---|
| 4 | `portfolio_images` (+ Storage bucket policies) |
| 5 | `quote_requests`, `quote_offers`, `bookings` with an explicit lifecycle: request -> offer -> accepted -> in_progress -> completed / cancelled / expired; atomic accept RPC (row lock + unique accepted offer); competitors cannot see rival offers |
| 6 | `conversations`, `conversation_participants`, `messages`, `notifications` (+ outbox), `reviews` (one per participant per completed job; aggregates maintained server-side), `professional_verification` (private documents), `reports`, `user_preferences`, `favorites` |
| 3 | geo search: PostGIS (`geography` + GIST) added in its own migration once the Supabase plan is confirmed; until then latitude/longitude columns serve the schema |

Open: PostGIS availability and the Maps provider benchmark (see ARCHITECTURE.md).
