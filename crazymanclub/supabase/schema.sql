-- CrazyManClub 신수교감 출석판 Supabase SQL
-- Supabase SQL Editor에서 전체 실행하세요.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  nickname text not null unique,
  role text not null default 'member' check (role in ('member','admin')),
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  nickname text not null,
  attendance_date date not null,
  image_url text,
  status text not null default 'submitted' check (status in ('submitted','approved','rejected')),
  created_at timestamptz not null default now(),
  unique(user_id, attendance_date)
);

alter table public.profiles enable row level security;
alter table public.attendance enable row level security;

drop policy if exists "profiles read all" on public.profiles;
create policy "profiles read all" on public.profiles for select to anon, authenticated using (true);

drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles for insert to authenticated with check (auth.uid() = id);

drop policy if exists "profiles update own or admin" on public.profiles;
create policy "profiles update own or admin" on public.profiles for update to authenticated
using (auth.uid() = id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
with check (auth.uid() = id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

drop policy if exists "attendance read all" on public.attendance;
create policy "attendance read all" on public.attendance for select to anon, authenticated using (true);

drop policy if exists "attendance insert approved own" on public.attendance;
create policy "attendance insert approved own" on public.attendance for insert to authenticated
with check (auth.uid() = user_id and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true));

drop policy if exists "attendance update own or admin" on public.attendance;
create policy "attendance update own or admin" on public.attendance for update to authenticated
using (auth.uid() = user_id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
with check (auth.uid() = user_id or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

insert into storage.buckets (id, name, public)
values ('attendance-images', 'attendance-images', true)
on conflict (id) do nothing;

drop policy if exists "attendance images public read" on storage.objects;
create policy "attendance images public read" on storage.objects for select to anon, authenticated using (bucket_id = 'attendance-images');

drop policy if exists "attendance images authenticated upload" on storage.objects;
create policy "attendance images authenticated upload" on storage.objects for insert to authenticated with check (bucket_id = 'attendance-images');

drop policy if exists "attendance images authenticated update" on storage.objects;
create policy "attendance images authenticated update" on storage.objects for update to authenticated using (bucket_id = 'attendance-images') with check (bucket_id = 'attendance-images');

-- 최초 운영진 설정:
-- 1) 웹에서 본인 계정 회원가입
-- 2) 아래 email 값을 본인 이메일로 바꿔 실행
-- update public.profiles set role='admin', approved=true where email='본인이메일@example.com';
