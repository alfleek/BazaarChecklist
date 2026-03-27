import argparse
import json
import os
import re
import urllib.request
from typing import Dict, List, Optional, Tuple

import AddressablesTools as AT
import UnityPy
import UnityPy.config as UnityPyConfig
from PIL import Image

from extract_item_images_from_game import DEFAULT_BUILD_ID


REMOTE_BASE = "https://data.playthebazaar.com/bundles/windows-standalone/"


def ensure_dir(p: str) -> None:
    os.makedirs(p, exist_ok=True)


def download_file(url: str, out_path: str) -> None:
    ensure_dir(os.path.dirname(out_path))
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36"
            ),
            "Accept": "*/*",
        },
        method="GET",
    )
    with urllib.request.urlopen(req) as resp, open(out_path, "wb") as f:
        while True:
            chunk = resp.read(1024 * 1024)
            if not chunk:
                break
            f.write(chunk)


def output_size_for_item(size_label: str, max_height_px: int) -> Tuple[int, int]:
    s = (size_label or "").strip().lower()
    slot_count = 2
    if s == "small":
        slot_count = 1
    elif s == "medium":
        slot_count = 2
    elif s == "large":
        slot_count = 3
    height = max(1, int(max_height_px))
    width = max(1, int(round(height * (slot_count / 2))))
    return width, height


def export_obj_image(obj: object, out_path: str, out_size: Tuple[int, int]) -> bool:
    try:
        data = obj.read()
        if not hasattr(data, "image"):
            return False
        img = data.image
        if not isinstance(img, Image.Image):
            return False
        if img.mode != "RGB":
            img = img.convert("RGB")
        img = img.resize(out_size, Image.Resampling.LANCZOS)
        ensure_dir(os.path.dirname(out_path))
        img.save(out_path, format="PNG", optimize=True)
        return True
    except Exception:
        return False


