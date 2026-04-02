import argparse
import hashlib
import json
import os
import re
import urllib.request
import zipfile
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import AddressablesTools as AT
import UnityPy
import UnityPy.config as UnityPyConfig
from PIL import Image


DEFAULT_BUILD_URL = "https://data.playthebazaar.com/game/windows/buildx64.zip"
DEFAULT_BUILD_ID = "7fa9c6d76587deba235468246222ced7f2a6beb77d2f4a434fa23f1559c04eba"

REMOTE_BUNDLES_BASE = "https://data.playthebazaar.com/bundles/windows-standalone/"

# Known mismatches between expected card/base names and texture naming in bundles.
# Keys are expected names; values are alternate names seen in Unity assets.
NAME_MISMATCH_OVERRIDES: Dict[str, str] = {
    # Oh hell yeah we're mapping to a Cyrillic character
    "SeafoodCracker": "SeafoodСracker",
    "TrailMix": "AlienTrailMix",
    "Slushee": "Juleppe",
    "CloudWhisp": "CloudWisp",
    "ClockworkDisc": "Disc",
    "Daggerwing": "Dreadnought",
    "InFlightMeal": "InFlightDinner",
    "LaunchTower": "BalloonTower",
    "LavaRoller": "LavaCycle",
    "LightningButterfly": "ElectricButterflyDrone",
    "Pillbuggy": "Pilbuggy",
    "PilotsWings": "PilotBadge",
    "RammingBalloon": "BalloonRam",
    "SteamWasher": "DeIcingCart",
    "BattleBalloon": "BalloonArmor",
    "BombVoyage": "IncendiaryBalloon",
    "MagShield": "MagneticShieldGenerator",
    "BusinessCard": "BuisnessCard",
    "TheCore": "PowerCore",
    "NestingDoll": "Matryoshka",
    "Sapphire": "Saphire",
    "PickledPeppers": "PickledAlienVeggies",
    "CrustaceanClaw": "CrusherClaw1",
    "CosmicAmulet": "CosmicAmulet1",
    "Seaweed": "Seaweed1",
    "Hacksaw": "MetalSaw",
    "Ballista": "Balista",
    "EpicEpicureanChoclate": "EpicEpicureanChocolate",
    "CrocodileTears": "CursePotion",
    "CyberSecurity": "AvantGuard",
    "CrabbyLobster": "CrubbyLobster",
    "DarkwaterAnglerfish": "DarkwaterAnglerfish(1)",
    "JuicerBro": "Juiecerbro",
    "DoodleGlass": "DoodleGlas",
    # Oh hell yeah we're mapping to a Cyrillic character
    "Cleaver": "Сleaver",
    "Soulstone": "SoulStone",
    "DooltronMainframe": "DootronMainframe",
    "SandsOfTime": "TomeOfTime",
    "EthergyConduit": "LargeRelic",
    "CEGreenPiggles": "PremiumCollectorsEditionPiggles_Green",
    "CEOrangePiggles": "PremiumCollectorsEditionPiggles_Orange",
    "CERedPiggles": "PremiumCollectorsEditionPiggles_Red",
    "CEYellowPiggles": "PremiumCollectorsEditionPiggles_Yellow",
    "PremiumColectorsEditionPiggles": "PremiumCollectorsEditionPiggles",
    "PigglesBlueA": "Piggles_Blue_A",
    "PigglesBlueL": "Piggles_Blue_L",
    "PigglesBlueR": "Piggles_Blue_R",
    "PigglesRedA": "Piggles_Red_A",
    "PigglesRedL": "Piggles_Red_L",
    "PigglesRedR": "Piggles_Red_R",
    "PigglesYellowA": "Piggles_Yellow_A",
    "PigglesYellowL": "Piggles_Yellow_L",
    "PigglesYellowR": "Piggles_Yellow_R",
}


@dataclass(frozen=True)
class ItemToExtract:
    itemId: str
    internalName: str
    heroLower: str
    artKey: str
    cardDataInternalId: str
    size: str


def ensure_dir(p: str) -> None:
    os.makedirs(p, exist_ok=True)


