#!/usr/bin/env python3
"""Exercise remote data boundaries using isolated configuration documents."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("config_check", Path(__file__).with_name("verify-remote-config.py"))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class ConfigTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.config = self.root / "remote-config"
        self.config.mkdir()

    def document(self, value):
        (self.config / "data.json").write_text(json.dumps(value))

    def test_encoded_asset_path_resolves(self):
        (self.config / "asset name.svg").write_text("<svg/>")
        self.document({"nested": [{"icon": check.BASE + "asset%20name.svg"}]})
        self.assertEqual(check.validate(self.root)["ownedReferences"], 1)

    def test_missing_nested_asset_fails(self):
        self.document({"nested": [{"icon": check.BASE + "absent.svg"}]})
        with self.assertRaisesRegex(ValueError, "missing owned asset"):
            check.validate(self.root)

    def test_external_shared_host_fails(self):
        self.document({"url": "https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/a.json"})
        with self.assertRaisesRegex(ValueError, "retired config URL"):
            check.validate(self.root)

    def test_bundled_fallback_rejects_retired_host(self):
        self.document({})
        bundled = self.root / check.BUNDLED_CONFIG
        bundled.mkdir(parents=True)
        (bundled / "chains.json").write_text(json.dumps({
            "icon": "https://raw.githubusercontent.com/soramitsu/fearless-utils/master/icon.svg"
        }))
        with self.assertRaisesRegex(ValueError, "chains.json: retired config URL"):
            check.validate(self.root)

    def test_bundled_fallback_checks_owned_asset_exists(self):
        self.document({})
        bundled = self.root / check.BUNDLED_CONFIG
        bundled.mkdir(parents=True)
        (bundled / "assets.json").write_text(json.dumps({"icon": check.BASE + "missing.svg"}))
        with self.assertRaisesRegex(ValueError, "assets.json: missing owned asset"):
            check.validate(self.root)

    def test_escape_from_owned_directory_fails(self):
        (self.root / "outside.svg").write_text("<svg/>")
        self.document({"url": check.BASE + "../outside.svg"})
        with self.assertRaisesRegex(ValueError, "missing owned asset"):
            check.validate(self.root)

    def test_wrong_asset_case_fails_on_every_filesystem(self):
        (self.config / "Token.svg").write_text("<svg/>")
        self.document({"url": check.BASE + "token.svg"})
        with self.assertRaisesRegex(ValueError, "missing owned asset"):
            check.validate(self.root)

    def chain_list(self, chains):
        directory = self.config / "production" / "chains" / "v13"
        directory.mkdir(parents=True, exist_ok=True)
        (directory / "chains.json").write_text(json.dumps(chains))

    def hub(self, staking="assetHub", asset_id=None, options=None):
        chain_id = "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f"
        asset = {"id": asset_id or check.ASSET_HUB_NATIVE[chain_id], "staking": staking}
        return {"chainId": chain_id, "assets": [asset], "options": options or ["utilityFeePayment"]}

    def test_asset_hub_native_staking_passes(self):
        self.chain_list([self.hub(), {"chainId": "other", "assets": [{"id": "x", "staking": "relaychain"}]}])
        self.assertEqual(check.validate(self.root)["documents"], 1)

    def test_relay_staking_on_a_hub_fails(self):
        self.chain_list([self.hub(staking="relaychain")])
        with self.assertRaisesRegex(ValueError, "stakes only its native token as assetHub"):
            check.validate(self.root)

    def test_hub_staking_on_another_asset_fails(self):
        self.chain_list([self.hub(asset_id="usdt")])
        with self.assertRaisesRegex(ValueError, "stakes only its native token as assetHub"):
            check.validate(self.root)

    def test_staking_on_a_migrated_relay_fails(self):
        relay = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        self.chain_list([{"chainId": relay, "assets": [{"id": "dot", "staking": "relaychain"}]}])
        with self.assertRaisesRegex(ValueError, "moved to its Asset Hub"):
            check.validate(self.root)

    def test_pool_staking_on_a_hub_fails(self):
        self.chain_list([self.hub(options=["poolStaking"])])
        with self.assertRaisesRegex(ValueError, "no pool staking or crowdloans"):
            check.validate(self.root)

    def test_asset_hub_value_outside_the_routes_fails(self):
        self.chain_list([{"chainId": "other", "assets": [{"id": "x", "staking": "assetHub"}]}])
        with self.assertRaisesRegex(ValueError, "not an Asset Hub route"):
            check.validate(self.root)

    def test_invalid_json_fails(self):
        (self.config / "data.json").write_text('{"invalid":')
        with self.assertRaises(ValueError):
            check.validate(self.root)


if __name__ == "__main__":
    unittest.main()
