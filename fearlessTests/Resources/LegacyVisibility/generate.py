#!/usr/bin/env python3
"""Generates the IOSUX-6 legacy asset visibility fixtures.

The fixtures describe wallets as App Store 4.0.4 (tag 4.0.4, 195b02307) and the
TestFlight 2026.9.x builds left them on disk. Every visibility row is produced by
re-implementing the writers that shipped, line by line, over the reviewed registry
snapshot and a declared balance map. Nothing here imports or mirrors the code under
test, so the upgrade tests in LegacyVisibilityMigrationV2Tests are not circular.

Writers re-implemented (paths at 195b02307 unless noted):
- WalletAssetsObserver.updateCurrentWallet(with:)        :182-200  hidden = accountInfo == nil || isZero
- WalletAssetsObserver.setDefaultVisibilitiesIfNeeded    :205-215  when no row is visible: hidden = !(rank != nil && isUtility)
- WalletAssetsObserver.updateVisibility(for:)            :107-137  TON chains are never scanned
- WalletAssetsObserver.update(_:with:)                   :217-225  a row replaces the row with the same assetId
- AssetManagementMigrator.migrate (3.6-3.7.4)            :31-63, 114-128  hidden = !(account && nonZero)
- MultiassetV9MigrationPolicy                            :13-36    assetIdsEnabled entries become hidden = true
- Manage switches (AssetManagementInteractor)            a user toggle writes one row
- TestFlight 9415f7f7b AssetVisibilityPreferenceStore.migrateLegacyHides :789-832 (the first AssetKey migration)
- TestFlight 9415f7f7b WalletAssetsObserverImpl.setDefaultVisibilitiesIfNeeded :583-618 (auto Shown)
- TestFlight 9415f7f7b AssetKey (ChainAsset.swift:12-18, 52-118) and AssetVisibilityPreferenceStore.key
  :838-846, so `storedPreferences` holds the UserDefaults keys those builds wrote, not keys the
  release derives

Usage: generate.py [--check]   (writes next to this script; --check only compares)
"""

import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REGISTRY = HERE.parent / "Registry" / "chains_v13_20261009.json"
REGISTRY_SHA256 = "fa6f0e23cd87dfb3e5536980591dd22ae30e49bf59d04dc2a0b31fc53237ea66"

# App-owned networks the TestFlight builds merged in at runtime
# (UniversalWalletRegistry.appOwnedProductionChains at 9415f7f7b: bitcoinMainnetChainModel :45-102,
# tairaChainModel :191-246). 4.0.4 had neither. The currency ids decide the stored AssetKey:
# Taira's XOR is keyed by its alias, not by its asset definition id.
APP_OWNED_CHAINS = [
    {
        "chainId": "bitcoin:mainnet", "name": "Bitcoin", "rank": 1, "ecosystem": "bitcoin",
        "options": [], "disabled": False,
        "assets": [{"id": "BTC", "currencyId": "BTC", "symbol": "BTC", "name": "Bitcoin", "isUtility": True}],
    },
    {
        "chainId": "iroha3-taira", "name": "Taira Testnet", "rank": 2, "ecosystem": "iroha",
        "options": ["testnet"], "disabled": False,
        "assets": [{
            "id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw", "currencyId": "xor#universal",
            "symbol": "XOR", "name": "SORA XOR", "isUtility": True,
        }],
    },
]


def load_registry():
    data = REGISTRY.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != REGISTRY_SHA256:
        sys.exit(f"registry snapshot sha256 {digest} != {REGISTRY_SHA256}")
    return json.loads(data)


def identifier(chain, asset):
    # ChainAsset.identifier: [chain.identifier, asset.id].joined(separator: " : ")
    return f"{chain['chainId']} : {asset['id']}"


def chain_assets(chains):
    for chain in chains:
        for asset in chain["assets"]:
            yield chain, asset


def find(chains, network, symbol):
    matches = [identifier(c, a) for c, a in chain_assets(chains) if c["name"] == network and a["symbol"] == symbol]
    assert len(matches) == 1, (network, symbol, matches)
    return matches[0]


def account_family(chain):
    return {"substrate": "substrate", "ethereum": "evm", "ethereumBased": "evm", "ton": "ton"}.get(chain.get("ecosystem"))


