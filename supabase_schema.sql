-- =================================================================
-- STELR — Supabase Schema
-- =================================================================
-- HOW TO RUN:
--   Supabase Dashboard → SQL Editor → New query → paste → Run
--
-- ⚠️  BEFORE YOU TEST SIGN-UP:
--   Auth → Settings → Email → uncheck "Enable email confirmations"
--   (Re-enable it when you go to production)
--
-- Safe to run multiple times — all statements use IF NOT EXISTS /
-- ON CONFLICT DO NOTHING / CREATE OR REPLACE.
-- =================================================================


-- -----------------------------------------------------------------
-- PROFILES  (auto-created on sign-up via trigger below)
-- -----------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid        references auth.users(id) on delete cascade primary key,
  username      text,
  display_name  text,
  avatar_color  text        default '38b8c4',
  created_at    timestamptz default now()
);


-- -----------------------------------------------------------------
-- SHOWS  (global catalogue cached from TVMaze / AniList)
-- -----------------------------------------------------------------
create table if not exists public.shows (
  tvmaze_id      int  primary key,
  title          text not null,
  platform       text,
  genre          text,
  year           int,
  summary        text,
  image_url      text,
  gradient1      text default '081e24',
  gradient2      text default '020b0e',
  accent_color   text default '38b8c4',
  total_seasons  int,
  total_episodes int,
  updated_at     timestamptz default now()
);


-- -----------------------------------------------------------------
-- USER ROTATION  (one row per user+show)
-- -----------------------------------------------------------------
create table if not exists public.user_shows (
  id                      uuid        default gen_random_uuid() primary key,
  user_id                 uuid        references auth.users(id) on delete cascade not null,
  show_id                 int         not null,
  current_season          int         default 1,
  current_episode         int         default 1,
  total_episodes_in_season int        default 10,
  vibe                    text        default 'not_watching',
  score                   float8      default 0,
  last_checked_at         timestamptz default now(),
  created_at              timestamptz default now(),
  unique (user_id, show_id)
);


-- -----------------------------------------------------------------
-- ACTIVITY FEED
-- -----------------------------------------------------------------
create table if not exists public.activities (
  id         uuid        default gen_random_uuid() primary key,
  user_id    uuid        references auth.users(id) on delete cascade not null,
  show_id    int         not null,
  action     text        not null,
  vibe       text,
  score      float8,
  created_at timestamptz default now()
);


-- -----------------------------------------------------------------
-- SEASON RATINGS
-- -----------------------------------------------------------------
create table if not exists public.season_ratings (
  id         uuid        default gen_random_uuid() primary key,
  user_id    uuid        references auth.users(id) on delete cascade not null,
  show_id    int         not null,
  season     int         not null,
  score      float8      not null,
  created_at timestamptz default now(),
  unique (user_id, show_id, season)
);


-- -----------------------------------------------------------------
-- TOP-5 LISTS
-- -----------------------------------------------------------------
create table if not exists public.user_lists (
  id         uuid        default gen_random_uuid() primary key,
  user_id    uuid        references auth.users(id) on delete cascade not null,
  title      text        not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.list_entries (
  id              uuid  default gen_random_uuid() primary key,
  list_id         uuid  references public.user_lists(id) on delete cascade not null,
  rank            int   not null check (rank between 1 and 5),
  show_id         int,                  -- null for free-text entries
  free_text_title text                  -- populated when show_id is null
);


-- -----------------------------------------------------------------
-- PROBES / RECOMMENDATIONS
-- -----------------------------------------------------------------
create table if not exists public.recommendations (
  id             uuid        default gen_random_uuid() primary key,
  from_user_id   uuid        references auth.users(id) on delete cascade not null,
  to_user_id     uuid        references auth.users(id) on delete cascade not null,
  show_id        int         not null,
  message        text,
  status         text        default 'pending',
  created_at     timestamptz default now()
);


-- =================================================================
-- ROW LEVEL SECURITY
-- =================================================================

alter table public.profiles       enable row level security;
alter table public.shows           enable row level security;
alter table public.user_shows      enable row level security;
alter table public.activities      enable row level security;
alter table public.season_ratings  enable row level security;
alter table public.user_lists      enable row level security;
alter table public.list_entries    enable row level security;
alter table public.recommendations enable row level security;


-- Profiles: only own row
drop policy if exists "profiles: own" on public.profiles;
create policy "profiles: own" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- Shows: anyone reads, authenticated users write
drop policy if exists "shows: read" on public.shows;
create policy "shows: read" on public.shows for select using (true);

drop policy if exists "shows: insert" on public.shows;
create policy "shows: insert" on public.shows
  for insert with check (auth.uid() is not null);

drop policy if exists "shows: update" on public.shows;
create policy "shows: update" on public.shows
  for update using (auth.uid() is not null);

-- User shows: own rows only
drop policy if exists "user_shows: own" on public.user_shows;
create policy "user_shows: own" on public.user_shows
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Activities: own write, everyone reads (friend feed)
drop policy if exists "activities: insert own" on public.activities;
create policy "activities: insert own" on public.activities
  for insert with check (auth.uid() = user_id);

drop policy if exists "activities: read all" on public.activities;
create policy "activities: read all" on public.activities
  for select using (true);

-- Season ratings: own rows only
drop policy if exists "season_ratings: own" on public.season_ratings;
create policy "season_ratings: own" on public.season_ratings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Lists: own rows only
drop policy if exists "user_lists: own" on public.user_lists;
create policy "user_lists: own" on public.user_lists
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- List entries: own via parent list
drop policy if exists "list_entries: own" on public.list_entries;
create policy "list_entries: own" on public.list_entries
  for all using (
    exists (
      select 1 from public.user_lists
      where id = list_entries.list_id
        and user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.user_lists
      where id = list_entries.list_id
        and user_id = auth.uid()
    )
  );

-- Recommendations: sender or recipient
drop policy if exists "recommendations: own" on public.recommendations;
create policy "recommendations: own" on public.recommendations
  for all using (
    auth.uid() = from_user_id or auth.uid() = to_user_id
  );


-- =================================================================
-- TRIGGER: auto-create profile row on sign-up
-- =================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
