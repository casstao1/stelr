-- stelr Supabase Schema
-- Run this in the Supabase SQL Editor: https://supabase.com/dashboard/project/vdtsdanotuewetigepbg/sql

-- PROFILES (extends auth.users)
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text unique,
  display_name text,
  avatar_color text default '#E5604A',
  created_at timestamptz default now()
);
alter table public.profiles enable row level security;
create policy "Public profiles are viewable by everyone" on profiles for select using (true);
create policy "Users can insert their own profile" on profiles for insert with check (auth.uid() = id);
create policy "Users can update their own profile" on profiles for update using (auth.uid() = id);

-- auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, display_name)
  values (new.id, split_part(new.email, '@', 1), split_part(new.email, '@', 1));
  return new;
end;
$$ language plpgsql security definer;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- SHOWS (TVMaze cache)
create table if not exists public.shows (
  id serial primary key,
  tvmaze_id integer unique,
  title text not null,
  platform text,
  genre text,
  year integer,
  summary text,
  image_url text,
  gradient1 text default '#081e24',
  gradient2 text default '#020b0e',
  accent_color text default '#38b8c4',
  total_seasons integer,
  total_episodes integer,
  created_at timestamptz default now()
);
alter table public.shows enable row level security;
create policy "Shows are viewable by everyone" on shows for select using (true);
create policy "Authenticated users can insert shows" on shows for insert with check (auth.role() = 'authenticated');

-- USER_SHOWS (my rotation)
create table if not exists public.user_shows (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  show_id integer references public.shows(id) on delete cascade not null,
  current_season integer default 1,
  current_episode integer default 1,
  total_episodes_in_season integer default 10,
  vibe text default 'just_ok' check (vibe in ('must_watch','going_good','just_ok','super_boring','not_watching')),
  score numeric(4,1) default 7.0 check (score >= 0 and score <= 10),
  last_checked_at timestamptz default now(),
  added_at timestamptz default now(),
  unique(user_id, show_id)
);
alter table public.user_shows enable row level security;
create policy "Users can view own shows" on user_shows for select using (auth.uid() = user_id);
create policy "Users can insert own shows" on user_shows for insert with check (auth.uid() = user_id);
create policy "Users can update own shows" on user_shows for update using (auth.uid() = user_id);
create policy "Users can delete own shows" on user_shows for delete using (auth.uid() = user_id);

-- FRIENDS
create table if not exists public.friends (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  friend_id uuid references auth.users(id) on delete cascade not null,
  status text default 'pending' check (status in ('pending','accepted','blocked')),
  created_at timestamptz default now(),
  unique(user_id, friend_id)
);
alter table public.friends enable row level security;
create policy "Users can view own friendships" on friends for select using (auth.uid() = user_id or auth.uid() = friend_id);
create policy "Users can insert friendships" on friends for insert with check (auth.uid() = user_id);
create policy "Users can update own friendships" on friends for update using (auth.uid() = user_id or auth.uid() = friend_id);

-- ACTIVITIES (feed)
create table if not exists public.activities (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  show_id integer references public.shows(id) on delete cascade not null,
  action text not null,
  vibe text,
  score numeric(4,1),
  created_at timestamptz default now()
);
alter table public.activities enable row level security;
create policy "Activities visible to friends" on activities for select using (auth.uid() = user_id);
create policy "Users can insert activities" on activities for insert with check (auth.uid() = user_id);

-- RECOMMENDATIONS (tell everyone)
create table if not exists public.recommendations (
  id uuid default gen_random_uuid() primary key,
  from_user_id uuid references auth.users(id) on delete cascade not null,
  to_user_id uuid references auth.users(id) on delete cascade not null,
  show_id integer references public.shows(id) on delete cascade not null,
  message text,
  read boolean default false,
  created_at timestamptz default now()
);
alter table public.recommendations enable row level security;
create policy "Sender can view sent" on recommendations for select using (auth.uid() = from_user_id or auth.uid() = to_user_id);
create policy "Users can send recommendations" on recommendations for insert with check (auth.uid() = from_user_id);
create policy "Recipient can mark read" on recommendations for update using (auth.uid() = to_user_id);

-- RALLIES (watch together)
create table if not exists public.rallies (
  id uuid default gen_random_uuid() primary key,
  from_user_id uuid references auth.users(id) on delete cascade not null,
  show_id integer references public.shows(id) on delete cascade not null,
  message text default 'Watch together now!',
  created_at timestamptz default now()
);
alter table public.rallies enable row level security;
create policy "Anyone can view rallies" on rallies for select using (true);
create policy "Users can create rallies" on rallies for insert with check (auth.uid() = from_user_id);

-- EPISODE_COMMENTS
-- Users can comment on individual episodes they've watched.
-- Spoiler-safe: a viewer only sees a friend's comment on episode N once
-- their own current_episode on that show exceeds N.
create table if not exists public.episode_comments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  show_id integer references public.shows(id) on delete cascade not null,
  season integer not null default 1,
  episode integer not null,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, show_id, season, episode)  -- one note per episode per user
);
alter table public.episode_comments enable row level security;

-- Own comments: always visible to the author.
create policy "Users can view own episode comments"
  on episode_comments for select
  using (auth.uid() = user_id);

-- Friend comments: visible only when the viewer's progress on that show
-- has surpassed the commented episode (viewer's current_episode > comment.episode).
-- We join user_shows to enforce the spoiler gate at the DB level.
create policy "Users can view friend episode comments after surpassing that episode"
  on episode_comments for select
  using (
    exists (
      select 1 from public.user_shows us
      join public.friends f
        on (f.user_id = auth.uid() and f.friend_id = episode_comments.user_id
            and f.status = 'accepted')
           or
           (f.friend_id = auth.uid() and f.user_id = episode_comments.user_id
            and f.status = 'accepted')
      where us.user_id = auth.uid()
        and us.show_id = episode_comments.show_id
        and us.current_season >= episode_comments.season
        and (
          us.current_season > episode_comments.season
          or us.current_episode > episode_comments.episode
        )
    )
  );

create policy "Users can insert own episode comments"
  on episode_comments for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.user_shows us
      where us.user_id = auth.uid()
        and us.show_id = episode_comments.show_id
        and (
          us.current_season > episode_comments.season
          or (us.current_season = episode_comments.season
              and us.current_episode >= episode_comments.episode)
        )
    )
  );

create policy "Users can update own episode comments"
  on episode_comments for update
  using (auth.uid() = user_id);

create policy "Users can delete own episode comments"
  on episode_comments for delete
  using (auth.uid() = user_id);

-- Auto-update updated_at on edits
create or replace function public.touch_episode_comment_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger episode_comments_updated_at
  before update on public.episode_comments
  for each row execute procedure public.touch_episode_comment_updated_at();

-- REALTIME: enable replication for live feed updates
alter publication supabase_realtime add table activities;
alter publication supabase_realtime add table rallies;
alter publication supabase_realtime add table recommendations;
alter publication supabase_realtime add table episode_comments;
