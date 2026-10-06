-- V12.1：帆夢社群資料與拾頁共用 Auth，但由帆夢專用 schema 管理。
-- 這份 migration 必須由共用 Supabase 專案的唯一 migration 序列部署。
-- 若舊 public 表已存在，先複製資料並封住舊表寫入；舊版 App 暫可唯讀。
create schema if not exists sailune_community;
revoke all on schema sailune_community from public, anon, authenticated;
grant usage on schema sailune_community to authenticated;

do $$
begin
  if to_regclass('sailune_community.community_templates') is not null then
    raise exception 'Sailune community_templates already exists; inspect before migrating';
  end if;
  if to_regclass('sailune_community.community_forum_posts') is not null then
    raise exception 'Sailune community_forum_posts already exists; inspect before migrating';
  end if;
end;
$$;

create table if not exists sailune_community.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table sailune_community.admins enable row level security;
revoke all on sailune_community.admins from public, anon, authenticated;

create or replace function sailune_community.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from sailune_community.admins
    where user_id = auth.uid()
  );
$$;
revoke all on function sailune_community.is_admin() from public, anon, authenticated;
grant execute on function sailune_community.is_admin() to authenticated;

create or replace function sailune_community.template_payload_valid(payload jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select jsonb_typeof(payload) = 'object'
    and payload->>'formatVersion' = '1'
    and coalesce(payload->>'author', '') = ''
    and coalesce(payload->>'synopsis', '') = ''
    and coalesce(payload->'volumes', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'timelineCards', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'planningMetadata', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'annotations', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'storyLines', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'stages', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'items', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'stageStarts', '[]'::jsonb) = '[]'::jsonb
    and coalesce(payload->'placements', '[]'::jsonb) = '[]'::jsonb
    and (payload->'backgroundText' is null or payload->'backgroundText' = 'null'::jsonb)
    and not jsonb_path_exists(payload, '$.nodes[*] ? (@.sectionID != null)')
    and not jsonb_path_exists(payload, '$.events[*] ? (@.sectionID != null)')
    and case when payload->'events' is null then true
      when jsonb_typeof(payload->'events') = 'array' then
        not exists (select 1 from jsonb_array_elements(payload->'events') as event where event->>'nodeID' is null)
      else false end
    and octet_length(payload::text) <= 6291456;
$$;
revoke all on function sailune_community.template_payload_valid(jsonb) from public, anon, authenticated;
grant execute on function sailune_community.template_payload_valid(jsonb) to authenticated;

create table if not exists sailune_community.community_templates (
  id uuid primary key,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  name text not null check (char_length(name) between 1 and 120),
  summary text not null default '' check (char_length(summary) <= 500),
  format_version integer not null default 1 check (format_version = 1),
  payload jsonb not null,
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table sailune_community.community_templates
  drop constraint if exists community_templates_payload_check;
alter table sailune_community.community_templates
  add constraint community_templates_payload_check
  check (sailune_community.template_payload_valid(payload));
create index if not exists community_templates_visible_recent
  on sailune_community.community_templates (created_at desc, id) where not hidden;

create table if not exists sailune_community.community_forum_posts (
  id uuid primary key,
  author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  board text not null check (board in ('announcements', 'writing', 'works', 'sailune', 'suggestions')),
  title text not null check (char_length(title) between 1 and 160),
  body text not null check (char_length(body) between 1 and 20000),
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists community_forum_board_recent
  on sailune_community.community_forum_posts (board, created_at desc, id) where not hidden;

do $$
begin
  if to_regclass('public.community_templates') is not null then
    insert into sailune_community.community_templates
      (id, owner_id, display_name, name, summary, format_version, payload, hidden, created_at, updated_at)
    select id, owner_id, display_name, name, summary, format_version, payload, hidden, created_at, updated_at
    from public.community_templates;
    if (select count(*) from sailune_community.community_templates)
       <> (select count(*) from public.community_templates) then
      raise exception 'community_templates copy count mismatch';
    end if;
    revoke insert, update, delete on public.community_templates from public, anon, authenticated;
  end if;
  if to_regclass('public.community_forum_posts') is not null then
    insert into sailune_community.community_forum_posts
      (id, author_id, display_name, board, title, body, hidden, created_at, updated_at)
    select id, author_id, display_name, board, title, body, hidden, created_at, updated_at
    from public.community_forum_posts;
    if (select count(*) from sailune_community.community_forum_posts)
       <> (select count(*) from public.community_forum_posts) then
      raise exception 'community_forum_posts copy count mismatch';
    end if;
    revoke insert, update, delete on public.community_forum_posts from public, anon, authenticated;
  end if;
end;
$$;

alter table sailune_community.community_templates enable row level security;
alter table sailune_community.community_forum_posts enable row level security;
drop policy if exists "members read shared templates" on sailune_community.community_templates;
drop policy if exists "members publish own templates" on sailune_community.community_templates;
drop policy if exists "owners and admins hide templates" on sailune_community.community_templates;
drop policy if exists "members read forum" on sailune_community.community_forum_posts;
drop policy if exists "members write own posts" on sailune_community.community_forum_posts;
drop policy if exists "authors and admins edit forum" on sailune_community.community_forum_posts;

create policy "members read shared templates" on sailune_community.community_templates
  for select to authenticated
  using (not hidden or owner_id = auth.uid() or sailune_community.is_admin());
create policy "members publish own templates" on sailune_community.community_templates
  for insert to authenticated with check (owner_id = auth.uid());
create policy "owners and admins hide templates" on sailune_community.community_templates
  for update to authenticated
  using (owner_id = auth.uid() or sailune_community.is_admin())
  with check (owner_id = auth.uid() or sailune_community.is_admin());
create policy "members read forum" on sailune_community.community_forum_posts
  for select to authenticated
  using (not hidden or author_id = auth.uid() or sailune_community.is_admin());
create policy "members write own posts" on sailune_community.community_forum_posts
  for insert to authenticated
  with check (author_id = auth.uid() and (board <> 'announcements' or sailune_community.is_admin()));
create policy "authors and admins edit forum" on sailune_community.community_forum_posts
  for update to authenticated
  using ((author_id = auth.uid() and board <> 'announcements') or sailune_community.is_admin())
  with check ((author_id = auth.uid() and board <> 'announcements') or sailune_community.is_admin());

revoke all on sailune_community.community_templates from public, anon, authenticated;
grant select on sailune_community.community_templates to authenticated;
grant insert (id, owner_id, display_name, name, summary, format_version, payload)
  on sailune_community.community_templates to authenticated;
grant update (hidden) on sailune_community.community_templates to authenticated;
revoke all on sailune_community.community_forum_posts from public, anon, authenticated;
grant select on sailune_community.community_forum_posts to authenticated;
grant insert (id, author_id, display_name, board, title, body)
  on sailune_community.community_forum_posts to authenticated;
grant update (title, body, hidden) on sailune_community.community_forum_posts to authenticated;

create or replace function sailune_community.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists community_templates_updated on sailune_community.community_templates;
drop trigger if exists community_forum_posts_updated on sailune_community.community_forum_posts;
create trigger community_templates_updated before update on sailune_community.community_templates
  for each row execute function sailune_community.touch_updated_at();
create trigger community_forum_posts_updated before update on sailune_community.community_forum_posts
  for each row execute function sailune_community.touch_updated_at();

create or replace function sailune_community.template_insert_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from sailune_community.community_templates
      where owner_id = new.owner_id and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'community_rate_limit';
  end if;
  return new;
end;
$$;
create or replace function sailune_community.forum_insert_limit() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from sailune_community.community_forum_posts
      where author_id = new.author_id and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'community_rate_limit';
  end if;
  return new;
end;
$$;
drop trigger if exists community_templates_rate on sailune_community.community_templates;
drop trigger if exists community_forum_rate on sailune_community.community_forum_posts;
create trigger community_templates_rate before insert on sailune_community.community_templates
  for each row execute function sailune_community.template_insert_limit();
create trigger community_forum_rate before insert on sailune_community.community_forum_posts
  for each row execute function sailune_community.forum_insert_limit();
revoke all on function sailune_community.touch_updated_at() from public, anon, authenticated;
revoke all on function sailune_community.template_insert_limit() from public, anon, authenticated;
revoke all on function sailune_community.forum_insert_limit() from public, anon, authenticated;

-- 部署前在 Supabase API 設定加入 sailune_community 至 Exposed schemas。
-- 首位帆夢管理員只由受控維運 SQL 指派，不由 App 或登入者自行寫入 admins。
