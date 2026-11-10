# Database schema

Postgres on Supabase. SQL migrations live in `backend/supabase/migrations` (timestamp-ordered) and are the source of truth; this page explains the intent. Security rules: [SECURITY.md](SECURITY.md).

## Implemented (Phase 2.2)
```
auth.users (Supabase)
  └─ profiles 1:1            id, full_name, avatar_url, phone (private), preferred_language,
  │                          is_customer, is_professional, timestamps
  ├─ customer_profiles 1:1   default_governorate_id, default_city_id
  ├─ admin_users 0..1        membership row; no client access
  └─ professional_profiles 0..1
       business_name, primary_category_id, description, years_experience,
       governorate_id / city_id / neighborhood_id, latitude/longitude (rounded),
       contact_phone, availability, is_published,
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

## Planned
| Phase | Tables |
|---|---|
| 4 | `portfolio_images` (+ Storage bucket policies) |
| 5 | `quote_requests`, `quote_offers`, `bookings` with an explicit lifecycle: request -> offer -> accepted -> in_progress -> completed / cancelled / expired; atomic accept RPC (row lock + unique accepted offer); competitors cannot see rival offers |
| 6 | `conversations`, `conversation_participants`, `messages`, `notifications` (+ outbox), `reviews` (one per participant per completed job; aggregates maintained server-side), `professional_verification` (private documents), `reports`, `user_preferences`, `favorites` |
| 3 | geo search: PostGIS (`geography` + GIST) added in its own migration once the Supabase plan is confirmed; until then latitude/longitude columns serve the schema |

Open: PostGIS availability and the Maps provider benchmark (see ARCHITECTURE.md).
