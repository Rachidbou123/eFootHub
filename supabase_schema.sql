-- eFootHub Supabase schema
-- Run this in the Supabase SQL editor after creating your project.

create extension if not exists "pgcrypto";

-- Profiles and admin roles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text,
  avatar_url text,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Core content
create table if not exists public.managers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  rating integer not null default 87,
  image_url text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.boosters (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  level integer not null default 2,
  effects jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  name text not null,
  team text,
  position text,
  overall_rating integer not null default 0,
  playstyle text,
  build jsonb not null default '{}'::jsonb,
  stats jsonb not null default '{}'::jsonb,
  manager_id uuid references public.managers(id) on delete set null,
  booster_slot_1 uuid references public.boosters(id) on delete set null,
  booster_slot_2 uuid references public.boosters(id) on delete set null,
  image_url text,
  card_type text,
  version_group text,
  release_date date,
  status text not null default 'official' check (status in ('official', 'draft', 'predicted')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.player_versions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  version_label text not null,
  release_date date,
  overall_rating integer,
  playstyle text,
  booster_snapshot jsonb not null default '{}'::jsonb,
  stats_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  title text not null,
  excerpt text,
  content text not null,
  image_url text,
  category text not null default 'News',
  status text not null default 'draft' check (status in ('draft', 'published')),
  author_id uuid references public.profiles(id) on delete set null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.predicted_players (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  name text not null,
  team text,
  position text,
  predicted_rating integer not null default 0,
  predicted_stats jsonb not null default '{}'::jsonb,
  predicted_boosters jsonb not null default '{}'::jsonb,
  confidence numeric(5,2) not null default 0,
  expected_release_date date,
  votes_agree integer not null default 0,
  votes_disagree integer not null default 0,
  image_url text,
  status text not null default 'published' check (status in ('draft', 'published')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_ratings (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  stars integer not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  unique (player_id, user_id)
);

create table if not exists public.build_battles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  build_a jsonb not null default '{}'::jsonb,
  build_b jsonb not null default '{}'::jsonb,
  votes_a integer not null default 0,
  votes_b integer not null default 0,
  status text not null default 'active' check (status in ('active', 'closed')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text,
  link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.squads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  formation text not null,
  squad jsonb not null default '{}'::jsonb,
  manager_id uuid references public.managers(id) on delete set null,
  public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_settings_updated_at on public.settings;
create trigger set_settings_updated_at before update on public.settings
for each row execute function public.set_updated_at();

drop trigger if exists set_managers_updated_at on public.managers;
create trigger set_managers_updated_at before update on public.managers
for each row execute function public.set_updated_at();

drop trigger if exists set_boosters_updated_at on public.boosters;
create trigger set_boosters_updated_at before update on public.boosters
for each row execute function public.set_updated_at();

drop trigger if exists set_players_updated_at on public.players;
create trigger set_players_updated_at before update on public.players
for each row execute function public.set_updated_at();

drop trigger if exists set_blog_posts_updated_at on public.blog_posts;
create trigger set_blog_posts_updated_at before update on public.blog_posts
for each row execute function public.set_updated_at();

drop trigger if exists set_predicted_players_updated_at on public.predicted_players;
create trigger set_predicted_players_updated_at before update on public.predicted_players
for each row execute function public.set_updated_at();

drop trigger if exists set_build_battles_updated_at on public.build_battles;
create trigger set_build_battles_updated_at before update on public.build_battles
for each row execute function public.set_updated_at();

-- RLS
alter table public.profiles enable row level security;
alter table public.settings enable row level security;
alter table public.managers enable row level security;
alter table public.boosters enable row level security;
alter table public.players enable row level security;
alter table public.player_versions enable row level security;
alter table public.blog_posts enable row level security;
alter table public.predicted_players enable row level security;
alter table public.community_ratings enable row level security;
alter table public.build_battles enable row level security;
alter table public.notifications enable row level security;
alter table public.squads enable row level security;

create or replace function public.is_admin()
returns boolean language sql stable as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

-- Public read policies
drop policy if exists "public read managers" on public.managers;
create policy "public read managers" on public.managers for select using (true);

drop policy if exists "public read boosters" on public.boosters;
create policy "public read boosters" on public.boosters for select using (true);

drop policy if exists "public read players" on public.players;
create policy "public read players" on public.players for select using (status = 'official' or status = 'predicted');

drop policy if exists "public read player versions" on public.player_versions;
create policy "public read player versions" on public.player_versions for select using (true);

drop policy if exists "public read published blog posts" on public.blog_posts;
create policy "public read published blog posts" on public.blog_posts for select using (status = 'published');

drop policy if exists "public read published predicted players" on public.predicted_players;
create policy "public read published predicted players" on public.predicted_players for select using (status = 'published');

drop policy if exists "public read build battles" on public.build_battles;
create policy "public read build battles" on public.build_battles for select using (status = 'active' or status = 'closed');

drop policy if exists "public read public squads" on public.squads;
create policy "public read public squads" on public.squads for select using (public = true);

-- Authenticated access
drop policy if exists "authenticated insert profiles" on public.profiles;
create policy "authenticated insert profiles" on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles for update using (auth.uid() = id);

drop policy if exists "admins manage settings" on public.settings;
create policy "admins manage settings" on public.settings for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage managers" on public.managers;
create policy "admins manage managers" on public.managers for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage boosters" on public.boosters;
create policy "admins manage boosters" on public.boosters for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage players" on public.players;
create policy "admins manage players" on public.players for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage player versions" on public.player_versions;
create policy "admins manage player versions" on public.player_versions for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage blog posts" on public.blog_posts;
create policy "admins manage blog posts" on public.blog_posts for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage predicted players" on public.predicted_players;
create policy "admins manage predicted players" on public.predicted_players for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage build battles" on public.build_battles;
create policy "admins manage build battles" on public.build_battles for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage notifications" on public.notifications;
create policy "admins manage notifications" on public.notifications for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "users manage own ratings" on public.community_ratings;
create policy "users manage own ratings" on public.community_ratings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "users manage own squads" on public.squads;
create policy "users manage own squads" on public.squads for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
