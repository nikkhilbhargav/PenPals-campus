# PenPals Campus — Supabase + Vercel

PenPals Campus keeps its current student-facing interface and nickname/password
sign-in. Express serves the site and API from one Node.js service. Supabase
provides Postgres and private Storage; the browser never connects to Supabase
directly.

## Supabase setup

1. Create a project at [Supabase](https://supabase.com/dashboard) and wait for
   its database to finish provisioning.
2. In **SQL Editor**, run [`supabase/schema.sql`](supabase/schema.sql). This
   creates the app tables, indexes, database-backed rate limits, and deny-all
   RLS policies for direct browser access.
3. In **Storage**, create these two buckets as private:

   | Bucket | Maximum size | Allowed content |
   | --- | ---: | --- |
   | `item-images` | 1.5 MB | JPEG, PNG, WebP |
   | `study-materials` | 4 MB | PDF, DOC, DOCX, JPEG, PNG, WebP |

   The Storage RLS policy is included at the bottom of `supabase/schema.sql`.
   [`supabase/config.toml`](supabase/config.toml) records local Supabase CLI
   bucket settings; for a hosted project, create buckets through the Dashboard.
4. In **Project Settings → API Keys**, get the project URL and create a
   server-side Secret key. Do not put that key in browser files or source
   control. A secret key bypasses RLS, so the backend checks ownership for each
   protected operation. See [Supabase API key guidance](https://supabase.com/docs/guides/getting-started/api-keys).

## Run locally

Requires Node.js 20+ and the Supabase schema and buckets above.

```powershell
npm install
Copy-Item .env.example .env
notepad .env
npm start
```

Set `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, and a separate random
`SESSION_SECRET` of at least 32 characters in `.env`. Keep this file private.
Open the local address printed by `npm start` (usually
`http://127.0.0.1:4173`). Press **Ctrl+C** in PowerShell to stop the server.

The first registration creates an account; no sample users or old JSON data are
included. Passwords use scrypt hashing. Sessions use random opaque tokens,
stored as keyed hashes and sent in HttpOnly/SameSite cookies.

## Deploy on Vercel

Vercel detects the Express application in `server.js` and runs it as a Function.
Files in `public/` are served as static assets. No separate frontend service or
serverless adapter is needed.

1. Push the project root to GitHub. Confirm `.env` is not committed; `.gitignore`
   excludes it.
2. At [Vercel](https://vercel.com/), choose **Add New → Project**, import the
   repository, and leave the Root Directory at the folder containing
   `package.json`.
3. Vercel detects Express automatically. Leave the build command and output
   directory at their defaults; no custom build command is required.
4. In **Project Settings → Environment Variables**, add these to **Production**
   (and Preview too if you want preview deployments to connect to Supabase):

   - `NODE_ENV` = `production`
   - `SUPABASE_URL` = your Supabase project URL
   - `SUPABASE_SECRET_KEY` = the new server-only Secret key
   - `SESSION_SECRET` = a separate random value of at least 32 characters

   Leave `SUPABASE_SERVICE_ROLE_KEY` unset when using `SUPABASE_SECRET_KEY`.
   Do not set `PORT`; Vercel manages the function runtime. Never commit or paste
   secrets into GitHub or chat. Rotate any key that has been exposed.
5. Select **Deploy**. After it succeeds, open the generated Vercel URL and test
   sign-up, sign-in, listing operations, and file downloads.

### Vercel limits and plan

Vercel Functions limit request and response bodies to 4.5 MB. This app accepts
study uploads up to 4 MB, so keep files below that application limit to leave
room for multipart request overhead. The Hobby plan is limited to personal,
non-commercial use; check Vercel's current [plan terms](https://vercel.com/pricing)
for your intended public campus use. If your use is commercial or institutionally
operated, choose a plan that permits it.

## Security and behavior

- API writes require an authenticated session and same-origin `Origin` header.
- Only listing owners can edit/delete their listings; request actions are scoped
  to the requester or listing owner and checked against allowed transitions.
- Only a study-material uploader can delete it. Private downloads require login.
- Upload content signatures, MIME types, file sizes, and allowed formats are
  checked. Server-generated filenames and storage paths are used.
- RLS denies direct browser access. The backend uses a server-only Supabase key
  and performs authorization because that key bypasses RLS.
- Rate limits are stored atomically in Supabase Postgres; client IPs are
  HMAC-hashed for the rate-limit key.
- Public profiles expose only nickname, branch, year, and semester. The app
  does not collect email, phone, or home address.

## Checks

Run `npm run check` for JavaScript syntax checks. End-to-end authentication,
uploads, ownership, Storage access, and RLS tests require a configured Supabase
project and live deployment environment.
