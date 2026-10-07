-- V12.1：模板世界觀 metadata。已部署的社群表只以前向方式擴充。
begin;

alter table sailune_community.community_templates
  add column if not exists worldview_categories text[] not null default '{}';

create or replace function sailune_community.template_worldview_categories_valid(categories text[])
returns boolean language sql immutable set search_path = '' as $$
  select categories is not null
    and array_position(categories, null) is null
    and categories <@ array[
      'reality', 'alternate_history', 'fantasy', 'science_fiction',
      'mythology', 'post_apocalyptic', 'other'
    ]::text[]
    and cardinality(categories) = (select count(distinct category) from unnest(categories) as category);
$$;
revoke all on function sailune_community.template_worldview_categories_valid(text[])
  from public, anon, authenticated;
grant execute on function sailune_community.template_worldview_categories_valid(text[]) to authenticated;

alter table sailune_community.community_templates
  drop constraint if exists community_templates_worldview_categories_check;
alter table sailune_community.community_templates
  add constraint community_templates_worldview_categories_check
  check (sailune_community.template_worldview_categories_valid(worldview_categories));

create index if not exists community_templates_visible_worldview_categories
  on sailune_community.community_templates using gin (worldview_categories)
  where not hidden;

grant insert (worldview_categories) on sailune_community.community_templates to authenticated;
grant update (worldview_categories) on sailune_community.community_templates to authenticated;

-- 既有 UPDATE policy 允許管理員隱藏；分類 metadata 只能由原作者改動。
create or replace function sailune_community.protect_template_worldview_categories()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.worldview_categories is distinct from old.worldview_categories
     and old.owner_id is distinct from auth.uid() then
    raise exception 'only template owner may change worldview categories' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function sailune_community.protect_template_worldview_categories()
  from public, anon, authenticated;
drop trigger if exists community_templates_protect_worldview_categories
  on sailune_community.community_templates;
create trigger community_templates_protect_worldview_categories
  before update on sailune_community.community_templates
  for each row execute function sailune_community.protect_template_worldview_categories();

commit;
