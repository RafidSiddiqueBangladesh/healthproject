-- Mood palette + theme customizer persistence for NutriCare
-- Run once in Supabase SQL Editor.

create extension if not exists pgcrypto;

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

create or replace function public.set_updated_at_user_theme_preferences()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_theme_preferences_updated_at on public.user_theme_preferences;
create trigger trg_user_theme_preferences_updated_at
before update on public.user_theme_preferences
for each row
execute function public.set_updated_at_user_theme_preferences();

alter table public.user_theme_preferences enable row level security;

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
