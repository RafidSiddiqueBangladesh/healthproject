-- Doctor / Patient role + telehealth logs setup for NutriCare
-- Run this in Supabase SQL editor.

create extension if not exists pgcrypto;

-- 1) Save app role in profiles
alter table if exists public.profiles
  add column if not exists role text not null default 'patient' check (role in ('patient', 'doctor'));

-- 2) Doctor reports (patient sends to doctor)
create table if not exists public.doctor_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  doctor_id text not null,
  doctor_name text not null,
  doctor_specialty text,
  report_title text not null default 'Health Report',
  report_text text not null,
  report_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_doctor_reports_user_created
  on public.doctor_reports(user_id, created_at desc);

create index if not exists idx_doctor_reports_doctor
  on public.doctor_reports(doctor_id, created_at desc);

-- 3) Booking logs
create table if not exists public.doctor_bookings (
  id uuid primary key default gen_random_uuid(),
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  doctor_id text not null,
  doctor_name text not null,
  doctor_specialty text,
  booking_status text not null default 'booked' check (booking_status in ('booked', 'cancelled', 'completed')),
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_doctor_bookings_patient_created
  on public.doctor_bookings(patient_user_id, created_at desc);

create index if not exists idx_doctor_bookings_doctor_created
  on public.doctor_bookings(doctor_id, created_at desc);

-- 4) Video call logs (uses free Jitsi room URLs)
create table if not exists public.video_call_logs (
  id uuid primary key default gen_random_uuid(),
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  doctor_id text not null,
  doctor_name text not null,
  doctor_specialty text,
  room_name text not null,
  join_url text not null,
  call_status text not null default 'requested' check (call_status in ('requested', 'ongoing', 'ended', 'missed')),
  initiated_by_user_id uuid references public.profiles(id) on delete set null,
  call_context text,
  started_at timestamptz,
  joined_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_video_call_logs_patient_created
  on public.video_call_logs(patient_user_id, created_at desc);

create index if not exists idx_video_call_logs_doctor_created
  on public.video_call_logs(doctor_id, created_at desc);

-- 5) RLS (patient owns their own rows)
alter table public.doctor_reports enable row level security;
alter table public.doctor_bookings enable row level security;
alter table public.video_call_logs enable row level security;

drop policy if exists "doctor reports own" on public.doctor_reports;
create policy "doctor reports own" on public.doctor_reports
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "doctor bookings own" on public.doctor_bookings;
create policy "doctor bookings own" on public.doctor_bookings
for all using (auth.uid() = patient_user_id) with check (auth.uid() = patient_user_id);

drop policy if exists "video call logs own" on public.video_call_logs;
create policy "video call logs own" on public.video_call_logs
for all using (auth.uid() = patient_user_id) with check (auth.uid() = patient_user_id);
