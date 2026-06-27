create extension if not exists pgcrypto;

create table if not exists public.admin_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  shop_id text not null,
  shop_name text not null,
  shop_address text not null,
  report_type text not null,
  report_content text not null,
  source_url text,
  reporter_contact text,
  status text not null default 'pending' check (status in ('pending','reviewing','approved','rejected','private')),
  admin_memo text,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists reports_status_idx on public.reports(status);
create index if not exists reports_shop_id_idx on public.reports(shop_id);
create index if not exists reports_created_at_idx on public.reports(created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row
execute function public.set_updated_at();

create or replace function public.prepare_public_report_insert()
returns trigger
language plpgsql
as $$
begin
  new.status = 'pending';
  new.admin_memo = null;
  new.reviewed_at = null;
  new.reviewed_by = null;
  return new;
end;
$$;

drop trigger if exists reports_prepare_public_insert on public.reports;
create trigger reports_prepare_public_insert
before insert on public.reports
for each row
execute function public.prepare_public_report_insert();

create or replace function public.submit_public_report(
  p_shop_id text,
  p_shop_name text,
  p_shop_address text,
  p_report_type text,
  p_report_content text,
  p_source_url text default null,
  p_reporter_contact text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.reports (
    shop_id,
    shop_name,
    shop_address,
    report_type,
    report_content,
    source_url,
    reporter_contact,
    status
  )
  values (
    nullif(trim(p_shop_id), ''),
    nullif(trim(p_shop_name), ''),
    nullif(trim(p_shop_address), ''),
    nullif(trim(p_report_type), ''),
    nullif(trim(p_report_content), ''),
    nullif(trim(p_source_url), ''),
    nullif(trim(p_reporter_contact), ''),
    'pending'
  );
end;
$$;

grant execute on function public.submit_public_report(text,text,text,text,text,text,text) to anon, authenticated;

create or replace function public.is_reports_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_profiles
    where user_id = auth.uid()
  );
$$;

alter table public.reports enable row level security;
alter table public.admin_profiles enable row level security;

drop policy if exists "public can insert pending reports" on public.reports;
create policy "public can insert pending reports"
on public.reports
for insert
to anon, authenticated
with check (true);

drop policy if exists "public can read approved reports" on public.reports;
create policy "public can read approved reports"
on public.reports
for select
to anon, authenticated
using (status = 'approved');

drop policy if exists "admins can read all reports" on public.reports;
create policy "admins can read all reports"
on public.reports
for select
to authenticated
using (public.is_reports_admin());

drop policy if exists "admins can update reports" on public.reports;
create policy "admins can update reports"
on public.reports
for update
to authenticated
using (public.is_reports_admin())
with check (public.is_reports_admin());

drop policy if exists "admins can read admin profiles" on public.admin_profiles;
create policy "admins can read admin profiles"
on public.admin_profiles
for select
to authenticated
using (public.is_reports_admin());

-- 관리자 등록 예시:
-- 1. Supabase Auth에서 관리자 계정을 만든다.
-- 2. auth.users에서 user id를 확인한다.
-- 3. 아래 값을 바꿔 실행한다.
-- insert into public.admin_profiles (user_id, email)
-- values ('00000000-0000-0000-0000-000000000000', 'admin@example.org');
