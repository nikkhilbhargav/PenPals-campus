# PenPals Campus — Supabase + Netlify

The existing UI is served as static files from `public/`. Its existing Express
API runs locally with Node or as one Netlify Function. The backend keeps the
nickname/password experience and session cookies, and uses Supabase Postgres
and private Storage buckets. The browser never connects to Supabase directly.

## 1. Create a Supabase project

Create a project at [Supabase](https://supabase.com/dashboard). Wait for the
database to finish provisioning.

## 2. Create the database tables and RLS policies

Open **SQL Editor** in the Supabase Dashboard, paste `supabase/schema.sql`, and
run it once. This creates users, sessions, items, requests, study materials,
notifications, and the database-backed rate-limit table/function.

The custom nickname session is separate from Supabase Auth. The SQL therefore
revokes table access from the browser roles `anon` and `authenticated` and
adds restrictive deny policies. Only the backend's secret/service-role key can
reach these tables; the API checks the session and row ownership before every
operation. Supabase secret/service-role keys bypass RLS, so never place one in
`public/` or any frontend build variable. See [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security)
and [API key guidance](https://supabase.com/docs/guides/getting-started/api-keys).

## 3. Create private Storage buckets

In **Storage → New bucket**, create both buckets as **Private**:

| Bucket | Maximum size | Allowed MIME types |
| --- | ---: | --- |
| `item-images` | 1.5 MB | `image/jpeg`, `image/png`, `image/webp` |
| `study-materials` | 4 MB | PDF, DOC, DOCX, JPEG, PNG, WebP |

Apply the Storage RLS policy at the bottom of `supabase/schema.sql`. It denies
direct browser-role operations on these buckets. The server uses its
server-only key and authorizes all downloads and deletions itself. Item images
are served through the API for available/requested listings; study files
require a signed-in campus account. Supabase explains the private bucket model
in its [Storage access-control guide](https://supabase.com/docs/guides/storage/security/access-control).

`supabase/config.toml` records the same private bucket limits for a local
Supabase CLI environment. For a hosted project, create the buckets in the
Dashboard as above; the schema SQL intentionally does not edit Supabase's
managed `storage` schema.

## 4. Copy project credentials

In **Project Settings → API Keys**, copy the Project URL and keys. Set:

- `SUPABASE_URL`: Project URL.
- `SUPABASE_ANON_KEY`: publishable/anon key. The app does not send it to the
  browser; it is kept in the environment for standard project configuration.
- `SUPABASE_SECRET_KEY`: recommended current server-side Secret key. The app
  also accepts the legacy `SUPABASE_SERVICE_ROLE_KEY` variable.
- `SESSION_SECRET`: at least 32 random characters.

Never commit `.env` or expose `SUPABASE_SECRET_KEY` / `SUPABASE_SERVICE_ROLE_KEY`.
Supabase recommends server-only secret keys; these bypass RLS by design.

## 5. Run locally

Requires Node.js 20+ and a configured Supabase project with the SQL and buckets
above applied. From this folder:

```powershell
npm install
Copy-Item .env.example .env
notepad .env
npm start
```

Fill the Supabase values and a private `SESSION_SECRET` in `.env`, save it, and
open the local URL shown by the server in your terminal. The first registration creates a new account;
there are no seeded accounts or old JSON data. Passwords are stored as scrypt
hashes, sessions are random opaque tokens stored as keyed hashes, and the
HttpOnly/SameSite cookie expires after seven days.

For local Netlify Functions and rewrite behavior, install the Netlify CLI and
run `netlify dev` from this folder after setting the same environment values.

## 6. Deploy to Netlify

Push this folder's contents to the root of a Git repository. In Netlify choose
**Add new project → Import from Git** and connect the repository. Netlify reads
`netlify.toml`: publish directory `public`, functions directory
`netlify/functions`, build command `npm install --omit=dev`, Node 22, and the
`/api/*` rewrite to the Express Function.

In the Netlify site's environment-variable settings, add `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, `SUPABASE_SECRET_KEY` (or `SUPABASE_SERVICE_ROLE_KEY`), and
`SESSION_SECRET`. Scope the secret key to Functions/runtime only when the UI
offers a scope choice. Redeploy after adding variables. **Do not put secrets in
`netlify.toml`**; that file is committed. Netlify's official [Express guide](https://docs.netlify.com/build/frameworks/framework-setup-guides/express/)
documents the function rewrite pattern used here.

Uploads stay within Netlify's buffered function request limit: item photos are
limited to 1.5 MB and study files to 4 MB. Netlify documents a 6 MB buffered
payload ceiling and about 4.5 MB for binary request data after Base64 overhead
([function limits](https://docs.netlify.com/build/functions/configuration/)).

## Security notes

- API writes require an authenticated session and same-origin `Origin` header.
- Item edits/deletes require item ownership. Request transitions check the
  requester or item owner and valid status transitions. Material delete checks
  uploader ownership.
- File signatures and declared MIME types are checked; names and storage paths
  are generated by the server. Arbitrary executable formats are rejected.
- RLS is a deny-all browser boundary for this custom-session architecture;
  backend authorization remains mandatory because the secret key bypasses RLS.
- Rate limits are stored atomically in Supabase Postgres so they still apply
  across stateless Netlify Function instances. Client IPs are HMAC-hashed.
- Public profiles contain only the campus nickname, branch, and year. The app
  does not collect email, phone, or home address.

## Checks and deployment status

Run `npm run check` for JavaScript syntax checks. End-to-end signup, uploads,
authorization attacks, Storage access, and RLS checks require a configured
Supabase project and Netlify environment variables; no credentials or project
were available in this workspace, so those live checks have not been run.
No site has been deployed or made publicly accessible.
