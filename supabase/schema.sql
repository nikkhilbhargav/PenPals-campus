-- PenPals Campus schema for the custom nickname/password session backend.
-- Apply once in Supabase Dashboard > SQL Editor.
-- Browser and Supabase Auth roles get no table/storage access. The private
-- backend uses a Supabase secret/service-role key and performs row checks.

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  nickname text not null,
  nickname_key text not null unique,
  password_hash text not null,
  branch text not null,
  year text not null,
  semester text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.sessions (
  token_hash text primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index if not exists sessions_expiry_idx on public.sessions(expires_at);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  item_name text not null check (char_length(item_name) between 2 and 80),
  category text not null check (category in ('Blue Pen','Black Pen','Red Pen','Pencil','Scale','Other')),
  color text not null,
  quantity integer not null check (quantity between 1 and 99),
  image_path text,
  location text not null,
  description text not null default '',
  status text not null default 'Available' check (status in ('Available','Requested','Given','Unavailable')),
  created_at timestamptz not null default now()
);
create index if not exists items_feed_idx on public.items(status,created_at desc);

create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  requester_id uuid not null references public.users(id) on delete cascade,
  lecture_theatre text not null default '',
  floor text not null default '',
  block text not null default '',
  meeting_location text not null default '',
  message text not null default '',
  status text not null default 'Pending' check (status in ('Pending','Accepted','Rejected','Given','Cancelled')),
  created_at timestamptz not null default now()
);
create index if not exists requests_requester_idx on public.requests(requester_id,created_at desc);
create unique index if not exists requests_one_active_per_item_idx on public.requests(item_id) where status in ('Pending','Accepted');

create table if not exists public.study_materials (
  id uuid primary key default gen_random_uuid(),
  uploader_id uuid not null references public.users(id) on delete cascade,
  type text not null check (type in ('Notes','Assignments','Lab Records','Programs/Code','Previous Year Questions','Study Material')),
  subject text not null,
  unit text not null default '',
  topic text not null default '',
  experiment_number text not null default '',
  assignment_number text not null default '',
  year text not null default '',
  semester text not null,
  branch text not null,
  file_path text not null,
  description text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists materials_feed_idx on public.study_materials(created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  message text not null,
  read_status boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id,created_at desc);

-- Netlify Functions are stateless, so enforce rate limits atomically in Postgres.
create table if not exists public.api_rate_limits (
  bucket_key text primary key,
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  updated_at timestamptz not null default now()
);
create index if not exists api_rate_limits_updated_idx on public.api_rate_limits(updated_at);

create or replace function public.consume_rate_limit(p_key text,p_limit integer,p_window_seconds integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare allowed boolean;
begin
  delete from public.api_rate_limits where updated_at < now() - interval '2 days';
  insert into public.api_rate_limits as r(bucket_key,window_started_at,request_count,updated_at)
  values(p_key,now(),1,now())
  on conflict(bucket_key) do update set
    request_count=case when r.window_started_at <= now() - make_interval(secs=>p_window_seconds) then 1 else r.request_count+1 end,
    window_started_at=case when r.window_started_at <= now() - make_interval(secs=>p_window_seconds) then now() else r.window_started_at end,
    updated_at=now()
  returning request_count <= p_limit into allowed;
  return allowed;
end;
$$;

-- The custom cookie session is not a Supabase Auth JWT. Deny every direct
-- Data API operation to anon/authenticated; trusted API code authorizes each
-- query before using the server-only key (which bypasses RLS).
alter table public.users enable row level security;
alter table public.sessions enable row level security;
alter table public.items enable row level security;
alter table public.requests enable row level security;
alter table public.study_materials enable row level security;
alter table public.notifications enable row level security;
alter table public.api_rate_limits enable row level security;

revoke all on public.users,public.sessions,public.items,public.requests,public.study_materials,public.notifications,public.api_rate_limits from anon,authenticated;
grant all on public.users,public.sessions,public.items,public.requests,public.study_materials,public.notifications,public.api_rate_limits to service_role;

drop policy if exists "deny direct client access" on public.users;
create policy "deny direct client access" on public.users as restrictive for all to anon,authenticated using (false) with check (false);
drop policy if exists "deny direct client access" on public.sessions;
create policy "deny direct client access" on public.sessions as restrictive for all to anon,authenticated using (false) with check (false);
drop policy if exists "deny direct client access" on public.items;
create policy "deny direct client access" on public.items as restrictive for all to anon,authenticated using (false) with check (false);
drop policy if exists "deny direct client access" on public.requests;
create policy "deny direct client access" on public.requests as restrictive for all to anon,authenticated using (false) with check (false);
drop policy if exists "deny direct client access" on public.study_materials;
create policy "deny direct client access" on public.study_materials as restrictive for all to anon,authenticated using (false) with check (false);
drop policy if exists "deny direct client access" on public.notifications;
create policy "deny direct client access" on public.notifications as restrictive for all to anon,authenticated using (false) with check (false);
drop policy if exists "deny direct client access" on public.api_rate_limits;
create policy "deny direct client access" on public.api_rate_limits as restrictive for all to anon,authenticated using (false) with check (false);

revoke all on function public.consume_rate_limit(text,integer,integer) from public,anon,authenticated;
grant execute on function public.consume_rate_limit(text,integer,integer) to service_role;

-- Storage object policies: server calls use a server-only key. No browser
-- client, including a signed-in Supabase Auth client, can access these buckets.
drop policy if exists "deny direct PenPals storage access" on storage.objects;
create policy "deny direct PenPals storage access" on storage.objects
as restrictive for all to anon,authenticated
using (bucket_id not in ('item-images','study-materials'))
with check (bucket_id not in ('item-images','study-materials'));
