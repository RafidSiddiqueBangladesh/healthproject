-- NutriCare Supabase setup
-- Run this in Supabase SQL Editor (one time).

create extension if not exists pgcrypto;

-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  avatar_url text,
  role text not null default 'patient' check (role in ('patient', 'doctor')),
  points integer not null default 0,
  bmi double precision,
  height_cm double precision,
  weight_kg double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.profiles
  add column if not exists role text not null default 'patient' check (role in ('patient', 'doctor'));

-- Friendships
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (requester_id, recipient_id),
  check (requester_id <> recipient_id)
);

create index if not exists idx_friendships_requester on public.friendships(requester_id);
create index if not exists idx_friendships_recipient on public.friendships(recipient_id);

-- Messages
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  text text not null,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create index if not exists idx_messages_sender on public.messages(sender_id, created_at desc);
create index if not exists idx_messages_recipient on public.messages(recipient_id, created_at desc);

-- Nutrition logs
create table if not exists public.nutrition_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  calories double precision not null default 0,
  amount_label text,
  grams double precision,
  matched_reference text,
  created_at timestamptz not null default now()
);

create index if not exists idx_nutrition_logs_user on public.nutrition_logs(user_id, created_at desc);

-- Cooking inventory
create table if not exists public.cooking_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  amount_label text,
  price double precision not null default 0,
  entry_date timestamptz,
  expiry_date timestamptz,
  used_default_expiry boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_cooking_items_user on public.cooking_items(user_id, created_at desc);

-- Health tracking logs (face/hand/shoulder/live)
create table if not exists public.health_tracking_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  label text not null,
  score double precision,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_health_tracking_logs_user on public.health_tracking_logs(user_id, created_at desc);
create index if not exists idx_health_tracking_logs_type on public.health_tracking_logs(type);

-- BMI history logs
create table if not exists public.bmi_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  bmi double precision not null,
  height_cm double precision not null,
  weight_kg double precision not null,
  category text,
  suggestion text,
  created_at timestamptz not null default now()
);

create index if not exists idx_bmi_logs_user on public.bmi_logs(user_id, created_at desc);

-- Doctor reports
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

create index if not exists idx_doctor_reports_user_created on public.doctor_reports(user_id, created_at desc);
create index if not exists idx_doctor_reports_doctor on public.doctor_reports(doctor_id, created_at desc);

-- Doctor booking logs
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

create index if not exists idx_doctor_bookings_patient_created on public.doctor_bookings(patient_user_id, created_at desc);
create index if not exists idx_doctor_bookings_doctor on public.doctor_bookings(doctor_id, created_at desc);

-- Video call logs (Jitsi/RTC room metadata)
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

create index if not exists idx_video_call_logs_patient_created on public.video_call_logs(patient_user_id, created_at desc);
create index if not exists idx_video_call_logs_doctor_created on public.video_call_logs(doctor_id, created_at desc);

-- Mood palette + theme customizer preferences
create table if not exists public.user_theme_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  mood_palette jsonb not null default '{"Happy":4294955366,"Sad":4286492927,"Neutral":4290500548,"Astonished":4294944378}'::jsonb,
  selected_mood text not null default 'Neutral' check (selected_mood in ('Happy', 'Sad', 'Neutral', 'Astonished')),
  mood_themes jsonb not null default '{"Happy":{"isLight":false,"primaryHue":44,"accentHue":18,"orbHues":[44,20,355,72,108]},"Sad":{"isLight":false,"primaryHue":220,"accentHue":258,"orbHues":[220,244,266,196,176]},"Neutral":{"isLight":false,"primaryHue":158,"accentHue":205,"orbHues":[158,184,205,228,140]},"Astonished":{"isLight":false,"primaryHue":16,"accentHue":332,"orbHues":[16,342,294,52,24]}}'::jsonb,
  is_light boolean not null default false,
  primary_hue double precision not null default 220,
  accent_hue double precision not null default 281,
  orb_hues jsonb not null default '[263,239,276,162,24]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.user_theme_preferences
  add column if not exists mood_themes jsonb not null default '{"Happy":{"isLight":false,"primaryHue":44,"accentHue":18,"orbHues":[44,20,355,72,108]},"Sad":{"isLight":false,"primaryHue":220,"accentHue":258,"orbHues":[220,244,266,196,176]},"Neutral":{"isLight":false,"primaryHue":158,"accentHue":205,"orbHues":[158,184,205,228,140]},"Astonished":{"isLight":false,"primaryHue":16,"accentHue":332,"orbHues":[16,342,294,52,24]}}'::jsonb;

create index if not exists idx_user_theme_preferences_updated_at on public.user_theme_preferences(updated_at desc);

-- Optional: manual costs (if not already created from manual_cost_entries.sql)
create table if not exists public.manual_cost_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  category text not null default 'Food',
  amount double precision not null,
  cost_date timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_manual_cost_entries_user on public.manual_cost_entries(user_id, cost_date desc);

-- Keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists trg_friendships_updated_at on public.friendships;
create trigger trg_friendships_updated_at
before update on public.friendships
for each row
execute function public.set_updated_at();

drop trigger if exists trg_user_theme_preferences_updated_at on public.user_theme_preferences;
create trigger trg_user_theme_preferences_updated_at
before update on public.user_theme_preferences
for each row
execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.messages enable row level security;
alter table public.nutrition_logs enable row level security;
alter table public.cooking_items enable row level security;
alter table public.health_tracking_logs enable row level security;
alter table public.bmi_logs enable row level security;
alter table public.doctor_reports enable row level security;
alter table public.doctor_bookings enable row level security;
alter table public.video_call_logs enable row level security;
alter table public.manual_cost_entries enable row level security;
alter table public.user_theme_preferences enable row level security;

-- Clear and recreate policies safely

drop policy if exists "profiles select own" on public.profiles;
create policy "profiles select own" on public.profiles
for select using (auth.uid() = id);

drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles
for insert with check (auth.uid() = id);

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "friendships read involved" on public.friendships;
create policy "friendships read involved" on public.friendships
for select using (auth.uid() = requester_id or auth.uid() = recipient_id);

drop policy if exists "friendships insert requester" on public.friendships;
create policy "friendships insert requester" on public.friendships
for insert with check (auth.uid() = requester_id);

drop policy if exists "friendships update involved" on public.friendships;
create policy "friendships update involved" on public.friendships
for update using (auth.uid() = requester_id or auth.uid() = recipient_id)
with check (auth.uid() = requester_id or auth.uid() = recipient_id);

drop policy if exists "messages read involved" on public.messages;
create policy "messages read involved" on public.messages
for select using (auth.uid() = sender_id or auth.uid() = recipient_id);

drop policy if exists "messages insert sender" on public.messages;
create policy "messages insert sender" on public.messages
for insert with check (auth.uid() = sender_id);

drop policy if exists "messages update recipient" on public.messages;
create policy "messages update recipient" on public.messages
for update using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);

drop policy if exists "nutrition logs own" on public.nutrition_logs;
create policy "nutrition logs own" on public.nutrition_logs
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "cooking items own" on public.cooking_items;
create policy "cooking items own" on public.cooking_items
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "health logs own" on public.health_tracking_logs;
create policy "health logs own" on public.health_tracking_logs
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "bmi logs own" on public.bmi_logs;
create policy "bmi logs own" on public.bmi_logs
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "doctor reports own" on public.doctor_reports;
create policy "doctor reports own" on public.doctor_reports
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "doctor bookings own" on public.doctor_bookings;
create policy "doctor bookings own" on public.doctor_bookings
for all using (auth.uid() = patient_user_id) with check (auth.uid() = patient_user_id);

drop policy if exists "video call logs own" on public.video_call_logs;
create policy "video call logs own" on public.video_call_logs
for all using (auth.uid() = patient_user_id) with check (auth.uid() = patient_user_id);

drop policy if exists "manual costs own" on public.manual_cost_entries;
create policy "manual costs own" on public.manual_cost_entries
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "theme preferences own read" on public.user_theme_preferences;
create policy "theme preferences own read" on public.user_theme_preferences
for select using (auth.uid() = user_id);

drop policy if exists "theme preferences own insert" on public.user_theme_preferences;
create policy "theme preferences own insert" on public.user_theme_preferences
for insert with check (auth.uid() = user_id);

drop policy if exists "theme preferences own update" on public.user_theme_preferences;
create policy "theme preferences own update" on public.user_theme_preferences
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "theme preferences own delete" on public.user_theme_preferences;
create policy "theme preferences own delete" on public.user_theme_preferences
for delete using (auth.uid() = user_id);

-- Storage buckets for profile/chat images
insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

drop policy if exists "profile images public read" on storage.objects;
create policy "profile images public read" on storage.objects
for select using (bucket_id = 'profile-images');

drop policy if exists "profile images owner write" on storage.objects;
create policy "profile images owner write" on storage.objects
for insert with check (
  bucket_id = 'profile-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "profile images owner update" on storage.objects;
create policy "profile images owner update" on storage.objects
for update using (
  bucket_id = 'profile-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "profile images owner delete" on storage.objects;
create policy "profile images owner delete" on storage.objects
for delete using (
  bucket_id = 'profile-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "chat images public read" on storage.objects;
create policy "chat images public read" on storage.objects
for select using (bucket_id = 'chat-images');

drop policy if exists "chat images owner write" on storage.objects;
create policy "chat images owner write" on storage.objects
for insert with check (
  bucket_id = 'chat-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "chat images owner update" on storage.objects;
create policy "chat images owner update" on storage.objects
for update using (
  bucket_id = 'chat-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

drop policy if exists "chat images owner delete" on storage.objects;
create policy "chat images owner delete" on storage.objects
for delete using (
  bucket_id = 'chat-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);
