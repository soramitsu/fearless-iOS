#!/usr/bin/env python3
"""Validate iOS-owned configuration and ensure nested asset URLs are self-contained."""
import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

REPOSITORY = "fearless-iOS"
BASE = "https://raw.githubusercontent.com/soramitsu/" + REPOSITORY + "/master/remote-config/"
RETIRED = ("/soramitsu/shared-features-utils/", "/soramitsu/fearless-utils/")
BUNDLED_CONFIG = Path("fearless/Modules/LiquidityPools/LiquidityPoolDetails/Resources")
# Pins each file under remote-config/ (sources[].path, relative to remote-config/) to the SHA-256 of its bytes
# (ownedSha256). An edit re-pins the file and appends a corrections entry in the same commit.
IMPORTS = Path("config/remote-config-imports.json")
SHA256 = re.compile("[0-9a-f]{64}")
# Staking of these relays moved to their Asset Hubs (AssetHubStakingRoute in the app). The v13 lists the app reads
# mark only each hub's native token, as "assetHub": builds without Asset Hub staking read that as no staking.
MIGRATED_RELAYS = {
    "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
    "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe",
    "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e",
}
ASSET_HUB_NATIVE = {
    "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f": "887a17c7-1370-4de0-97dd-5422e294fa75",
    "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a": "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
    "67f9723393ef76214df0118c34bbbd3dbebc8ed46a10973a8c969d48fe7598c9": "a3868e1b-922e-42d4-b73e-b41712f0843c",
}


def check_asset_hub_staking(document, source, failures):
    """Relay staking lives on the Asset Hubs; a list must not send a build's relay staking code to either."""
    for chain in document if isinstance(document, list) else []:
        if not isinstance(chain, dict) or not isinstance(chain.get("chainId"), str):
            continue
        chain_id = chain["chainId"]
        for asset in chain.get("assets") or []:
            staking = asset.get("staking") if isinstance(asset, dict) else None
            if staking is None:
                continue
            if chain_id in MIGRATED_RELAYS:
                failures.append(source + ": relay " + chain_id[:8] + " offers staking that moved to its Asset Hub")
            elif chain_id in ASSET_HUB_NATIVE:
                if staking != "assetHub" or asset.get("id") != ASSET_HUB_NATIVE[chain_id]:
                    failures.append(source + ": Asset Hub " + chain_id[:8] + " stakes only its native token as assetHub")
            elif staking == "assetHub":
                failures.append(source + ": assetHub staking on " + chain_id[:8] + ", which is not an Asset Hub route")
        options = set(chain.get("options") or [])
        if (chain_id in MIGRATED_RELAYS or chain_id in ASSET_HUB_NATIVE) and options & {"poolStaking", "crowdloans"}:
            failures.append(source + ": no pool staking or crowdloans on relay or Asset Hub " + chain_id[:8])


def is_chain_keyed(file, root):
    """Chain lists (chains/v*/chains*.json), chain types (chains/all_chains_types.json) and their bundled fallbacks."""
    if file.parent == root / BUNDLED_CONFIG:
        return file.name in ("chains.json", "types.json")
    if file.parent.name == "chains":
        return file.name == "all_chains_types.json"
    return file.parent.parent.name == "chains" and file.name in ("chains.json", "chains_dev.json")


def check_unique_chain_ids(document, source, failures):
    """ChainSyncService.sanitizingRemoteChains refuses a whole chain list that repeats a chainId: the build keeps only
    its app-owned chains. The chain types readers (ChainsTypesSyncService, SnapshotHotBootBuilder) keep the last entry
    of a repeated chainId and drop the others without a word."""
    seen = set()
    for chain in document if isinstance(document, list) else []:
        chain_id = chain.get("chainId") if isinstance(chain, dict) else None
        if not isinstance(chain_id, str):
            continue
        if chain_id in seen:
            failures.append(source + ": chainId " + chain_id[:8] + " is listed more than once")
        seen.add(chain_id)


def check_pins(root, inventory, failures):
    """Every file the imports manifest pins exists under remote-config/ and still has its ownedSha256."""
    try:
        sources = json.loads((root / IMPORTS).read_text())["sources"]
        if not isinstance(sources, list):
            raise TypeError("sources is not a list")
    except (OSError, ValueError, KeyError, TypeError) as error:
        failures.append(str(IMPORTS) + ": cannot read the pins: " + str(error))
        return 0
    pinned = set()
    for entry in sources:
        path = entry.get("path") if isinstance(entry, dict) else None
        pin = entry.get("ownedSha256") if isinstance(entry, dict) else None
        if not isinstance(path, str) or not isinstance(pin, str) or not SHA256.fullmatch(pin):
            failures.append(str(IMPORTS) + ": malformed pin " + json.dumps(entry)[:160])
            continue
        if path in pinned:
            failures.append(str(IMPORTS) + ": remote-config/" + path + " is pinned more than once")
        pinned.add(path)
        # The inventory holds exact-case paths of files inside remote-config/, so "../" and case slips count as missing.
        if path not in inventory:
            failures.append(str(IMPORTS) + ": pinned file remote-config/" + path + " is missing")
            continue
        digest = hashlib.sha256((root / "remote-config" / path).read_bytes()).hexdigest()
        if digest != pin:
            failures.append(str(IMPORTS) + ": remote-config/" + path + " has SHA-256 " + digest + ", pinned " + pin)
    return len(pinned)


def validate(root):
    root = Path(root).resolve()
    config = root / "remote-config"
    inventory = {path.relative_to(config).as_posix() for path in config.rglob("*") if path.is_file()}
    failures = []
    counts = {"documents": 0, "ownedReferences": 0, "pinnedFiles": 0}

    def visit(value, source):
        if isinstance(value, dict):
            for child in value.values():
                visit(child, source)
        elif isinstance(value, list):
            for child in value:
                visit(child, source)
        elif isinstance(value, str):
            if any(fragment in value for fragment in RETIRED):
                failures.append(str(source) + ": retired config URL")
            if value.startswith(BASE):
                counts["ownedReferences"] += 1
                relative = unquote(urlsplit(value[len(BASE):]).path)
                target = (config / relative).resolve()
                if relative not in inventory or config.resolve() not in target.parents or not target.is_file():
                    failures.append(str(source) + ": missing owned asset " + relative)

    # Startup can use these bundled catalogs before the remote refresh succeeds.
    documents = set(config.rglob("*")) | set((root / BUNDLED_CONFIG).glob("*.json"))
    for file in sorted(documents):
        if not file.is_file() or (file.suffix != ".json" and file.name != "feature_toggle"):
            continue
        counts["documents"] += 1
        try:
            document = json.loads(file.read_text())
            visit(document, file.relative_to(root))
            if file.parent.name == "v13" and file.name in ("chains.json", "chains_dev.json"):
                check_asset_hub_staking(document, str(file.relative_to(root)), failures)
            if is_chain_keyed(file, root):
                check_unique_chain_ids(document, str(file.relative_to(root)), failures)
        except (ValueError, UnicodeError) as error:
            failures.append(str(file.relative_to(root)) + ": " + str(error))
    counts["pinnedFiles"] = check_pins(root, inventory, failures)
    if counts["documents"] == 0:
        failures.append("No owned configuration documents found")
    if failures:
        raise ValueError("\n".join(failures))
    return counts


if __name__ == "__main__":
    try:
        print(json.dumps(validate(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]), sort_keys=True))
    except (ValueError, OSError) as error:
        sys.exit(str(error))