def normalize_cards_version(cards_json: Dict) -> List[Dict]:
    version_key = next(k for k, v in cards_json.items() if isinstance(v, list))
    return cards_json[version_key]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export item images by forcing a specific asset name per itemId."
    )
    parser.add_argument("--buildId", default=DEFAULT_BUILD_ID)
    parser.add_argument("--outSuffix", default="pass5_artfix")
    parser.add_argument("--maxBundlesPerItem", type=int, default=220)
    parser.add_argument(
        "--overridesFile",
        default=os.path.join(
            os.path.dirname(__file__), "..", "data", "item_art_overrides.json"
        ),
        help="JSON file with forcedAssetByItemId map.",
    )
    parser.add_argument(
        "--onlyItemIds",
        default="",
        help="Optional pipe-separated list of itemIds to export from forced map.",
    )
    args = parser.parse_args()

    UnityPyConfig.FALLBACK_UNITY_VERSION = "2020.3.48f1"

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    build_dir = os.path.join(repo_root, ".cache", "game-builds", args.buildId)

    cards = json.load(open(os.path.join(build_dir, "cards.json"), "r", encoding="utf-8"))
    items = normalize_cards_version(cards)
    by_id = {
        c.get("Id"): c
        for c in items
        if isinstance(c, dict) and isinstance(c.get("Id"), str)
    }
    cat = AT.parse_binary(open(os.path.join(build_dir, "catalog.bin"), "rb").read())

    forced_asset_by_item_id: Dict[str, str] = {}
    overrides_file = os.path.abspath(args.overridesFile)
    if os.path.exists(overrides_file):
        parsed = json.load(open(overrides_file, "r", encoding="utf-8"))
        forced_asset_by_item_id = {
            k: v
            for (k, v) in (parsed.get("forcedAssetByItemId") or {}).items()
            if isinstance(k, str) and isinstance(v, str)
        }
    else:
        raise FileNotFoundError(f"overrides file not found: {overrides_file}")
    if args.onlyItemIds:
        wanted = {x.strip() for x in args.onlyItemIds.split("|") if x.strip()}
        forced_asset_by_item_id = {
            k: v for (k, v) in forced_asset_by_item_id.items() if k in wanted
        }

    out_thumb_dir = os.path.join(build_dir, f"exported_item_thumbs_{args.outSuffix}")
    out_full_dir = os.path.join(build_dir, f"exported_item_full_{args.outSuffix}")
    ensure_dir(out_thumb_dir)
    ensure_dir(out_full_dir)

    downloaded_bundle_paths: Dict[str, str] = {}
    env_by_url: Dict[str, UnityPy.environment.Environment] = {}

    def download_bundle(url: str) -> str:
        name = url.split("/")[-1]
        local = os.path.join(build_dir, "downloaded_bundles", name)
        if name not in downloaded_bundle_paths and not os.path.exists(local):
            download_file(url, local)
            downloaded_bundle_paths[name] = local
        return local

    def get_env(url: str) -> Optional[UnityPy.environment.Environment]:
        if url in env_by_url:
            return env_by_url[url]
        try:
            env = UnityPy.load(download_bundle(url))
            env_by_url[url] = env
            return env
        except Exception:
            return None

    def dep_bundles_for_artkey(art_key: str) -> List[str]:
        rl_list = cat.Resources.get(art_key) or []
        if not rl_list:
            return []
        # prefer CardData internalId when present
        card_data_iid = None
        for rl in rl_list:
            iid = getattr(rl, "InternalId", None)
            if isinstance(iid, str) and iid.endswith("_CardData.asset"):
                card_data_iid = iid
                break
        rl = next(
            (r for r in rl_list if getattr(r, "InternalId", None) == card_data_iid),
            rl_list[0],
        )
        deps = getattr(rl, "Dependencies", []) or []
        bundles: List[str] = []
        for d in deps:
            if (
                getattr(d, "ProviderId", None)
                != "UnityEngine.ResourceManagement.ResourceProviders.AssetBundleProvider"
            ):
                continue
            iid = getattr(d, "InternalId", None)
            if (
                isinstance(iid, str)
                and iid.startswith(REMOTE_BASE)
                and iid.endswith(".bundle")
            ):
                bundles.append(iid)
        seen = set()
        bundles = [b for b in bundles if not (b in seen or seen.add(b))]
        return bundles

    def find_obj_by_exact_name(
        env: UnityPy.environment.Environment, asset_name: str
    ) -> Optional[Tuple[str, object]]:
        target = asset_name.strip()
        if not target:
            return None
        for obj in env.objects:
            t = obj.type.name
            if t not in ("Texture2D", "Sprite"):
                continue
            try:
                pn = obj.peek_name()
            except Exception:
                pn = None
            if pn == target:
                return (t, obj)
        return None

    thumb_manifest: Dict[str, Dict[str, str]] = {}
    full_manifest: Dict[str, Dict[str, str]] = {}
    failed: List[str] = []

    for item_id, forced_asset in forced_asset_by_item_id.items():
        c = by_id.get(item_id)
        if not c:
            failed.append(item_id)
            continue
        art_key = c.get("ArtKey")
        if not isinstance(art_key, str) or art_key not in cat.Resources:
            failed.append(item_id)
            continue

        bundles = dep_bundles_for_artkey(art_key)
        found: Optional[Tuple[str, object, str]] = None  # (kind,obj,bundleUrl)
        for b_i, b in enumerate(bundles[: int(args.maxBundlesPerItem)]):
            env = get_env(b)
            if env is None:
                continue
            got = find_obj_by_exact_name(env, forced_asset)
            if got is None:
                continue
            kind, obj = got
            found = (kind, obj, b)
            break

        if found is None:
            failed.append(item_id)
            continue

        kind, obj, chosen_bundle = found
        size_label = str(c.get("Size", ""))
        thumb_size = output_size_for_item(size_label, 128)
        full_size = output_size_for_item(size_label, 512)

        thumb_path = os.path.join(out_thumb_dir, f"{item_id}.png")
        full_path = os.path.join(out_full_dir, f"{item_id}.png")

        ok_thumb = export_obj_image(obj, thumb_path, thumb_size)
        ok_full = export_obj_image(obj, full_path, full_size)
        if not ok_thumb or not ok_full:
            failed.append(item_id)
            continue

        hero0 = ""
        heroes = c.get("Heroes")
        if isinstance(heroes, list) and heroes and isinstance(heroes[0], str):
            hero0 = heroes[0]

        thumb_manifest[item_id] = {
            "artKey": art_key,
            "hero": hero0,
            "bundle": chosen_bundle.split("/")[-1],
            "imagePath": thumb_path,
            "chosenAsset": forced_asset,
            "chosenAssetKind": kind,
            "pass": "pass5_artfix",
        }
        full_manifest[item_id] = {
            "artKey": art_key,
            "hero": hero0,
            "bundle": chosen_bundle.split("/")[-1],
            "imagePath": full_path,
            "chosenAsset": forced_asset,
            "chosenAssetKind": kind,
            "pass": "pass5_artfix",
        }

    json.dump(
        {
            "manifest": thumb_manifest,
            "failedItemIds": failed,
            "forcedCount": len(forced_asset_by_item_id),
            "recoveredCount": len(thumb_manifest),
        },
        open(os.path.join(out_thumb_dir, "manifest.json"), "w", encoding="utf-8"),
        indent=2,
    )
    json.dump(
        {
            "manifest": full_manifest,
            "failedItemIds": failed,
            "forcedCount": len(forced_asset_by_item_id),
            "recoveredCount": len(full_manifest),
        },
        open(os.path.join(out_full_dir, "manifest.json"), "w", encoding="utf-8"),
        indent=2,
    )

    print("pass5_artfix export done")
    print("forced:", len(forced_asset_by_item_id))
    print("exported:", len(thumb_manifest))
    print("failed:", len(failed))
    if failed:
        for x in failed:
            print(" -", x)
    print("thumbManifest:", os.path.join(out_thumb_dir, "manifest.json"))
    print("fullManifest:", os.path.join(out_full_dir, "manifest.json"))


if __name__ == "__main__":
    main()