def is_ton(chain):
    return chain.get("ecosystem") == "ton"


def asset_key_ecosystem(chain):
    # AssetKey.ecosystem(for:) with ChainModel.isTonCompatibilityChain and isEthereumBased.
    chain_id = chain["chainId"].lower()
    name_tokens = "".join(ch if ch.isalnum() else " " for ch in chain["name"].lower()).split()
    if "ton" in name_tokens or chain_id in ("ton", "-239", "-3") or chain_id.startswith(("ton-", "ton:")):
        return "ton"
    if chain_id.startswith("bitcoin:"):
        return "bitcoin"
    if chain_id.startswith("solana:"):
        return "solana"
    if chain_id.startswith("iroha") or chain_id.startswith("sora:nexus"):
        return "iroha"
    if {"ethereumBased", "ethereum"} & set(chain.get("options") or []):
        return "evm"
    return "substrate"


def storage_key(chain, asset):
    """The part of the UserDefaults key after "asset.presentation.explicit.hidden:<walletId>:":
    ecosystem, lowercased chain id and canonical asset id (currencyId when present, lowercased
    on EVM networks)."""
    ecosystem = asset_key_ecosystem(chain)
    asset_id = asset.get("currencyId") or asset["id"]
    if ecosystem == "evm":
        asset_id = asset_id.lower()
    return ":".join([ecosystem, chain["chainId"].lower(), asset_id])


class LegacyWallet:
    """MetaAccountModel.assetsVisibility as the 4.0.4 writers maintained it."""

    def __init__(self, accounts):
        self.accounts = set(accounts)
        self.rows = []

    def has_account(self, chain):
        return account_family(chain) in self.accounts

    # WalletAssetsObserver.update(_:with:)
    def update(self, asset_id, hidden):
        self.rows = [row for row in self.rows if row["assetId"] != asset_id]
        self.rows.append({"assetId": asset_id, "hidden": hidden})

    # WalletAssetsObserver.setDefaultVisibilitiesIfNeeded(chains:)
    def set_default_visibilities_if_needed(self, chains):
        is_new_wallet = not [row for row in self.rows if not row["hidden"]]
        if not is_new_wallet:
            return
        self.rows = [
            {"assetId": identifier(c, a), "hidden": not (c.get("rank") is not None and bool(a.get("isUtility")))}
            for c, a in chain_assets(chains)
        ]

    # WalletAssetsObserver.updateVisibility(for:) + updateCurrentWallet(with:):
    # the Manage pull-to-refresh. A chain is scanned when the wallet has an
    # account on it; TON chains are skipped.
    def pull_to_refresh(self, chains, balances):
        scanned = [c for c in chains if not is_ton(c) and self.has_account(c)]
        for chain, asset in chain_assets(scanned):
            key = identifier(chain, asset)
            self.update(key, balances.get(key, 0) == 0)
        self.set_default_visibilities_if_needed(scanned)

    # AssetManagementMigrator.migrate (3.6-3.7.4): replaces every row.
    def asset_management_migrator(self, chains, balances):
        if not self.rows:
            return
        self.rows = [
            {
                "assetId": identifier(c, a),
                "hidden": not (self.has_account(c) and balances.get(identifier(c, a), 0) > 0),
            }
            for c, a in chain_assets(chains)
        ]

    # MultiassetV9MigrationPolicy: every assetIdsEnabled entry becomes a hidden row.
    def v9_policy(self, asset_ids_enabled):
        for asset_id in asset_ids_enabled:
            self.rows.append({"assetId": asset_id, "hidden": True})

    # A Manage switch.
    def toggle(self, asset_id, hidden):
        self.update(asset_id, hidden)


def first_migration(rows, chains, stored):
    """TestFlight 9415f7f7b migrateLegacyHides: an explicit preference for every
    asset whose identifier, id, canonical id, symbol or name equals the row's
    assetId (case-insensitively except the identifier); later rows overwrite.
    `stored` receives the UserDefaults entries in write order."""
    prefs = {}
    for row in rows:
        wanted = row["assetId"]
        for chain, asset in chain_assets(chains):
            loose = [asset["id"], asset.get("currencyId") or asset["id"], asset["symbol"], asset["name"]]
            if identifier(chain, asset) == wanted or wanted.lower() in [value.lower() for value in loose]:
                prefs[identifier(chain, asset)] = "hidden" if row["hidden"] else "shown"
                stored[storage_key(chain, asset)] = prefs[identifier(chain, asset)]
    return prefs


