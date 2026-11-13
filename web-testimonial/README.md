# Testimonial page

One static file (`index.html`, no build step). A past client opens the link a
freelancer sent from the app (`<TESTIMONIAL_BASE_URL>/t/<token>`), writes a
testimonial and the page calls the `submit_testimonial` function of the
backend with the public key. No account, no cookies.

## Deploy on Vercel

1. Edit the `CONFIG` block at the top of `index.html`:
   - `SUPABASE_URL`: the project URL (`https://<ref>.supabase.co`).
   - `SUPABASE_PUBLISHABLE_KEY`: the public `sb_publishable_...` key (or the
     legacy `anon` key). Never a secret or service-role key.
2. Create a Vercel project with this folder (`web-testimonial`) as the root
   directory, framework preset "Other", no build command, no output directory.
   `vercel.json` rewrites `/t/*` to `index.html`.
3. If the project is not on `*.supabase.co` (custom domain), add that origin
   to `connect-src` in the CSP `<meta>` of `index.html`.
4. Put the deployed address in the app build:
   `--dart-define=TESTIMONIAL_BASE_URL=https://your-page.vercel.app`
   (optional: when empty, the app cannot create invitation links and says so).
   It must be https, without a trailing path.

The invitation token is 64 hex characters, valid 30 days, usable once.
`https://.../t/<token>` and `https://.../?t=<token>` both work.
