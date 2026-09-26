# 資料模型與關聯

> 依 2026-09-23 現行 schema、store 與 V7.2 多地圖實作整理。

## Store 邊界

| Store | Schema／主要模型 | 連結方式 |
|---|---|---|
| `Sailune-v5.store` | `NovelWriterSchemaV5`：Book、Volume、Section、Character、Ability、Item、Timeline、Node、Event 與舊 Organization 相容型別 | SwiftData relationship；V6.0c 不改此已發布 schema，Book 狀態目前為 transient |
| `Sailune-v5-settings.store` | `V5SettingsSchemaV13`：V12 模型加上 MapPlacement 可空目標地圖 ID | 只以 `bookID` 與穩定 UUID 連結其他 store；地圖與 Place 以 UUID placement 連接；V1～V12 保留為不可變遷移快照 |
| `Sailune-v5-item-copies.store` | ItemCopy、ItemCopyHolding、ItemCopyHistory | `bookID`、`itemID`、`characterID`、`copyID` |
| `Sailune-v5-item-copy-level-selections.store` | ItemCopyLevelSelection | `copyID`、`levelID` |
| `Sailune-v5-ability-progress.store` | AbilityProgressRecord／History | `bookID`、`abilityID`、`characterID`、`nodeID` |
| `Sailune-v5-story-planning.store` | `StoryPlanningSchemaV7`：V6 全部模型加上 PlanningRecordMetadata | `bookID`、`sectionID`、`eventID`、`outlineItemID`、來源種類與來源 UUID 等 |

Book 封面與地圖背景不在 SwiftData，分別存於 Application Support 的 `Sailune/Covers` PNG 與 `Sailune/Maps/<bookID>/<mapID>/<versionID>.pdf`。

## 主關聯

```text
Book
├─ status（連載／完結／草稿；目前 transient，新書與重載預設草稿）
├─ Volume ─ Section（AttributedString 正文）
├─ Character
│  ├─ Alias / Profile / Appearance / Psychology
│  ├─ CharacterAbility / History
│  ├─ CharacterItem / History
│  └─ Relationship / Kinship / History
├─ Item ─ ItemLevel / ItemHistory
└─ Timeline ─ Node ─ Event
                 └─ Character 關聯與可選 Section 來源

PowerLevel（bookID、由高至低 sortOrder）
└─ PowerUnit（bookID、levelID → PowerLevel、名稱／舊名／外文名／簡稱、簡介、高層管理員、其他名單、勢力關係、政治、宗教、核心／範圍欄位）
   └─ PowerSubordination：lowerPowerID → upperPowerID（只保存直接隸屬）
   └─ PowerRelation：sourcePowerID ↔／→ targetPowerID（對稱關係或宗主→附庸；不含時間序）
   ├─ PowerAssetLink：資源／技術 WorldTerm 或主 store 物品／能力的 UUID 連接
   ├─ PowerAdvantage：軍事／經濟優勢的作者命名與說明
   ├─ PowerLifecycleEvent／PowerSuccessionLink：生命週期與前身→後繼（可選 nodeID）
   └─ PowerMember ─ PowerMemberRole：加入／離開、多重職務、領導與任職狀態（可選 nodeID）

BookSidebarSetting（bookID）→ 顯示項目、可見性、排序、側邊欄目錄版本
Place（bookID）→ 名稱、其他名稱、類型、簡介、詳細描述、備註、排序、可選 coordinateX／coordinateY
BookMap（bookID、平面 level、名稱、排序）
├─ BookMapVersion（mapID、名稱、排序）→ 對應獨立 PDF 背景
└─ MapPlacement（mapID、placeID、X、Y、可空 targetMapID）→ 同一 Place 可跨地圖使用不同座標；每個來源標記可指向下一層級地圖
WorldTerm（bookID）→ 名稱、其他名稱、分類、簡介、核心定義、運作與表現、限制／差異／例外、世界影響、使用範例、備註、排序
```

## 故事規劃關聯

```text
BookPlanningProfile ─ bookID
StoryTag ─ bookID + sectionID + 文字錨點
ChapterAnnotation ─ bookID + sectionID
OutlineStoryLine ─ OutlineStage ─ OutlineItem
                              ├─ OutlineItemAnchor（正文來源，最多一筆）
                              └─ OutlineItemPlacement（手動安置，最多一筆）
OutlineStage ─ OutlineStageStartAnchor + OutlineStageStartDetail
TimelineEventCardMetadata ─ eventID + 可選 outlineItemID
```

## 重要不變條件

