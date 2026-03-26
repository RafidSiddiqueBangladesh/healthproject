-- Manual cost entries table for Cost Analysis
-- Run this in Supabase SQL Editor.

create table if not exists public.manual_cost_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  category text not null default 'Food',
  amount numeric(12,2) not null default 0,
  cost_date timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_manual_cost_entries_user_id
  on public.manual_cost_entries(user_id);

create index if not exists idx_manual_cost_entries_cost_date
  on public.manual_cost_entries(cost_date desc);

alter table public.manual_cost_entries enable row level security;

-- Allow users to manage only their own manual cost entries.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'manual_cost_entries'
      and policyname = 'manual_cost_entries_select_own'
  ) then
    create policy manual_cost_entries_select_own
      on public.manual_cost_entries
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'manual_cost_entries'
      and policyname = 'manual_cost_entries_insert_own'
  ) then
    create policy manual_cost_entries_insert_own
      on public.manual_cost_entries
      for insert
      to authenticated
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'manual_cost_entries'
      and policyname = 'manual_cost_entries_update_own'
  ) then
    create policy manual_cost_entries_update_own
      on public.manual_cost_entries
      for update
      to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'manual_cost_entries'
      and policyname = 'manual_cost_entries_delete_own'
  ) then
    create policy manual_cost_entries_delete_own
      on public.manual_cost_entries
      for delete
      to authenticated
      using (auth.uid() = user_id);
  end if;
end $$;