def download_file(url: str, out_path: str) -> None:
    ensure_dir(os.path.dirname(out_path))
    print("Downloading", url)
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36",
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


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(1024 * 1024)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def normalize_cards_version(cards_json: Dict) -> List[Dict]:
    version_key = next(k for k, v in cards_json.items() if isinstance(v, list))
    return cards_json[version_key]


def should_skip_debug_item(name: str) -> bool:
    # Example: "[DEBUG] Something" or "Something [DEBUG] Something".
    return bool(re.search(r"\[[^\]]+\]", name or ""))


def compact_name(s: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "", (s or ""))


def build_name_candidates(base_card_name: str, internal_name: str) -> List[str]:
    candidates: List[str] = []

    def add(x: str) -> None:
        if not x:
            return
        if x not in candidates:
            candidates.append(x)

    base = compact_name(base_card_name)
    internal = compact_name(internal_name)
    add(base)
    add(internal)

    for k, v in NAME_MISMATCH_OVERRIDES.items():
        if base == k or internal == k:
            add(v)
        if base == v or internal == v:
            add(k)

    return candidates


def pick_card_bundle_url_for_hero(dependencies: list, hero_lower: str) -> Optional[str]:
    # AddressablesTools dependency entries are ResourceLocation objects.
    # We prefer the hero-specific card bundle: `card_<heroLower>__<hash>.bundle`.
    hero_prefix = f"card_{hero_lower}__"
    bundles: List[str] = []
    for d in dependencies:
        if getattr(d, "ProviderId", None) != "UnityEngine.ResourceManagement.ResourceProviders.AssetBundleProvider":
            continue
        iid = getattr(d, "InternalId", None)
        if not isinstance(iid, str) or not iid.endswith(".bundle"):
            continue
        if not iid.startswith("https://data.playthebazaar.com/bundles/windows-standalone/"):
            continue
        bundles.append(iid)

    # Some items use Neutral art even when hero is "Common".
    if hero_lower == "common":
        for b in bundles:
            name = b.split("/")[-1]
            if name.startswith("card_neutral__"):
                return b

    for b in bundles:
        name = b.split("/")[-1]
        if name.startswith(hero_prefix):
            return b
    # Fallback: any `card_` bundle URL
    for b in bundles:
        if "/card_" in b:
            return b
    return bundles[0] if bundles else None


def choose_texture_name(texture_names: List[str], name_candidates: List[str]) -> Optional[str]:
    needles = [n.lower() for n in name_candidates if n]
    compact_needles = [compact_name(n).lower() for n in name_candidates if n]
    if not needles:
        return None
    candidates = []
    for nm in texture_names:
        nl = nm.lower()
        compact_nl = compact_name(nl).lower()
        if not any((needle in nl) or (needle in compact_nl) for needle in needles + compact_needles):
            continue
        score = 0
        # Prefer the main diffuse/base art texture.
        if nl.endswith("_d"):
            score += 200
        elif "_d" in nl:
            score += 60

        # Explicitly avoid non-base layers/effects. We only want base art.
        if "mask" in nl:
            score -= 500
        if nl.startswith("fx_") or " fx_" in nl or "_fx_" in nl:
            score -= 200
        if "enchant" in nl or "enchantment" in nl:
            score -= 500
        # Prefer common diffuse/preview textures over masks.
        if "storeimage" in nl:
            score += 5
        candidates.append((score, nm))

    if not candidates:
        return None
    candidates.sort(key=lambda x: x[0], reverse=True)
    best_score, best_name = candidates[0]
    if best_score <= 0:
        # Still return the best; sometimes naming conventions differ.
        return best_name
    return best_name


