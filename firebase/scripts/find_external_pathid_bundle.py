import argparse
import json
import os
import urllib.request
from typing import Dict, List, Set

import AddressablesTools as AT
import UnityPy
import UnityPy.config as UnityPyConfig

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


def gather_all_bundle_urls(cat: object) -> List[str]:
    urls: List[str] = []
    for rls in cat.Resources.values():
        for rl in rls:
            iid = getattr(rl, "InternalId", None)
            if isinstance(iid, str) and iid.startswith(REMOTE_BASE) and iid.endswith(".bundle"):
                urls.append(iid)
            for d in (getattr(rl, "Dependencies", []) or []):
                diid = getattr(d, "InternalId", None)
                if isinstance(diid, str) and diid.startswith(REMOTE_BASE) and diid.endswith(".bundle"):
                    urls.append(diid)
    seen: Set[str] = set()
    return [u for u in urls if not (u in seen or seen.add(u))]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Brute-force scan all bundles for a target pathID."
    )
    parser.add_argument("--buildId", default=DEFAULT_BUILD_ID)
    parser.add_argument("--pathId", type=int, required=True)
    parser.add_argument("--maxBundles", type=int, default=0, help="0 = no limit")
    parser.add_argument("--resumeFrom", type=int, default=0, help="start index in URL list")
    args = parser.parse_args()

    UnityPyConfig.FALLBACK_UNITY_VERSION = "2020.3.48f1"

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    build_dir = os.path.join(repo_root, ".cache", "game-builds", args.buildId)
    catalog_bin = os.path.join(build_dir, "catalog.bin")
    cat = AT.parse_binary(open(catalog_bin, "rb").read())

    urls = gather_all_bundle_urls(cat)
    start = max(0, int(args.resumeFrom))
    if args.maxBundles and args.maxBundles > 0:
        end = min(len(urls), start + int(args.maxBundles))
    else:
        end = len(urls)

    print(f"total_bundle_urls={len(urls)} scan_start={start} scan_end={end}")

    downloaded = 0
    loaded = 0
    errors = 0
    out_progress = os.path.join(build_dir, "pathid_scan_progress.json")

    for idx in range(start, end):
        url = urls[idx]
        fn = url.split("/")[-1]
        local = os.path.join(build_dir, "downloaded_bundles", fn)
        try:
            if not os.path.exists(local):
                download_file(url, local)
                downloaded += 1

            env = UnityPy.load(local)
            loaded += 1
            for obj in env.objects:
                if obj.path_id != args.pathId:
                    continue
                try:
                    pn = obj.peek_name()
                except Exception:
                    pn = ""
                print("FOUND")
                print(f"bundle={fn}")
                print(f"type={obj.type.name}")
                print(f"name={pn}")
                print(f"pathId={args.pathId}")
                json.dump(
                    {
                        "found": True,
                        "bundle": fn,
                        "url": url,
                        "type": obj.type.name,
                        "name": pn,
                        "pathId": args.pathId,
                        "index": idx,
                    },
                    open(os.path.join(build_dir, "pathid_scan_found.json"), "w", encoding="utf-8"),
                    indent=2,
                )
                return
        except Exception:
            errors += 1

        if (idx + 1) % 25 == 0:
            print(
                f"progress idx={idx+1}/{end} downloaded={downloaded} loaded={loaded} errors={errors}"
            )
            json.dump(
                {
                    "found": False,
                    "pathId": args.pathId,
                    "idx": idx + 1,
                    "end": end,
                    "downloaded": downloaded,
                    "loaded": loaded,
                    "errors": errors,
                },
                open(out_progress, "w", encoding="utf-8"),
                indent=2,
            )

    print("NOT_FOUND")
    print(f"pathId={args.pathId} scanned={end-start} downloaded={downloaded} loaded={loaded} errors={errors}")


if __name__ == "__main__":
    main()

