# V12.1 帆夢社群服務部署與驗收

> 2026-10-06。帆夢與拾頁共用 Supabase 專案與 Auth；社群資料由 `sailune_community` 管理。SQL 原稿：`../supabase/migrations/20261005000000_sailune_community.sql`；共用專案 migration 序列的部署副本：拾頁 `supabase/migrations/20261005000000_sailune_community.sql`。正式專案已透過 SQL Editor 手動套用；沒有 CLI migration ledger。兩份 SQL SHA-256 已核對相同。

## 1. 唯讀核對正式環境

用受控的 Supabase SQL Editor 查表及 migration 狀態；只看結構與筆數，不讀作者內容：

```sql
select to_regclass('public.community_templates') as old_templates,
       to_regclass('public.community_forum_posts') as old_forum,
       to_regclass('sailune_community.community_templates') as new_templates,
       to_regclass('sailune_community.community_forum_posts') as new_forum;

select version from supabase_migrations.schema_migrations
where version in ('20261003010000', '20261004000000', '20261005000000')
order by version;
```

2026-10-06 正式專案唯讀預檢：SQL Editor 專案 ref 與拾頁 `.env.local` 的 Supabase URL 相同；四個 `to_regclass` 都是 `NULL`。`supabase_migrations.schema_migrations` 不存在，但拾頁 `public.books`、`public.authors`、`public.site_admins` 與 `public.admin_site_daily_views(integer)` 已存在，表示既有正式結構不受 Supabase CLI migration ledger 追蹤。這次不得直接 `db push`。若由 SQL Editor 單獨套用本次已審核 SQL，須明記它是手動部署，未寫入 migration ledger，日後建立統一 ledger 前先盤點既有拾頁遷移。

若任一舊表或新表存在，先記錄兩邊筆數及 schema 狀態；若舊與新同名表都存在，新 migration 會故意拒絕執行，須先人工核對來源與目的資料。2026-10-05 以 publishable key 對正式 PostgREST 做 `select=id&limit=0`：兩張舊表回 `PGRST205`，新 schema 回 `PGRST106`；這只證明當時 API 未提供兩者，不是資料庫目錄或 migration 紀錄的直接查詢。

## 2. 部署資料庫

先確認同一 Supabase 專案待套用的 **全部** migration，避免順帶部署未驗收的拾頁功能。正式專案目前沒有 CLI migration ledger；本次應在 SQL Editor 將 `20261005000000_sailune_community.sql` 單獨以一個交易執行，並記錄驗證結果。不能由帆夢與拾頁兩個 repo 各自對同一專案執行 `db push`。若舊 `public` 社群表存在，本次遷移將全部列複製到新 schema，核對筆數，保留舊表但撤銷 `authenticated` 寫入；舊版 App 暫時只能讀舊表。資料若不符合新版限制或複製筆數不符，遷移應失敗並保留原資料，不手動刪表處理。

在 Supabase Data API 的 **Exposed schemas** 加入 `sailune_community`，保留既有 schema；再於 **Exposed tables** 只選 `sailune_community.community_templates`、`sailune_community.community_forum_posts`，**Exposed functions** 只選 `sailune_community.is_admin`。不要選 `admins` 表。新 schema 未加入 exposed 清單時，App 會得到 `PGRST106`，無法載入共享內容。

2026-10-06 正式操作發現 Data API 畫面的 Exposed tables 開關會另外授予 `anon` SELECT 與 `authenticated` DELETE 等過大資料庫權限。存檔後必須立刻在 SQL Editor 執行下列收斂 SQL；不要只憑開關或 RLS 判斷安全。已於正式專案執行並驗得匿名 schema／表／RPC 權限、登入者 DELETE 與 `admins` SELECT 全為 false，登入者必要 SELECT、指定欄位 INSERT 與 RPC EXECUTE 全為 true。

```sql
begin;
revoke all on sailune_community.community_templates from public, anon, authenticated, service_role;
grant select on sailune_community.community_templates to authenticated;
grant insert (id, owner_id, display_name, name, summary, format_version, payload)
  on sailune_community.community_templates to authenticated;
grant update (hidden) on sailune_community.community_templates to authenticated;
revoke all on sailune_community.community_forum_posts from public, anon, authenticated, service_role;
grant select on sailune_community.community_forum_posts to authenticated;
grant insert (id, author_id, display_name, board, title, body)
  on sailune_community.community_forum_posts to authenticated;
grant update (title, body, hidden) on sailune_community.community_forum_posts to authenticated;
revoke all on function sailune_community.is_admin() from public, anon, authenticated, service_role;
grant execute on function sailune_community.is_admin() to authenticated;
commit;
```

## 3. 指派帆夢公告管理員

由使用者指定現有登入帳號，維運者唯讀查 `auth.users` 確認 UUID；不以拾頁 `site_admins` 自動複製。核對後才由受控 SQL 執行：

```sql
insert into sailune_community.admins (user_id)
values ('<已核對的 auth.users.id>')
on conflict (user_id) do nothing;
```

App、publishable key 與一般登入者不得持有這張表的寫入權限。`public.is_admin()` 仍只用於拾頁網站後台。

2026-10-06 已由 SQL Editor 以先前唯讀核對的 UUID 指派使用者指定帳號；再以 `auth.users` 關聯做布林核對，指定 Email 命中、`admins` 恰有 1 筆。Email 與 UUID 不放進 repo 的 SQL 範本。

## 4. 驗收與切換

先在資料庫核對新表筆數、RLS、schema 授權及兩種管理員判斷；再讓兩個不同帳號使用兩套帆夢安裝對同一服務測試：A 發表一般文章與公開模板，B 能讀取與套用但不能修改；取消公開後 B 用舊 ID 不可讀；拾頁站長不能發帆夢公告，帆夢管理員可以；匿名不能讀寫；Guest 仍可建立書籍、寫正文與編輯設定。網路錯誤重試不得生成重複文章／模板。

2026-10-06 已驗：三表 `relrowsecurity=true`；兩張內容表各 3 條 RLS policy；模板及論壇初始筆數均為 0。正式匿名 PostgREST 對兩表及 `is_admin` RPC 均回 HTTP 401／`42501`，不再是 schema 未暴露的 `PGRST106`。Data API 設定已儲存為 3/3 schema、6/14 表、11/42 函式暴露；額外授權已收回並以 `has_*_privilege` 唯讀核對。這不等於已登入 App 或兩帳號跨安裝成功；這些仍須實測。

確認新版 App 已接 `sailune_community` 且跨安裝驗收成功後，再另外規劃舊 `public.community_*` 表退役。舊表在此之前保留，不直接刪除；本機模板、舊論壇 JSON 與備份不因部署而搬移或上傳。
