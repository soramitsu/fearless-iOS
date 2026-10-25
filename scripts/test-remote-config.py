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

    def test_invalid_json_fails(self):
        (self.config / "data.json").write_text('{"invalid":')
        with self.assertRaises(ValueError):
            check.validate(self.root)


if __name__ == "__main__":
    unittest.main()