def testflight_auto_shown(prefs, chains, stored):
    """TestFlight 9415f7f7b setDefaultVisibilitiesIfNeeded: Shown for the utility
    asset of every ranked network, and for SORA Nexus XOR, whose stored preference
    is still Auto. Every ranked network is listed: the daily sweep covers mainnets
    and a Manage pull-to-refresh covers the testnets it lists (Taira included)."""
    written = []
    for chain, asset in chain_assets(chains):
        key = identifier(chain, asset)
        name = chain["name"].lower()
        is_pinned_native = chain.get("rank") is not None and bool(asset.get("isUtility"))
        is_sora_nexus_xor = bool(asset.get("isUtility")) and asset["symbol"].lower() == "xor" and "sora" in name and "nexus" in name
        if (is_pinned_native or is_sora_nexus_xor) and storage_key(chain, asset) not in stored:
            prefs[key] = "shown"
            stored[storage_key(chain, asset)] = "shown"
            written.append(key)
    return written


def user_choices(choices, chains, prefs, stored):
    """Manage switches and row actions in a TestFlight build: one stored preference each."""
    by_identifier = {identifier(c, a): (c, a) for c, a in chain_assets(chains)}
    for key, value in choices.items():
        chain, asset = by_identifier[key]
        prefs[key] = value
        stored[storage_key(chain, asset)] = value


def fixture(fixture_id, description, wallet, balances, ecosystem="regular", **extra):
    document = {
        "format": "fearless.ios-legacy-visibility-fixture",
        "version": 1,
        "id": fixture_id,
        "description": description,
        "generator": "LegacyVisibility/generate.py",
        "registrySha256": REGISTRY_SHA256,
        "wallet": {
            "ecosystem": ecosystem,
            "legacyTon": ecosystem == "ton",
            "accounts": sorted(wallet.accounts),
            "assetsVisibility": wallet.rows,
        },
        "balances": {key: str(value) for key, value in sorted(balances.items()) if value > 0},
    }
    document.update(extra)
    return document


