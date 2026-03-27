import argparse
import json
import os
from typing import Any, Dict, List, Optional

import AddressablesTools as AT
import UnityPy
import UnityPy.config as UnityPyConfig

from extract_item_images_from_game import DEFAULT_BUILD_ID


OCTOPUS_ITEM_ID = "82d41afc-d1a9-41ee-a03d-fd9305bef8b5"
REMOTE_BASE = "https://data.playthebazaar.com/bundles/windows-standalone/"


def normalize_cards_version(cards_json: Dict[str, Any]) -> List[Dict[str, Any]]:
    key = next(k for k, v in cards_json.items() if isinstance(v, list))
    return cards_json[key]


def load_build_context(build_dir: str) -> Dict[str, Any]:
    cards = json.load(open(os.path.join(build_dir, "cards.json"), "r", encoding="utf-8"))
    items = normalize_cards_version(cards)
    by_id = {c.get("Id"): c for c in items if isinstance(c, dict) and isinstance(c.get("Id"), str)}
    cat = AT.parse_binary(open(os.path.join(build_dir, "catalog.bin"), "rb").read())
    return {"by_id": by_id, "cat": cat}


def main() -> None:
    parser = argparse.ArgumentParser(description="Trace Octopus CardData->Material->_MainTex.")
    parser.add_argument("--buildId", default=DEFAULT_BUILD_ID)
    parser.add_argument(
        "--scanLogPath",
        default=None,
        help="Optional path to pathID scan output text for summary extraction.",
    )
    parser.add_argument(
        "--skipCorpusPathIdCheck",
        action="store_true",
        help="Skip expensive UnityPy.load(downloaded_bundles) corpus scan.",
    )
    args = parser.parse_args()

    UnityPyConfig.FALLBACK_UNITY_VERSION = "2020.3.48f1"

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    build_dir = os.path.join(repo_root, ".cache", "game-builds", args.buildId)
    ctx = load_build_context(build_dir)
    by_id = ctx["by_id"]
    cat = ctx["cat"]

    report: Dict[str, Any] = {
        "itemId": OCTOPUS_ITEM_ID,
        "buildId": args.buildId,
        "steps": [],
        "finalAssessment": {},
        "confidence": "medium",
    }

    item = by_id.get(OCTOPUS_ITEM_ID)
    if not item:
        report["finalAssessment"] = {"status": "error", "reason": "octopus item missing in cards.json"}
        out = os.path.join(build_dir, "octopus_trace_report.json")
        json.dump(report, open(out, "w", encoding="utf-8"), indent=2)
        print(out)
        return

    art_key = item.get("ArtKey")
    report["steps"].append(
        {
            "name": "item_record",
            "result": "ok",
            "itemInternalName": item.get("InternalName"),
            "artKey": art_key,
            "hero": (item.get("Heroes") or [""])[0] if isinstance(item.get("Heroes"), list) else "",
            "size": item.get("Size"),
        }
    )

    rl_list = cat.Resources.get(art_key, [])
    if not rl_list:
        report["finalAssessment"] = {"status": "error", "reason": "art key missing in catalog resources"}
        out = os.path.join(build_dir, "octopus_trace_report.json")
        json.dump(report, open(out, "w", encoding="utf-8"), indent=2)
        print(out)
        return

    card_data_iid = None
    for rl in rl_list:
        iid = getattr(rl, "InternalId", None)
        if isinstance(iid, str) and iid.endswith("_CardData.asset"):
            card_data_iid = iid
            break
    if not card_data_iid:
        card_data_iid = getattr(rl_list[0], "InternalId", None)

    rl = next((r for r in rl_list if getattr(r, "InternalId", None) == card_data_iid), rl_list[0])
    deps = getattr(rl, "Dependencies", []) or []
    dep_bundle_urls = []
    for d in deps:
        iid = getattr(d, "InternalId", None)
        if isinstance(iid, str) and iid.startswith(REMOTE_BASE) and iid.endswith(".bundle"):
            dep_bundle_urls.append(iid)
    seen = set()
    dep_bundle_urls = [u for u in dep_bundle_urls if not (u in seen or seen.add(u))]

    report["steps"].append(
        {
            "name": "catalog_rl",
            "result": "ok",
            "cardDataInternalId": card_data_iid,
            "dependencyBundleCount": len(dep_bundle_urls),
        }
    )

    # Load the primary card bundle for this item.
    card_bundle_name = dep_bundle_urls[0].split("/")[-1] if dep_bundle_urls else ""
    card_bundle_path = os.path.join(build_dir, "downloaded_bundles", card_bundle_name)
    env = UnityPy.load(card_bundle_path)

    mat_obj = None
    card_data_obj = None
    for obj in env.objects:
        t = obj.type.name
        try:
            n = obj.peek_name()
        except Exception:
            n = ""
        if t == "Material" and n == "CF_M_VAN_Octopus":
            mat_obj = obj
        if t == "MonoBehaviour" and n == "Octopus_CardData":
            card_data_obj = obj

    report["steps"].append(
        {
            "name": "card_bundle_objects",
            "result": "ok" if mat_obj and card_data_obj else "partial",
            "cardBundle": card_bundle_name,
            "materialFound": bool(mat_obj),
            "cardDataFound": bool(card_data_obj),
        }
    )

    main_tex_ref: Optional[Dict[str, int]] = None
    external_path = None
    if mat_obj is not None:
        tt = mat_obj.read_typetree()
        for k, v in tt.get("m_SavedProperties", {}).get("m_TexEnvs", []):
            if k == "_MainTex":
                main_tex_ref = v.get("m_Texture")
                break
        if main_tex_ref:
            af = mat_obj.assets_file
            exts = getattr(af, "externals", []) or []
            file_id = int(main_tex_ref.get("m_FileID", 0))
            if file_id > 0 and file_id - 1 < len(exts):
                ext = exts[file_id - 1]
                external_path = getattr(ext, "path", None)

    report["steps"].append(
        {
            "name": "material_maintex_ref",
            "result": "ok" if main_tex_ref else "missing",
            "mainTexRef": main_tex_ref,
            "externalPath": external_path,
        }
    )

    # Check whether target pathId exists in downloaded bundle corpus.
    target_path_id = int(main_tex_ref.get("m_PathID", 0)) if main_tex_ref else None
    found_any = []
    if target_path_id and not args.skipCorpusPathIdCheck:
        folder_env = UnityPy.load(os.path.join(build_dir, "downloaded_bundles"))
        for obj in folder_env.objects:
            if obj.path_id != target_path_id:
                continue
            try:
                pn = obj.peek_name()
            except Exception:
                pn = ""
            found_any.append({"type": obj.type.name, "name": pn})

    report["steps"].append(
        {
            "name": "pathid_resolution_in_downloaded_bundles",
            "result": "found" if found_any else ("skipped" if args.skipCorpusPathIdCheck else "not_found"),
            "targetPathId": target_path_id,
            "matches": found_any,
        }
    )

    # Parse optional scan log summary.
    scan_summary = {}
    if args.scanLogPath and os.path.exists(args.scanLogPath):
        lines = open(args.scanLogPath, "r", encoding="utf-8", errors="ignore").read().splitlines()
        last_progress = [ln for ln in lines if ln.startswith("progress idx=")]
        not_found = [ln for ln in lines if ln.startswith("NOT_FOUND")]
        stats = [ln for ln in lines if ln.startswith("pathId=")]
        scan_summary = {
            "lastProgress": last_progress[-1] if last_progress else "",
            "notFoundMarker": bool(not_found),
            "finalStats": stats[-1] if stats else "",
        }
    pathid_scan_found_path = os.path.join(build_dir, "pathid_scan_found.json")
    pathid_scan_found = None
    if os.path.exists(pathid_scan_found_path):
        pathid_scan_found = json.load(open(pathid_scan_found_path, "r", encoding="utf-8"))

    report["steps"].append(
        {
            "name": "bruteforce_scan_summary",
            "result": "ok" if scan_summary else "missing",
            "scanSummary": scan_summary,
            "pathIdFoundFile": pathid_scan_found,
        }
    )

    found_by_scan = bool(pathid_scan_found and pathid_scan_found.get("found") is True)
    found_by_local_check = bool(found_any)
    if target_path_id and not found_by_scan and not found_by_local_check:
        report["finalAssessment"] = {
            "status": "unresolved_external_reference",
            "reason": (
                "Octopus material _MainTex points to an external CAB/pathId not present "
                "in currently addressable/downloaded bundle corpus."
            ),
            "recommendation": (
                "Use controlled fallback (no image) to avoid wrong monster art until upstream "
                "asset pointer resolves."
            ),
        }
        report["confidence"] = "high"
    else:
        report["finalAssessment"] = {
            "status": "resolved_or_partially_resolved",
            "reason": "Target pathId became resolvable in local corpus.",
        }

    out = os.path.join(build_dir, "octopus_trace_report.json")
    json.dump(report, open(out, "w", encoding="utf-8"), indent=2)
    print(out)


if __name__ == "__main__":
    main()

