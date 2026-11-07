#!/usr/bin/env python3
"""Exercise remote data boundaries using isolated configuration documents."""
import hashlib
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
        self.pins([])

    def document(self, value):
        (self.config / "data.json").write_text(json.dumps(value))

    def pins(self, sources):
        manifest = self.root / check.IMPORTS
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(json.dumps({"schemaVersion": 1, "sources": sources}))

    def pin(self, path, file=None):
        data = (file or self.config / path).read_bytes()
        return {"path": path, "ownedSha256": hashlib.sha256(data).hexdigest()}

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

    def chain_list(self, chains, path="production/chains/v13/chains.json"):
        file = self.config / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(json.dumps(chains))

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

    def test_repeated_chain_id_fails_in_every_versioned_list(self):
        repeated = [{"chainId": "b91746b4e0"}, {"chainId": "other"}, {"chainId": "b91746b4e0"}]
        for path in ("development/chains/v13/chains_dev.json", "production/chains/v13/chains.json",
                     "development/chains/v9/chains_dev.json", "production/chains/v2/chains.json"):
            with self.subTest(path=path):
                for stale in self.config.rglob("*.json"):
                    stale.unlink()
                self.chain_list(repeated, path)
                with self.assertRaisesRegex(ValueError, path + ": chainId b91746b4 is listed more than once"):
                    check.validate(self.root)

    def test_distinct_chain_ids_pass(self):
        self.chain_list([{"chainId": "a"}, {"chainId": "b"}], "development/chains/v13/chains_dev.json")
        self.assertEqual(check.validate(self.root)["documents"], 1)

    def test_repeated_chain_id_fails_in_chain_types(self):
        repeated = [{"chainId": "6d8d9f145c", "runtime_id": 1}, {"chainId": "6d8d9f145c", "runtime_id": 14}]
        for path in ("production/chains/all_chains_types.json", "development/chains/all_chains_types.json"):
            with self.subTest(path=path):
                for stale in self.config.rglob("*.json"):
                    stale.unlink()
                self.chain_list(repeated, path)
                with self.assertRaisesRegex(ValueError, path + ": chainId 6d8d9f14 is listed more than once"):
                    check.validate(self.root)

    def test_repeated_chain_id_fails_in_bundled_fallbacks(self):
        self.document({})
        bundled = self.root / check.BUNDLED_CONFIG
        bundled.mkdir(parents=True)
        for name in ("chains.json", "types.json"):
            with self.subTest(name=name):
                for stale in bundled.glob("*.json"):
                    stale.unlink()
                (bundled / name).write_text(json.dumps([{"chainId": "169"}, {"chainId": "a"}, {"chainId": "169"}]))
                with self.assertRaisesRegex(ValueError, "Resources/" + name + ": chainId 169 is listed more than once"):
                    check.validate(self.root)

    def test_distinct_chain_ids_pass_in_chain_types_and_fallbacks(self):
        self.chain_list([{"chainId": "a"}, {"chainId": "b"}], "production/chains/all_chains_types.json")
        bundled = self.root / check.BUNDLED_CONFIG
        bundled.mkdir(parents=True)
        for name in ("chains.json", "types.json"):
            (bundled / name).write_text(json.dumps([{"chainId": "a"}, {"chainId": "b"}]))
        self.assertEqual(check.validate(self.root)["documents"], 3)

    def test_chain_ids_may_repeat_in_other_documents(self):
        self.chain_list([{"chainId": "a"}, {"chainId": "a"}], "production/xcm/v2/xcm_fees.json")
        self.assertEqual(check.validate(self.root)["documents"], 1)

    def test_matching_pins_pass(self):
        self.document({"a": 1})
        (self.config / "icons").mkdir()
        (self.config / "icons" / "dot.svg").write_text("<svg/>")
        self.pins([self.pin("data.json"), self.pin("icons/dot.svg")])
        self.assertEqual(check.validate(self.root)["pinnedFiles"], 2)

    def test_edit_without_a_new_pin_fails(self):
        self.document({"a": 1})
        self.pins([self.pin("data.json")])
        self.document({"a": 2})
        with self.assertRaisesRegex(ValueError, "remote-config/data.json has SHA-256 [0-9a-f]{64}, pinned [0-9a-f]{64}"):
            check.validate(self.root)

    def test_pinned_file_that_is_gone_fails(self):
        self.document({})
        self.pins([self.pin("data.json"), {"path": "chains/gone.json", "ownedSha256": "0" * 64}])
        with self.assertRaisesRegex(ValueError, "pinned file remote-config/chains/gone.json is missing"):
            check.validate(self.root)

    def test_pin_outside_remote_config_fails(self):
        self.document({})
        outside = self.root / "outside.json"
        outside.write_text("{}")
        self.pins([self.pin("../outside.json", outside)])
        with self.assertRaisesRegex(ValueError, r"pinned file remote-config/\.\./outside.json is missing"):
            check.validate(self.root)

    def test_pin_with_the_wrong_case_fails_on_every_filesystem(self):
        (self.config / "Token.svg").write_text("<svg/>")
        self.document({})
        self.pins([self.pin("token.svg", self.config / "Token.svg")])
        with self.assertRaisesRegex(ValueError, "pinned file remote-config/token.svg is missing"):
            check.validate(self.root)

    def test_malformed_pin_fails(self):
        self.document({})
        digest = self.pin("data.json")["ownedSha256"]
        for entry in ({"ownedSha256": digest}, {"path": "data.json"}, {"path": "data.json", "ownedSha256": digest[:63]},
                      {"path": "data.json", "ownedSha256": digest.upper()}, "data.json"):
            with self.subTest(entry=entry):
                self.pins([entry])
                with self.assertRaisesRegex(ValueError, "malformed pin"):
                    check.validate(self.root)

    def test_file_pinned_twice_fails(self):
        self.document({})
        self.pins([self.pin("data.json"), self.pin("data.json")])
        with self.assertRaisesRegex(ValueError, "remote-config/data.json is pinned more than once"):
            check.validate(self.root)

    def test_missing_or_unreadable_manifest_fails(self):
        self.document({})
        manifest = self.root / check.IMPORTS
        for content in (None, '{"sources":', '{"schemaVersion": 1}', '{"sources": {}}', "[]"):
            with self.subTest(content=content):
                if content is None:
                    manifest.unlink()
                else:
                    manifest.write_text(content)
                with self.assertRaisesRegex(ValueError, "config/remote-config-imports.json: cannot read the pins"):
                    check.validate(self.root)

    def test_invalid_json_fails(self):
        (self.config / "data.json").write_text('{"invalid":')
        with self.assertRaises(ValueError):
            check.validate(self.root)


if __name__ == "__main__":
    unittest.main()