def build(registry):
    enabled = [c for c in registry if not c.get("disabled")]
    fixtures = []

    # 1. A regular wallet after a 4.0.4 Manage pull-to-refresh: six holdings,
    # every other scanned asset hidden at zero.
    funded = {
        find(registry, "Polkadot", "dot"): 12_000_000_000,
        find(registry, "Kusama", "ksm"): 3_000_000_000_000,
        find(registry, "Ethereum", "eth"): 250_000_000_000_000_000,
        find(registry, "Moonbeam", "glmr"): 40_000_000_000_000_000_000,
        find(registry, "SORA Mainnet", "val"): 7_000_000_000_000_000_000,
        find(registry, "Polkadot AssetHub", "usdt"): 125_000_000,
    }
    wallet = LegacyWallet(["substrate", "evm"])
    wallet.pull_to_refresh(enabled, funded)
    fixtures.append(fixture(
        "404-regular-scanned",
        "Regular 4.0.4 wallet after a Manage pull-to-refresh: six funded assets visible, every other "
        "scanned asset written hidden = isZero.",
        wallet, funded,
    ))

    # 2. 3.6-3.7.4 AssetManagementMigrator output (it replaced the V9 rows).
    funded = {
        find(registry, "Kusama", "ksm"): 1_500_000_000_000,
        find(registry, "Acala", "aca"): 9_000_000_000_000,
        find(registry, "Polygon", "usdc"): 42_000_000,
    }
    wallet = LegacyWallet(["substrate", "evm"])
    wallet.v9_policy(["1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b"])
    wallet.asset_management_migrator(registry, funded)
    fixtures.append(fixture(
        "374-migrator",
        "Regular wallet whose rows were rewritten by the 3.6-3.7.4 AssetManagementMigrator "
        "(hidden = !(account && nonZero)) and never refreshed afterwards.",
        wallet, funded,
    ))

    # 3. Rows the Core Data V9 policy produced from assetIdsEnabled: bare
    # registry asset ids and a symbol, all hidden. The DOT and KSM ids name the
    # relay chain and Asset Hub rows alike.
    funded = {
        find(registry, "Polkadot", "dot"): 5_000_000_000,
        find(registry, "Kusama AssetHub", "ksm"): 800_000_000_000,
    }
    wallet = LegacyWallet(["substrate", "evm"])
    wallet.v9_policy([
        "887a17c7-1370-4de0-97dd-5422e294fa75",
        "1e0c2ec6-935f-49bd-a854-5e12ee6c9f1b",
        "PHA",
    ])
    fixtures.append(fixture(
        "v9-asset-ids-enabled",
        "Rows converted by MultiassetV9MigrationPolicy: bare asset ids and a symbol, hidden = true.",
        wallet, funded,
    ))

    # 4. A 4.0.4 TON wallet. Jettons came from TonJettonInjector with
    # id = jetton wallet address and currencyId = jetton master; the release
    # stores id = currencyId = master, so both rows share one AssetKey.
    ton_chain = next(c for c in registry if c["chainId"] == "-239")
    master = {name: "0:" + hashlib.sha256(f"master-{name}".encode()).hexdigest() for name in "ABCDE"}
    jetton_wallet = {name: "0:" + hashlib.sha256(f"wallet-{name}".encode()).hexdigest() for name in "ABCDE"}
    extra_assets = []
    for name, symbol in [("A", "FUNDHID"), ("B", "SPAM"), ("C", "REON"), ("D", "NEWJET")]:
        extra_assets.append({
            "chainId": "-239", "id": jetton_wallet[name], "currencyId": master[name],
            "symbol": symbol, "name": f"Jetton {name}", "precision": 9, "format": "4.0.4",
        })
    extra_assets.append({
        "chainId": "-239", "id": master["A"], "currencyId": master["A"],
        "symbol": "FUNDHID", "name": "Jetton A", "precision": 9, "format": "release",
    })
    ton_key = identifier(ton_chain, ton_chain["assets"][0])
    jetton_key = {name: f"-239 : {jetton_wallet[name]}" for name in "ABCDE"}
    funded = {
        ton_key: 3_000_000_000,
        jetton_key["A"]: 50_000_000_000,
        jetton_key["C"]: 1_000_000_000,
        jetton_key["D"]: 2_000_000_000,
    }
    wallet = LegacyWallet(["ton"])
    wallet.toggle(jetton_key["A"], True)
    wallet.toggle(jetton_key["B"], True)
    wallet.toggle(jetton_key["C"], True)
    wallet.toggle(jetton_key["C"], False)
    wallet.toggle(jetton_key["E"], True)  # a jetton the catalog no longer has
    wallet.pull_to_refresh(enabled, {})
    fixtures.append(fixture(
        "404-ton-optout",
        "4.0.4 TON wallet: everything without a hidden row was listed, so hidden rows are the user's. "
        "Jetton A is hidden and funded, B hidden at zero, C re-enabled, D never toggled, E no longer exists.",
        wallet, funded, ecosystem="ton",
        extraAssets=extra_assets,
        userHidden=[jetton_key["A"], jetton_key["B"]],
        unmatched=[jetton_key["E"]],
    ))

    # 5. A new wallet scanned while empty (defaults: ranked utility visible,
    # everything else hidden), funded later.
    scan_balances = {}
    current = {
        find(registry, "Polkadot", "dot"): 20_000_000_000,
        find(registry, "Phala", "pha"): 3_000_000_000_000,
        find(registry, "Polkadot AssetHub", "usdt"): 9_000_000,
    }
    wallet = LegacyWallet(["substrate", "evm"])
    wallet.pull_to_refresh(enabled, scan_balances)
    fixtures.append(fixture(
        "404-auto-hidden-then-funded",
        "Regular wallet scanned by 4.0.4 while empty, so only ranked utility assets were visible; "
        "PHA and Asset Hub USDT were written hidden and have been funded since.",
        wallet, current,
        scanBalances={},
    ))

    # 6. A TestFlight 2026.9.x device: 4.0.4 rows, the first AssetKey migration,
    # the auto-Shown writes, then choices the user made in TestFlight.
    scan_balances = {
        find(registry, "Polkadot", "dot"): 4_000_000_000,
        find(registry, "Ethereum", "eth"): 10_000_000_000_000_000,
    }
    wallet = LegacyWallet(["substrate", "evm"])
    wallet.pull_to_refresh(enabled, scan_balances)
    all_chains = registry + APP_OWNED_CHAINS
    stored = {}
    prefs = first_migration(wallet.rows, all_chains, stored)
    first_migration_prefs = dict(prefs)
    auto_shown = testflight_auto_shown(prefs, all_chains, stored)
    changed_hidden_to_shown = find(registry, "Kusama", "ksm")
    changed_shown_to_hidden = find(registry, "Ethereum", "eth")
    post_upgrade = {
        identifier(APP_OWNED_CHAINS[0], APP_OWNED_CHAINS[0]["assets"][0]): "hidden",
        ton_key: "hidden",
        changed_hidden_to_shown: "shown",
        changed_shown_to_hidden: "hidden",
    }
    assert first_migration_prefs[changed_hidden_to_shown] == "hidden"
    assert first_migration_prefs[changed_shown_to_hidden] == "shown"
    user_choices(post_upgrade, all_chains, prefs, stored)
    current = dict(scan_balances)
    current[find(registry, "Acala", "aca")] = 2_000_000_000_000
    fixtures.append(fixture(
        "testflight-v1-applied",
        "TestFlight device: 4.0.4 rows, then the first AssetKey migration made every row explicit, the "
        "auto-Shown writer marked Bitcoin and Taira Shown, and the user then hid Bitcoin and TON and "
        "changed two migrated values. ACA was hidden at zero by 4.0.4 and has been funded since.",
        wallet, current,
        firstMigrationMarker=True,
        firstMigrationPreferences=first_migration_prefs,
        autoShown=auto_shown,
        postUpgradeChoices=post_upgrade,
        preferences=dict(sorted(prefs.items())),
        storedPreferences=dict(sorted(stored.items())),
    ))

    # 7. A wallet created on a TestFlight 2026.9.x build: no 4.0.4 rows, so the
    # first migration only left its marker and every scan stored Shown for the
    # ranked networks' utility assets. The user then hid DOT (funded) and
    # switched on ACA, which no scan ever touches.
    wallet = LegacyWallet(["substrate", "evm"])
    stored = {}
    prefs = first_migration(wallet.rows, all_chains, stored)
    assert prefs == {}
    auto_shown = testflight_auto_shown(prefs, all_chains, stored)
    hidden_after_scan = find(registry, "Polkadot", "dot")
    shown_by_user = find(registry, "Acala", "aca")
    assert hidden_after_scan in auto_shown and shown_by_user not in auto_shown
    post_upgrade = {hidden_after_scan: "hidden", shown_by_user: "shown"}
    user_choices(post_upgrade, all_chains, prefs, stored)
    current = {
        hidden_after_scan: 30_000_000_000,
        find(registry, "Ethereum", "eth"): 20_000_000_000_000_000,
    }
    fixtures.append(fixture(
        "testflight-new-wallet",
        "Wallet created on a TestFlight build: no legacy rows, the first-migration marker, and Shown "
        "stored by the scans for every ranked utility asset (testnets included). The user hid DOT, "
        "which holds funds, and switched on ACA at zero.",
        wallet, current,
        firstMigrationMarker=True,
        firstMigrationPreferences={},
        autoShown=auto_shown,
        postUpgradeChoices=post_upgrade,
        preferences=dict(sorted(prefs.items())),
        storedPreferences=dict(sorted(stored.items())),
    ))

    return fixtures


def main():
    check = "--check" in sys.argv[1:]
    registry = load_registry()
    stale = []
    for document in build(registry):
        path = HERE / f"{document['id']}.json"
        text = json.dumps(document, indent=1, ensure_ascii=False) + "\n"
        if check:
            if not path.exists() or path.read_text() != text:
                stale.append(path.name)
        else:
            path.write_text(text)
    if stale:
        sys.exit("stale fixtures: " + ", ".join(stale))


if __name__ == "__main__":
    main()
