#!/usr/bin/env python3
"""Validate immutable V9 inventory coverage and report remaining decisions."""
from __future__ import annotations

import argparse
import csv
import hashlib
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SNAPSHOT_HASHES = {
    "baseline-files.csv": "39f68ec7326866e669a15be0b1025ccfc7ff03360b4e7445635068437a3b5e0e",
    "callsite-inventory.csv": "58b0ba50fc104d9e6a96c444cc325197476e88e451822d4c71e3b89195d8f18f",
    "module-inventory.csv": "b3299d867ded18ab72dee07151e6553c123b77de97aa249cac679fba8cc08b8f",
}
STATES = {"已共用", "待共用", "合理例外"}


def rows(name: str) -> list[dict[str, str]]:
    with (HERE / name).open(newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def unique_index(items: list[dict[str, str]], key: str) -> dict[str, dict[str, str]]:
    result = {item[key]: item for item in items}
    assert len(result) == len(items), f"duplicate {key}"
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-frozen", action="store_true", help="also require source files to equal the original snapshot")
    parser.add_argument("--final", action="store_true", help="fail while any disposition or verification remains pending")
    args = parser.parse_args()
    for filename, expected in SNAPSHOT_HASHES.items():
        actual = hashlib.sha256((HERE / filename).read_bytes()).hexdigest()
        assert actual == expected, f"immutable snapshot changed: {filename}"

    baseline = unique_index(rows("baseline-files.csv"), "file")
    calls = unique_index(rows("callsite-inventory.csv"), "id")
    modules = unique_index(rows("module-inventory.csv"), "file")
    ledger = unique_index(rows("resolution-ledger.csv"), "id")
    module_ledger = unique_index(rows("module-resolution-ledger.csv"), "file")
    assert len(baseline) == len(modules) == len(module_ledger) == 93
    assert len(calls) == len(ledger) == 2256
    assert set(calls) == set(ledger)
    assert set(baseline) == set(modules) == set(module_ledger)
    for item in calls.values():
        assert item["file"] in baseline
        assert item["file_sha256"] == baseline[item["file"]]["sha256"]
        review = ledger[item["id"]]
        assert review["reviewed_status"] in STATES
        assert all(review[k].strip() for k in ("evidence_and_disposition", "work_item", "verification_state"))
    for path, item in modules.items():
        assert item["sha256"] == baseline[path]["sha256"] == module_ledger[path]["sha256"]
        review = module_ledger[path]
        assert review["reviewed_status"] in STATES
        assert all(review[k].strip() for k in ("evidence_and_reason", "disposition", "verification_state"))
    if args.source_frozen:
        for path, item in baseline.items():
            actual = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            assert actual == item["sha256"], f"source changed since freeze: {path}"
    call_counts = Counter(item["reviewed_status"] for item in ledger.values())
    module_counts = Counter(item["reviewed_status"] for item in module_ledger.values())
    print("callsites", len(calls), dict(call_counts))
    print("modules", len(modules), dict(module_counts))
    if args.source_frozen:
        print("source files match frozen SHA-256", len(baseline))
    if args.final:
        assert call_counts["待共用"] == module_counts["待共用"] == 0, "undecided dispositions remain"
        assert all("待" not in item["verification_state"] for item in ledger.values()), "callsite verification remains pending"
        assert all("待" not in item["verification_state"] for item in module_ledger.values()), "module verification remains pending"


if __name__ == "__main__":
    main()
