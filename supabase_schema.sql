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

create table if not exists public.shop_memos (
  shop_id text primary key,
  shop_name text not null,
  dong text,
  address text,
  status text,
  open_date text,
  close_date text,
  field_check text,
  open_guess text,
  online_ad text,
  source_url text,
  memo_text text,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists shop_memos_dong_idx on public.shop_memos(dong);
create index if not exists shop_memos_updated_at_idx on public.shop_memos(updated_at desc);

create table if not exists public.field_notes (
  id uuid primary key default gen_random_uuid(),
  shop_id text not null,
  shop_name text not null,
  shop_address text not null,
  dong text,
  investigator_name text,
  investigation_date date,
  field_check text,
  open_guess text,
  online_ad text,
  source_url text,
  memo_text text,
  field_lat double precision,
  field_lon double precision,
  field_accuracy_m double precision,
  field_location_captured_at timestamptz,
  status text not null default 'submitted' check (status in ('submitted','reviewing','reflected','archived','private')),
  admin_memo text,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.field_notes add column if not exists field_lat double precision;
alter table public.field_notes add column if not exists field_lon double precision;
alter table public.field_notes add column if not exists field_accuracy_m double precision;
alter table public.field_notes add column if not exists field_location_captured_at timestamptz;

create index if not exists field_notes_status_idx on public.field_notes(status);
create index if not exists field_notes_shop_id_idx on public.field_notes(shop_id);
create index if not exists field_notes_created_at_idx on public.field_notes(created_at desc);

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

drop trigger if exists shop_memos_set_updated_at on public.shop_memos;
create trigger shop_memos_set_updated_at
before update on public.shop_memos
for each row
execute function public.set_updated_at();

drop trigger if exists field_notes_set_updated_at on public.field_notes;
create trigger field_notes_set_updated_at
before update on public.field_notes
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
set row_security = off
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

alter function public.submit_public_report(text,text,text,text,text,text,text) owner to postgres;
revoke all on function public.submit_public_report(text,text,text,text,text,text,text) from public;
grant execute on function public.submit_public_report(text,text,text,text,text,text,text) to anon, authenticated;

drop function if exists public.submit_field_note(text,text,text,text,text,text,text,text,text,text,text);
drop function if exists public.submit_field_note(text,text,text,text,text,text,text,text,text,text,text,double precision,double precision,double precision,text);

create or replace function public.submit_field_note(
  p_shop_id text,
  p_shop_name text,
  p_shop_address text,
  p_dong text default null,
  p_investigator_name text default null,
  p_investigation_date text default null,
  p_field_check text default null,
  p_open_guess text default null,
  p_online_ad text default null,
  p_source_url text default null,
  p_memo_text text default null,
  p_field_lat double precision default null,
  p_field_lon double precision default null,
  p_field_accuracy_m double precision default null,
  p_field_location_captured_at text default null
)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  insert into public.field_notes (
    shop_id,
    shop_name,
    shop_address,
    dong,
    investigator_name,
    investigation_date,
    field_check,
    open_guess,
    online_ad,
    source_url,
    memo_text,
    field_lat,
    field_lon,
    field_accuracy_m,
    field_location_captured_at,
    status
  )
  values (
    nullif(trim(p_shop_id), ''),
    nullif(trim(p_shop_name), ''),
    nullif(trim(p_shop_address), ''),
    nullif(trim(p_dong), ''),
    nullif(trim(p_investigator_name), ''),
    nullif(trim(p_investigation_date), '')::date,
    nullif(trim(p_field_check), ''),
    nullif(trim(p_open_guess), ''),
    nullif(trim(p_online_ad), ''),
    nullif(trim(p_source_url), ''),
    nullif(trim(p_memo_text), ''),
    p_field_lat,
    p_field_lon,
    p_field_accuracy_m,
    nullif(trim(p_field_location_captured_at), '')::timestamptz,
    'submitted'
  );
end;
$$;

alter function public.submit_field_note(text,text,text,text,text,text,text,text,text,text,text,double precision,double precision,double precision,text) owner to postgres;
revoke all on function public.submit_field_note(text,text,text,text,text,text,text,text,text,text,text,double precision,double precision,double precision,text) from public;
grant execute on function public.submit_field_note(text,text,text,text,text,text,text,text,text,text,text,double precision,double precision,double precision,text) to anon, authenticated;

create or replace function public.submit_field_note_v2(p_note jsonb)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  insert into public.field_notes (
    shop_id,
    shop_name,
    shop_address,
    dong,
    investigator_name,
    investigation_date,
    field_check,
    open_guess,
    online_ad,
    source_url,
    memo_text,
    field_lat,
    field_lon,
    field_accuracy_m,
    field_location_captured_at,
    status
  )
  values (
    nullif(trim(p_note->>'shop_id'), ''),
    nullif(trim(p_note->>'shop_name'), ''),
    nullif(trim(p_note->>'shop_address'), ''),
    nullif(trim(p_note->>'dong'), ''),
    nullif(trim(p_note->>'investigator_name'), ''),
    nullif(trim(p_note->>'investigation_date'), '')::date,
    nullif(trim(p_note->>'field_check'), ''),
    nullif(trim(p_note->>'open_guess'), ''),
    nullif(trim(p_note->>'online_ad'), ''),
    nullif(trim(p_note->>'source_url'), ''),
    nullif(trim(p_note->>'memo_text'), ''),
    nullif(trim(p_note->>'field_lat'), '')::double precision,
    nullif(trim(p_note->>'field_lon'), '')::double precision,
    nullif(trim(p_note->>'field_accuracy_m'), '')::double precision,
    nullif(trim(p_note->>'field_location_captured_at'), '')::timestamptz,
    'submitted'
  );
end;
$$;

alter function public.submit_field_note_v2(jsonb) owner to postgres;
revoke all on function public.submit_field_note_v2(jsonb) from public;
grant execute on function public.submit_field_note_v2(jsonb) to anon, authenticated;

create or replace function public.delete_admin_report(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.is_reports_admin() then
    raise exception '관리자 권한이 필요합니다.';
  end if;

  delete from public.reports
  where id = p_id;
end;
$$;

alter function public.delete_admin_report(uuid) owner to postgres;
revoke all on function public.delete_admin_report(uuid) from public;
grant execute on function public.delete_admin_report(uuid) to authenticated;

create or replace function public.delete_field_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
set row_security = off
as $$
begin
  if not public.is_reports_admin() then
    raise exception '관리자 권한이 필요합니다.';
  end if;

  delete from public.field_notes
  where id = p_id;
end;
$$;

alter function public.delete_field_note(uuid) owner to postgres;
revoke all on function public.delete_field_note(uuid) from public;
grant execute on function public.delete_field_note(uuid) to authenticated;

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
alter table public.shop_memos enable row level security;
alter table public.field_notes enable row level security;

drop policy if exists "public can insert pending reports" on public.reports;
create policy "public can insert pending reports"
on public.reports
for insert
to public
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

drop policy if exists "admins can delete reports" on public.reports;
create policy "admins can delete reports"
on public.reports
for delete
to authenticated
using (public.is_reports_admin());

drop policy if exists "admins can read admin profiles" on public.admin_profiles;
create policy "admins can read admin profiles"
on public.admin_profiles
for select
to authenticated
using (public.is_reports_admin());

drop policy if exists "admins can read shop memos" on public.shop_memos;
create policy "admins can read shop memos"
on public.shop_memos
for select
to authenticated
using (public.is_reports_admin());

drop policy if exists "admins can insert shop memos" on public.shop_memos;
create policy "admins can insert shop memos"
on public.shop_memos
for insert
to authenticated
with check (public.is_reports_admin());

drop policy if exists "admins can update shop memos" on public.shop_memos;
create policy "admins can update shop memos"
on public.shop_memos
for update
to authenticated
using (public.is_reports_admin())
with check (public.is_reports_admin());

drop policy if exists "admins can read field notes" on public.field_notes;
create policy "admins can read field notes"
on public.field_notes
for select
to authenticated
using (public.is_reports_admin());

drop policy if exists "public can read reflected field notes" on public.field_notes;
create policy "public can read reflected field notes"
on public.field_notes
for select
to anon, authenticated
using (status = 'reflected');

drop policy if exists "admins can update field notes" on public.field_notes;
create policy "admins can update field notes"
on public.field_notes
for update
to authenticated
using (public.is_reports_admin())
with check (public.is_reports_admin());

drop policy if exists "admins can delete field notes" on public.field_notes;
create policy "admins can delete field notes"
on public.field_notes
for delete
to authenticated
using (public.is_reports_admin());

-- 관리자 등록 예시:
-- 1. Supabase Auth에서 관리자 계정을 만든다.
-- 2. auth.users에서 user id를 확인한다.
-- 3. 아래 값을 바꿔 실행한다.
-- insert into public.admin_profiles (user_id, email)
-- values ('00000000-0000-0000-0000-000000000000', 'admin@example.org');