def choose_mask_name(texture_names: List[str], name_candidates: List[str]) -> Optional[str]:
    """
    Choose a mask texture to drive alpha for the base diffuse art.
    We prefer non-enchantment/base masks (i.e. avoid `FX_` prefixed masks) when possible.
    """
    needles = [n.lower() for n in name_candidates if n]
    compact_needles = [compact_name(n).lower() for n in name_candidates if n]
    if not needles:
        return None
    best_cf: Optional[str] = None
    best_fx: Optional[str] = None
    best_cf_score = -10**18
    best_fx_score = -10**18

    for nm in texture_names:
        nl = nm.lower()
        compact_nl = compact_name(nl).lower()
        if not any((needle in nl) or (needle in compact_nl) for needle in needles + compact_needles):
            continue
        if "mask" not in nl:
            continue

        # Prefer non-FX masks (un-enchanted / base mask).
        is_fx = nl.startswith("fx_") or " fx_" in nl or "_fx_" in nl or nl.startswith("fx")
        score = 0
        # Prefer exact suffix/matching.
        if nl.endswith("_mask"):
            score += 200
        if "_mask" in nl:
            score += 50
        # Prefer the CF_ convention when present.
        if nl.startswith("cf_"):
            score += 100
        if "enchant" in nl or "enchantment" in nl:
            score -= 500

        if is_fx:
            if score > best_fx_score:
                best_fx_score = score
                best_fx = nm
        else:
            if score > best_cf_score:
                best_cf_score = score
                best_cf = nm

    return best_cf or best_fx


def choose_background_name(
    texture_names: List[str],
    sprite_names: List[str],
    hero_lower: str,
) -> Optional[str]:
    """
    Choose a hero "purchase" background asset inside the same card bundle.

    We intentionally avoid selecting masks/enchantment/FX assets; we only need the static background.
    """

    def score_name(nm: str) -> int:
        nl = nm.lower()
        if "mask" in nl:
            return -10**9
        if "enchant" in nl or "enchantment" in nl:
            return -10**9
        if "fx" in nl or "_fx_" in nl or " fx_" in nl:
            return -2000

        if "purchase_bg" in nl or "purchasebg" in nl:
            return 10000
        if "purchase" in nl and "bg" in nl:
            return 9000
        if "background" in nl:
            return 5000
        if " bg" in nl or "_bg" in nl or "bg_" in nl or "bg_" in nl:
            return 3000
        if "tui" in nl and "bg" in nl:
            return 2500
        # As a last resort, allow any name containing bg/background.
        if "bg" in nl:
            return 1000
        return -1

    candidates: List[Tuple[int, str]] = []
    for nm in sprite_names:
        sc = score_name(nm)
        if sc > 0:
            candidates.append((sc, nm))
    for nm in texture_names:
        sc = score_name(nm)
        if sc > 0:
            candidates.append((sc, nm))

    if not candidates:
        return None
    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][1]