- UUID 是跨 store、遷移與回填的穩定識別；`sortOrder` 只負責同父層顯示順序。
- V7.2 每張具體地圖都是固定 `4000 × 3000`；MapPlacement 的 X／Y 合法時才顯示。背景版本只是替代 PDF，切換或移除不改 placement。Place 舊座標只作 V11 遷移來源。
- 同一本書最多一條主線；主線可有多個階段。階段只屬主線。
- 一筆大綱項目最多一個正文來源；手動項目可沒有來源。
- 只有有正文來源的大綱項目可呈現「已完成」；手動項目使用背景、草稿或預定。
- 伏筆／修改標籤和大綱來源都以原文加 UTF-16 offset 解析最近候選，但失效結果不同：標籤刪除；大綱保留、退到原節開頭並轉草稿。
- 手動大綱安置可為待安置、階段首、某項目後或階段末。目標失效時保留內容並回待安置，不猜新位置。
- StoryPlanning V6 的 event metadata 只補充主 store Event；它不擁有事件。刪除 OutlineItem 不刪 Event，缺來源時卡片顯示來源失效。
- StoryPlanning V7 的 `PlanningRecordMetadata` 只保存每筆設定時間序的故事線與可選階段；標題、摘要、世界日期和節次仍以原始來源及 Node 為唯一來源。同一 Node 可供多筆來源共用，不承擔故事線歸屬。
- 物品副本是共用 Item 的獨立實例；副本目前等級不改寫父 Item 定義。
- V5.0 第一版只保存目前勢力與直接隸屬，不建立角色／勢力、物品／勢力或正文／勢力關聯；舊 Organization 資料啟動時清除。後續 V5.2 以 `PowerMember` 連接同書角色，V5.4 以 `PowerAssetLink` 連接資源、技術、物品與能力，V5.5 再加入生命週期、承接及成員／職務時間定位；正文仍沒有勢力穩定連結。
- 每本書首次建立設定配置時預設兩個可改名層級「層級 1／層級 2」；勢力先指定層級才可建立隸屬。下級層級的 `sortOrder` 必須大於上級，允許跨級、多上級與多下級。
- 高層管理員、其他名單、政治與宗教自由文字是 V5.0 的相容欄位；後續版本另以成員、世界條目與結構化關係提供可查詢資料，既有文字不解析、不覆蓋。V5.6 的非隸屬關係也保留原 `relationshipNotes` 作補充筆記。
- 勢力目前只有宗教／政體兩個 WorldTerm 連接，並分別限制為「信仰」／「制度」分類；核心與範圍是未來的地點／地圖連接概念，既有 UUID 欄位暫保相容性。
- 勢力改層或層級重新排序若會使既有連線反向或同級，整項操作失敗並保留原層級、原順序與全部連線。
- 設定集隱藏只改變導航，不刪除設定資料；V5.2.1 預設顯示角色、勢力、世界條目、物品、能力、標籤，地點可選加入。V5→V6 以每書目錄版本只顯示世界條目一次，作者後續隱藏不會被覆蓋。
- V5.1 階段 A 將地點與世界條目補強為獨立純文字設定頁；地點類型維持自由文字，世界條目分類由 UI 限定為制度、信仰、技術、資源、族群／種族、文化習俗、專有名詞，語言不再是新建分類。其他名稱、類型／分類、詳細內容、使用範例與備註不與其他 store 建立關聯。`WorldTerm.termCategory` 維持可空 `String` 以保留 V3→V4 舊分類（包括退役的「語言」字串），未對應值只在作者選擇新分類後替換。族群／種族預設以固定 ID 映射到既有文字欄位，不新增 schema 或 migration。
- V5.2.2 仍以原 `detailedDescription` 保存核心定義，另以三個可空字串保存運作與表現、限制／差異／例外及世界影響。分類只決定編輯提示，不寫入或搬移作者內容；V6→V7 遷移後舊條目的三個新欄位為空。
- V5.3 的八套政體定義由程式內 `GovernmentPreset` 提供。作者新增 WorldTerm、選擇「制度」並套用後，固定內容保存於既有 WorldTerm 欄位；勢力仍以 `governmentWorldTermID` 連接同書條目，不新增 schema。完整匹配內建內容的條目以唯讀畫面呈現。

## 刪除語意

- `PersistentModelDeletion` 明確解除 Node／Event 與角色歷史、設定歷史或 Section 的引用，再刪除 Book、Character、Item、Event、Node、Era、Timeline、Section 或 Volume。
- `CrossStoreDeletionCoordinator` 對 Book、Event、Node、Era、Timeline 採「先保存主 store，再清理 StoryPlanning」；附屬清理失敗可稍後冪等重試。
- V6.4 刪除 Era 時，限按目前 Book 的所有 Timeline 找出仍關聯的 Node，沿用 Node 刪除語意並在同一次主 store save 刪除這些 Node 與 Era；Node 的 Event 隨之刪除。歷史來源保留但解除 Node 定位，StoryPlanning metadata、ItemCopy、AbilityProgress 與 V5 settings 的失效 Node UUID 在主 store 保存後清理，失敗可由既有修復重試。每本書的 Era／Timeline／設定獨立，不存在跨書共享；被刪 Era 的 `Book.currentEra` 依 nullify 解除。
- 刪除勢力會刪除以它為端點的直接隸屬；已被勢力使用的層級不可刪除。刪除書籍時會一併刪除該書的層級與 settings 資料。
- 刪除具體地圖會刪除其版本與 placement，但保留 Place；刪除 Place 會清除所有地圖中的對應 placement。刪除版本不影響 placement。
- 啟動與時間軸載入會按現存 Book／Event UUID 清除孤立規劃資料；缺 OutlineItem 不會使 Event 或 metadata 被刪除。
- 現行 UI 仍有 Volume／Section 與角色事件直接刪除入口，未完整套用上述集中語意；詳見 `consistency-audit.md`。

## 模型風險

- 六個 store 無共同 transaction，任何新增跨域關係都要定義保存順序、失敗狀態、修復與測試。
- 伏筆目前沒有回收狀態或回收來源，不能從既有 StoryTag 推導「未回收」。
- 物品正文引用是名稱掃描；重新命名或同名物品無穩定識別保證。
- 備份必須同時包含六個 store、封面與地圖 PDF，不能只複製主 store。

## V10.1 書籍發布狀態

`Book.status` 仍是 V5 主 store 的暫存欄位，發布流程不以它作持久來源。`BookPublicationStore` 以書籍 UUID 為鍵，保存於獨立 `Sailune/Publication Status.json`；缺少紀錄即草稿，狀態只可依序進入發布中、完結。此路徑避免直接修改已發布的 V5 schema；未來若改存主 store，仍須完整 schema 遷移。
