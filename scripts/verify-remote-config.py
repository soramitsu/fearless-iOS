#!/usr/bin/env python3
"""Validate iOS-owned configuration and ensure nested asset URLs are self-contained."""
import json
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit

REPOSITORY = "fearless-iOS"
BASE = "https://raw.githubusercontent.com/soramitsu/" + REPOSITORY + "/master/remote-config/"
RETIRED = ("/soramitsu/shared-features-utils/", "/soramitsu/fearless-utils/")
BUNDLED_CONFIG = Path("fearless/Modules/LiquidityPools/LiquidityPoolDetails/Resources")
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


def validate(root):
    root = Path(root).resolve()
    config = root / "remote-config"
    inventory = {path.relative_to(config).as_posix() for path in config.rglob("*") if path.is_file()}
    failures = []
    counts = {"documents": 0, "ownedReferences": 0}

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
        except (ValueError, UnicodeError) as error:
            failures.append(str(file.relative_to(root)) + ": " + str(error))
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
