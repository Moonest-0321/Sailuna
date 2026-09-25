#!/usr/bin/env python3
"""Freeze V9 source findings from the current worktree; run only for a new approved baseline."""

from __future__ import annotations

import csv
import hashlib
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SOURCE_DIRS = (ROOT / "Sailune", ROOT / "SailuneTests")

# Each regex match is one inventory row. These are frozen V9 families, not a
# promise that every native framework call should become a custom component.
RULES = {
    "button": re.compile(r"\b(?:SailuneIconButton|Button)\s*\("),
    "button_style": re.compile(r"\.buttonStyle\s*\("),
    "field": re.compile(r"\b(?:TextField|SailuneFormTextField|SailuneSearchField|CompositionAwareTextField)\s*\("),
    "editor": re.compile(r"\b(?:TextEditor|InsetTextEditor|SailuneBorderedTextEditor)\s*\("),
    "surface": re.compile(r"\.background\s*\(|\bColor\.secondary\.opacity\s*\(|\bSailuneTheme\."),
    "symbol": re.compile(r"\b(?:systemName|systemImage)\s*:\s*\"[^\"]*\"|\bSailuneSymbol\.\w+"),
    "copy": re.compile(r"\bSailuneActionCopy\.\w+|\b(?:Button|Label|Menu|Text)\s*\(\s*\""),
    "accessibility": re.compile(r"\.(?:help|accessibilityLabel|accessibilityHint)\s*\("),
    "dialog": re.compile(r"\.(?:alert|confirmationDialog|sheet)\s*\("),
    "failure_path": re.compile(r"\btry\?|\bcatch\b"),
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def classify(category: str, match: str, source: str, path: str) -> tuple[str, str]:
    in_tests = path.startswith("SailuneTests/")
    in_shared = path.startswith("Sailune/SharedUI/")
    if in_tests:
        return ("合理例外", "測試專用呼叫；不屬正式 UI 共用接線，測試清理與解析結果仍需保留測試語意。")
    if category == "button":
        if match.startswith("SailuneIconButton") or in_shared:
            return ("已共用", "直接引用或定義共用按鈕元件；實際命中仍依代表畫面驗收。")
        return ("待共用", "原生 Button；須按動作角色、位置、命中與資料 action 判定共用外殼或具名例外。")
    if category == "button_style":
        if "PlanningActionStyle" in source or in_shared:
            return ("已共用", "引用或定義既有共用 ButtonStyle。")
        return ("待共用", "原生樣式；需與同語意按鈕比對，不能只按 style 名稱批量替換。")
    if category == "field":
        if match.startswith(("SailuneFormTextField", "SailuneSearchField")) or in_shared:
            return ("已共用", "引用或定義共用欄位；焦點、組字及內距仍需代表畫面驗收。")
        if match.startswith("CompositionAwareTextField"):
            return ("合理例外", "角色名稱專用 AppKit 組字欄；有獨立組字及焦點契約。")
        return ("待共用", "原生欄位；需檢查數值、焦點、提交與多行等專用契約。")
    if category == "editor":
        if match.startswith(("InsetTextEditor", "SailuneBorderedTextEditor")) or in_shared:
            return ("已共用", "引用或定義共用多行編輯器；V9.1am 首行安全距仍待 U 核定。")
        return ("待共用", "原生多行編輯器；需核對 placeholder、內距、背景、組字與 Undo。")
    if category == "surface":
        if match.startswith("SailuneTheme.") or in_shared:
            return ("已共用", "引用或定義語意色彩 token；形狀與疊層仍需檢查。")
        return ("待共用", "直接背景或色值；需判定表面用途與既有 token 是否相同。")
    if category == "symbol":
        if match.startswith("SailuneSymbol.") or in_shared:
            return ("已共用", "使用或定義語意圖標 key；原字形由集中表提供。")
        return ("待共用", "直接 SF Symbol 字串；須依實際操作或資料語意分類。")
    if category == "copy":
        if match.startswith("SailuneActionCopy.") or in_shared:
            return ("已共用", "使用或定義集中操作文案。")
        if match.startswith("Text("):
            return ("合理例外", "靜態欄名或領域內容；非可執行操作文案，保留畫面語境。")
        return ("待共用", "直接 Button／Label／Menu 文案；需與同功能操作名稱及例外對照。")
    if category == "accessibility":
        if "SailuneActionCopy." in source or "SailuneIconButton" in source or in_shared:
            return ("已共用", "描述由共用文案或按鈕元件提供；仍需 VoiceOver 驗收。")
        return ("待共用", "直接提示或輔助描述；需核對同操作名稱及可點擊對象。")
    if category == "dialog":
        return ("待共用", "原生呈現入口；需按確認、錯誤、取消及資料後果分組，僅呈現外殼可共用。")
    if category == "failure_path":
        if match == "try?" and "Task.sleep" in source:
            return ("合理例外", "短暫提示的可取消延遲；取消不影響資料操作。")
        if match == "try?" and "removeItem" in source and path.startswith("Sailune/SailuneBackupService"):
            return ("待共用", "備份／還原清理失敗政策待決；不得以靜態命中數取代復位證據。")
        return ("待共用", "失敗分支或可選錯誤；需核對主要結果、次要錯誤記錄與恢復契約。")
    raise AssertionError(category)


def main() -> None:
    source_files = sorted(p for d in SOURCE_DIRS for p in d.rglob("*.swift"))
    manifest_rows = []
    finding_rows = []
    module_rows = []
    for path in source_files:
        rel = path.relative_to(ROOT).as_posix()
        data = path.read_bytes()
        digest = sha256(data)
        lines = data.decode("utf-8").splitlines()
        manifest_rows.append((rel, digest, len(lines), len(data)))
        declarations = []
        declaration_pattern = re.compile(r"^(?:@\w+\s+)*(?:(?:private|fileprivate|public|internal|open|final|indirect)\s+)*(?:struct|class|enum|actor|protocol|extension)\s+([A-Za-z_][A-Za-z0-9_]*)")
        for line in lines:
            found = declaration_pattern.match(line)
            if found:
                declarations.append(found.group(1))
        if rel.startswith("SailuneTests/"):
            module_status = "合理例外"
            module_reason = "獨立測試目標；保留測試資料／隔離清理責任，不以正式 UI 元件規則機械替換。"
        elif rel.startswith("Sailune/SharedUI/"):
            module_status = "已共用"
            module_reason = "共用 UI foundation；責任與公開呼叫點由本檔集中提供。"
        elif len(lines) >= 900:
            module_status = "待共用"
            module_reason = "大型領域檔；須逐宣告確認責任邊界、資料依賴與安全拆分，不以行數直接判定可搬移。"
        else:
            module_status = "合理例外"
            module_reason = "具名領域檔；暫保留領域責任，需與逐項清單核對是否有重複操作外殼。"
        module_rows.append((rel, digest, len(lines), " | ".join(declarations), module_status, module_reason))
        for line_number, source in enumerate(lines, 1):
            for category, pattern in RULES.items():
                for hit in pattern.finditer(source):
                    match = hit.group()
                    status, reason = classify(category, match, source, rel)
                    finding_rows.append((category, rel, line_number, hit.start() + 1, match, status, reason, source.strip(), digest))

    finding_rows.sort(key=lambda r: (r[1], r[2], r[3], r[0]))
    with (OUT / "baseline-files.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(("file", "sha256", "lines", "bytes"))
        writer.writerows(manifest_rows)
    with (OUT / "callsite-inventory.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(("id", "family", "file", "line", "column", "match", "status", "evidence_or_reason", "source_line", "file_sha256"))
        for index, row in enumerate(finding_rows, 1):
            writer.writerow((f"V9-{index:04d}", *row))
    with (OUT / "module-inventory.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(("file", "sha256", "lines", "top_level_declarations", "status", "evidence_or_reason"))
        writer.writerows(module_rows)

    counts = Counter((row[0], row[5]) for row in finding_rows)
    print(f"files={len(source_files)} findings={len(finding_rows)}")
    for (family, status), count in sorted(counts.items()):
        print(f"{family},{status},{count}")


if __name__ == "__main__":
    main()