def cover_to_size(img: Image.Image, target_size: Tuple[int, int]) -> Image.Image:
    """
    Resize while preserving aspect, then center-crop to exactly `target_size`.
    """
    tw, th = target_size
    sw, sh = img.size
    if sw <= 0 or sh <= 0:
        return img

    scale = max(tw / sw, th / sh)
    nw = max(1, int(round(sw * scale)))
    nh = max(1, int(round(sh * scale)))
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)

    left = max(0, (nw - tw) // 2)
    top = max(0, (nh - th) // 2)
    right = left + tw
    bottom = top + th
    return resized.crop((left, top, right, bottom))


def score_texture_bundle_matches(texture_names: List[str], name_candidates: List[str]) -> int:
    needles = [n.lower() for n in name_candidates if n]
    compact_needles = [compact_name(n).lower() for n in name_candidates if n]
    if not needles:
        return 0
    score = 0
    for nm in texture_names:
        nl = nm.lower()
        compact_nl = compact_name(nl).lower()
        if not any((needle in nl) or (needle in compact_nl) for needle in needles + compact_needles):
            continue
        if "mask" in nl or "enchant" in nl or "enchantment" in nl:
            score -= 200
        if nl.startswith("fx_") or " fx_" in nl or "_fx_" in nl:
            score -= 100
        if nl.endswith("_d"):
            score += 250
        elif "_d" in nl:
            score += 80
        if "storeimage" in nl:
            score += 10
    return score


def extract_texture_png_thumbnail_from_index(
    *,
    texture_names: List[str],
    tex_obj_by_name: Dict[str, object],
    bg_rgba: Optional[Image.Image],
    name_candidates: List[str],
    output_png_path: str,
    output_size: Tuple[int, int],
) -> bool:
    chosen_name = choose_texture_name(texture_names, name_candidates)
    if not chosen_name:
        return False
    obj = tex_obj_by_name.get(chosen_name)
    if not obj:
        return False

    data = obj.read()
    if not hasattr(data, "image"):
        return False

    img = data.image
    if not isinstance(img, Image.Image):
        return False

    # Art-only export:
    # The `*_D` textures often store the *visuals* in RGB but rely on alpha for runtime layering.
    # For our static catalog tiles, we want the whole background+foreground baked into the PNG,
    # so ignore the alpha channel by converting to RGB.
    # Drop alpha so we don't end up with "floating art" on a dark container.
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGB")
    elif img.mode != "RGB":
        img = img.convert("RGB")

    # Resize without cropping: we want the exported image to match the slot aspect.
    img = img.resize(output_size, Image.Resampling.LANCZOS)
    img.save(output_png_path, format="PNG", optimize=True)
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract item art thumbnails from The Bazaar build (Addressables+UnityPy).")
    parser.add_argument("--buildId", default=DEFAULT_BUILD_ID)
    parser.add_argument("--buildUrl", default=DEFAULT_BUILD_URL)
    parser.add_argument("--cardsJsonPath", default=None, help="Optional: local cards.json path to avoid extracting from zip.")
    parser.add_argument(
        "--outDir",
        default="exported_item_thumbs",
        help="Output directory under the build cache directory.",
    )
    parser.add_argument("--thumbMaxPx", type=int, default=256)
    parser.add_argument(
        "--fullOutDir",
        default="exported_item_full",
        help="Output directory under the build cache directory.",
    )
    parser.add_argument(
        "--includeFull",
        action="store_true",
        help="Also export full-size thumbnails (for item detail pages).",
    )
    parser.add_argument("--fullMaxPx", type=int, default=512)
    parser.add_argument("--limit", type=int, default=0, help="0 = no limit")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    UnityPyConfig.FALLBACK_UNITY_VERSION = "2020.3.48f1"

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    build_dir = os.path.join(repo_root, ".cache", "game-builds", args.buildId)
    ensure_dir(build_dir)

    # Ensure build zip exists, so we can extract cards.json + catalog.bin if needed.
    zip_path = os.path.join(build_dir, "buildx64.zip")
    if not os.path.exists(zip_path):
        tmp_zip_path = os.path.join(build_dir, "download_buildx64.zip")
        if not os.path.exists(tmp_zip_path):
            download_file(args.buildUrl, tmp_zip_path)
        # Copy to stable location for this buildId.
        if not os.path.exists(zip_path):
            ensure_dir(os.path.dirname(zip_path))
            with open(tmp_zip_path, "rb") as fsrc, open(zip_path, "wb") as fdst:
                fdst.write(fsrc.read())

    # Extract cards.json if not provided / not in cache.
    cards_json_out = os.path.join(build_dir, "cards.json")
    if args.cardsJsonPath:
        cards_json_out = args.cardsJsonPath
    if not os.path.exists(cards_json_out):
        ensure_dir(build_dir)
        with zipfile.ZipFile(zip_path, "r") as z:
            wanted_cards = "TheBazaar_Data/StreamingAssets/cards.json"
            # Normalize entry names.
            entry = next(e for e in z.namelist() if e.replace("\\", "/").endswith(wanted_cards))
            out_bytes = z.read(entry)
            with open(cards_json_out, "wb") as f:
                f.write(out_bytes)

    catalog_bin_path = os.path.join(build_dir, "catalog.bin")
    if not os.path.exists(catalog_bin_path):
        with zipfile.ZipFile(zip_path, "r") as z:
            wanted_catalog = "TheBazaar_Data/StreamingAssets/aa/catalog.bin"
            entry = next(e for e in z.namelist() if e.replace("\\", "/").endswith(wanted_catalog))
            out_bytes = z.read(entry)
            with open(catalog_bin_path, "wb") as f:
                f.write(out_bytes)

    # Parse Addressables catalog once.
    if args.verbose:
        print("Parsing catalog.bin...")
    cat = AT.parse_binary(open(catalog_bin_path, "rb").read())

    cards_json = json.load(open(cards_json_out, "r", encoding="utf-8"))
    items_cards = normalize_cards_version(cards_json)

    # Load initial card candidates (Type=Item, single hero).
    to_extract: List[ItemToExtract] = []
    for c in items_cards:
        if args.limit and len(to_extract) >= args.limit:
            break
        if not isinstance(c, dict):
            continue
        if c.get("Type") != "Item":
            continue
        heroes = c.get("Heroes")
        if not isinstance(heroes, list) or len(heroes) != 1 or not isinstance(heroes[0], str):
            continue
        hero = heroes[0].strip()
        if not hero:
            continue
        hero_lower = hero.lower()
        item_id = c.get("Id")
        art_key = c.get("ArtKey")
        internal_name = c.get("InternalName")
        size_label = c.get("Size")
        if not isinstance(item_id, str) or not item_id:
            continue
        if not isinstance(art_key, str) or not art_key:
            continue
        if not isinstance(internal_name, str) or not internal_name:
            continue
        if should_skip_debug_item(internal_name):
            continue
        if not isinstance(size_label, str):
            size_label = ''

        if art_key not in cat.Resources:
            continue

        rl_list = cat.Resources[art_key]
        # Choose the CardData internalId explicitly when possible.
        card_data_internal_id = None
        for rl in rl_list:
            iid = getattr(rl, "InternalId", None)
            if isinstance(iid, str) and iid.endswith("_CardData.asset"):
                card_data_internal_id = iid
                break
        if not card_data_internal_id:
            # Fallback to first entry.
            card_data_internal_id = getattr(rl_list[0], "InternalId", None)
        if not isinstance(card_data_internal_id, str) or not card_data_internal_id:
            continue

        to_extract.append(
            ItemToExtract(
                itemId=item_id.strip(),
                internalName=internal_name.strip(),
                heroLower=hero_lower,
                artKey=art_key.strip(),
                cardDataInternalId=card_data_internal_id,
                size=size_label.strip(),
            )
        )

    if args.verbose:
        print("Items to extract:", len(to_extract))

    out_dir = os.path.join(build_dir, args.outDir)
    ensure_dir(out_dir)
    manifest_path = os.path.join(out_dir, "manifest.json")

    full_out_dir = None
    full_manifest_path = None
    full_manifest: Dict[str, Dict[str, str]] = {}
    failed_full: List[str] = []
    if args.includeFull:
        full_out_dir = os.path.join(build_dir, args.fullOutDir)
        ensure_dir(full_out_dir)
        full_manifest_path = os.path.join(full_out_dir, "manifest.json")

    # Cache UnityPy env per hero card bundle (because we reuse it a lot).
    unity_env_by_bundle_url: Dict[str, UnityPy.environment.Environment] = {}
    downloaded_bundle_paths: Dict[str, str] = {}
    # Cache per-bundle texture indexes so we don't rescan objects for each item.
    texture_index_by_bundle_url: Dict[str, Tuple[List[str], Dict[str, object]]] = {}
    sprite_index_by_bundle_url: Dict[str, Tuple[List[str], Dict[str, object]]] = {}
    background_rgba_by_bundle_url: Dict[str, Image.Image] = {}

    def download_bundle(url: str) -> str:
        name = url.split("/")[-1]
        local_path = os.path.join(build_dir, "downloaded_bundles", name)
        if name not in downloaded_bundle_paths and not os.path.exists(local_path):
            download_file(url, local_path)
            downloaded_bundle_paths[name] = local_path
        return local_path

    def get_texture_index_for_bundle(bundle_url: str) -> Tuple[List[str], Dict[str, object]]:
        cached = texture_index_by_bundle_url.get(bundle_url)
        if cached is not None:
            return cached

        if bundle_url not in unity_env_by_bundle_url:
            local_bundle_path = download_bundle(bundle_url)
            unity_env_by_bundle_url[bundle_url] = UnityPy.load(local_bundle_path)

        unity_env = unity_env_by_bundle_url[bundle_url]
        tex_obj_by_name: Dict[str, object] = {}
        texture_names: List[str] = []
        for obj in unity_env.objects:
            if obj.type.name != "Texture2D":
                continue
            try:
                pn = obj.peek_name()
            except Exception:
                pn = None
            name = pn if isinstance(pn, str) and pn else None
            if not name:
                try:
                    data = obj.read()
                    name = getattr(data, "name", "") or getattr(data, "m_Name", "") or ""
                except Exception:
                    name = ""
            if isinstance(name, str) and name:
                texture_names.append(name)
                tex_obj_by_name[name] = obj

        texture_index_by_bundle_url[bundle_url] = (texture_names, tex_obj_by_name)
        return texture_names, tex_obj_by_name

    def get_sprite_index_for_bundle(bundle_url: str) -> Tuple[List[str], Dict[str, object]]:
        cached = sprite_index_by_bundle_url.get(bundle_url)
        if cached is not None:
            return cached

        if bundle_url not in unity_env_by_bundle_url:
            local_bundle_path = download_bundle(bundle_url)
            unity_env_by_bundle_url[bundle_url] = UnityPy.load(local_bundle_path)

        unity_env = unity_env_by_bundle_url[bundle_url]
        spr_obj_by_name: Dict[str, object] = {}
        sprite_names: List[str] = []
        for obj in unity_env.objects:
            if obj.type.name != "Sprite":
                continue
            try:
                pn = obj.peek_name()
            except Exception:
                pn = None
            name = pn if isinstance(pn, str) and pn else None
            if not name:
                # Some sprites may not expose peek_name; fall back to read metadata.
                try:
                    data = obj.read()
                    name = getattr(data, "name", "") or getattr(data, "m_Name", "") or ""
                except Exception:
                    name = ""
            if isinstance(name, str) and name:
                sprite_names.append(name)
                spr_obj_by_name[name] = obj

        sprite_index_by_bundle_url[bundle_url] = (sprite_names, spr_obj_by_name)
        return sprite_names, spr_obj_by_name

    manifest: Dict[str, Dict[str, str]] = {}
    failed: List[str] = []

    def output_size_for_item(size_label: str, max_height_px: int) -> Tuple[int, int]:
        # Slot geometry:
        # - Each slot is half as wide as it is tall.
        # - small => 1 slot, medium => 2 slots, large => 3 slots.
        s = (size_label or '').strip().lower()
        slot_count = 2
        if s == 'small':
            slot_count = 1
        elif s == 'medium':
            slot_count = 2
        elif s == 'large':
            slot_count = 3

        height = max(1, int(max_height_px))
        width = max(1, int(round(height * (slot_count / 2))))
        return width, height

    for idx, item in enumerate(to_extract):
        if args.verbose and idx % 10 == 0:
            print(f"Processing {idx+1}/{len(to_extract)}: {item.internalName} ({item.itemId})")

        rl_list = cat.Resources[item.artKey]
        # Find the ResourceLocation that corresponds to this cardData internal id.
        rl = None
        for r in rl_list:
            if getattr(r, "InternalId", None) == item.cardDataInternalId:
                rl = r
                break
        if rl is None:
            rl = rl_list[0]

        deps = getattr(rl, "Dependencies", []) or []

        # Texture naming usually follows the Addressables asset naming convention (no spaces, e.g. `MagnifyingGlass`),
        # so derive base card name from `*_CardData.asset` instead of `cards.json` InternalName.
        # Example internalId: .../MagnifyingGlass/MagnifyingGlass_CardData.asset
        # Base card name: MagnifyingGlass
        card_file = item.cardDataInternalId.split("/")[-1]
        # Be resilient to casing differences in Unity asset filenames.
        base_card_name = re.sub(r"_carddata\.asset$", "", card_file, flags=re.IGNORECASE)
        base_card_name = re.sub(r"\.asset$", "", base_card_name, flags=re.IGNORECASE)
        name_candidates = build_name_candidates(base_card_name, item.internalName)

        # Candidate card bundles from dependencies.
        card_bundles: List[str] = []
        for d in deps:
            if getattr(d, "ProviderId", None) != "UnityEngine.ResourceManagement.ResourceProviders.AssetBundleProvider":
                continue
            iid = getattr(d, "InternalId", None)
            if not isinstance(iid, str):
                continue
            if not iid.endswith(".bundle"):
                continue
            if "/bundles/windows-standalone/" not in iid:
                continue
            # Keep only hero-card-ish bundles; for this repo they appear as `.../card_<hero>__...bundle`.
            if "/card_" not in iid:
                continue
            card_bundles.append(iid)

        # De-dupe while preserving order.
        seen: set[str] = set()
        card_bundles = [b for b in card_bundles if not (b in seen or seen.add(b))]

        if not card_bundles:
            failed.append(item.itemId)
            continue

        # Fast-path: use the hero-specific `card_<hero>__*.bundle` when present.
        best_bundle: Optional[str] = pick_card_bundle_url_for_hero(deps, item.heroLower)
        if best_bundle:
            # If the hero-bundle doesn't actually include this item art (happens for some Common/Neutral cases),
            # fall back to scoring across all candidate card bundles.
            try:
                bn, _ = get_texture_index_for_bundle(best_bundle)
                if choose_texture_name(bn, name_candidates) is None:
                    best_bundle = None
            except Exception:
                best_bundle = None

        if not best_bundle:
            best_score = -10**18
            for b in card_bundles:
                texture_names, _ = get_texture_index_for_bundle(b)
                score = score_texture_bundle_matches(texture_names, name_candidates)
                if score > best_score:
                    best_score = score
                    best_bundle = b

        if not best_bundle:
            failed.append(item.itemId)
            continue

        texture_names, tex_obj_by_name = get_texture_index_for_bundle(best_bundle)
        sprite_names, spr_obj_by_name = get_sprite_index_for_bundle(best_bundle)
        bg_rgba: Optional[Image.Image] = None
        if best_bundle in background_rgba_by_bundle_url:
            bg_rgba = background_rgba_by_bundle_url[best_bundle]
        else:
            bg_name = choose_background_name(texture_names, sprite_names, item.heroLower)
            if bg_name:
                bg_obj = spr_obj_by_name.get(bg_name) or tex_obj_by_name.get(bg_name)
                if bg_obj is not None:
                    try:
                        bg_data = bg_obj.read()
                        if hasattr(bg_data, "image") and isinstance(bg_data.image, Image.Image):
                            bg_rgba = bg_data.image.convert("RGBA")
                            background_rgba_by_bundle_url[best_bundle] = bg_rgba
                    except Exception:
                        bg_rgba = None

        out_png = os.path.join(out_dir, f"{item.itemId}.png")
        thumb_w, thumb_h = output_size_for_item(item.size, args.thumbMaxPx)
        ok = extract_texture_png_thumbnail_from_index(
            texture_names=texture_names,
            tex_obj_by_name=tex_obj_by_name,
            bg_rgba=bg_rgba,
            name_candidates=name_candidates,
            output_png_path=out_png,
            output_size=(thumb_w, thumb_h),
        )
        if not ok:
            failed.append(item.itemId)
            continue

        manifest[item.itemId] = {
            "artKey": item.artKey,
            "hero": item.heroLower,
            "bundle": best_bundle.split("/")[-1],
            # Store absolute path for now; later we can rewrite to repo-relative or asset-relative.
            "imagePath": out_png,
        }

        if args.includeFull and full_out_dir is not None:
            full_png = os.path.join(full_out_dir, f"{item.itemId}.png")
            full_w, full_h = output_size_for_item(item.size, args.fullMaxPx)
            ok_full = extract_texture_png_thumbnail_from_index(
                texture_names=texture_names,
                tex_obj_by_name=tex_obj_by_name,
                bg_rgba=bg_rgba,
                name_candidates=name_candidates,
                output_png_path=full_png,
                output_size=(full_w, full_h),
            )
            if ok_full:
                full_manifest[item.itemId] = {
                    "artKey": item.artKey,
                    "hero": item.heroLower,
                    "bundle": best_bundle.split("/")[-1],
                    "imagePath": full_png,
                }
            else:
                failed_full.append(item.itemId)

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump({"manifest": manifest, "failedItemIds": failed}, f, indent=2)

    if args.includeFull and full_manifest_path:
        with open(full_manifest_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "manifest": full_manifest,
                    "failedItemIds": failed_full,
                },
                f,
                indent=2,
            )

    print("Done.")
    print("Extracted:", len(manifest), "failed:", len(failed))
    print("Manifest:", manifest_path)
    if args.includeFull and full_manifest_path:
        print("Full extracted:", len(full_manifest), "failed:", len(failed_full))
        print("Full manifest:", full_manifest_path)


if __name__ == "__main__":
    main()

