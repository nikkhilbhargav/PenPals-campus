# PenPals Campus — Supabase + Railway

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

## Deploy on Railway

This project runs as a regular Express server, so Railway can run it directly;
no serverless adapter or separate frontend service is needed.

1. Push the project root to a GitHub repository. Confirm `.env` is not included
   (`.gitignore` excludes it). A private repository is fine.
2. In [Railway](https://railway.com/), create a project and choose **Deploy from
   GitHub repo**. Select the repository containing `package.json` at its root.
3. Railway detects Node.js and the `npm start` script. If it asks for commands,
   use **Build:** `npm install` and **Start:** `npm start`.
4. In the service's **Variables** settings, add these for the production
   environment:

   - `NODE_ENV` = `production`
   - `SUPABASE_URL` = your Supabase project URL
   - `SUPABASE_SECRET_KEY` = the new server-only Secret key
   - `SESSION_SECRET` = a separate random value of at least 32 characters

   Leave `SUPABASE_SERVICE_ROLE_KEY` unset when using `SUPABASE_SECRET_KEY`.
   Railway provides `PORT` automatically; do not hard-code a production port.
   Never paste secrets into GitHub or chat. If a key has been exposed, rotate it
   in Supabase and update this variable.
5. In Railway service **Settings**, set the healthcheck path to `/health`, then
   use **Networking → Generate Domain** to create the public URL. Railway waits
   for the app's `/health` endpoint before routing traffic.

For Railway's current Express deployment workflow, see its [Express guide](https://docs.railway.com/guides/express),
[build and start command docs](https://docs.railway.com/builds/build-and-start-commands),
and [healthcheck docs](https://docs.railway.com/deployments/healthchecks).

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
