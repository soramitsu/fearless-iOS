#!/usr/bin/env python3
"""Synthetic service configuration generation tests; no production keys used."""

import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/ci/generate-ios-service-configuration.py"
SPEC = importlib.util.spec_from_file_location("service_configuration_generator", SCRIPT)
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)
TEMPLATE = (ROOT / "fearless/CIKeys.stencil").read_text()


class ServiceConfigurationGenerationTests(unittest.TestCase):
    def test_deployed_jenkins_ton_alias_and_identical_aliases_are_supported(self):
        for environment in [
            {"FL_IOS_TON_API_KEY": "synthetic-ton-key"},
            {"FL_TON_API_KEY": "", "FL_IOS_TON_API_KEY": "synthetic-ton-key"},
            {"FL_TON_API_KEY": "synthetic-ton-key", "FL_IOS_TON_API_KEY": "synthetic-ton-key"},
        ]:
            self.assertIn('tonApiKey: String = "synthetic-ton-key"', GENERATOR.render(TEMPLATE, environment))

    def test_conflicting_ton_aliases_are_rejected_without_disclosing_values(self):
        with self.assertRaisesRegex(ValueError, "^conflicting service environment aliases$"):
            GENERATOR.render(TEMPLATE, {"FL_TON_API_KEY": "synthetic-one", "FL_IOS_TON_API_KEY": "synthetic-two"})

    @staticmethod
    def fixture_environment():
        environment = {name: "fixture-" + name for name in GENERATOR.ARGUMENT_ENVIRONMENT.values()}
        # The Solana provider must be a usable URL; the fixture keeps its marker in the path.
        environment["FL_SOLANA_RPC_URL"] = "https://rpc.fixture.example/fixture-FL_SOLANA_RPC_URL"
        return environment

    def test_every_template_argument_uses_its_existing_environment_name(self):
        environment = self.fixture_environment()
        rendered = GENERATOR.render(TEMPLATE, environment)
        for argument, variable in GENERATOR.ARGUMENT_ENVIRONMENT.items():
            with self.subTest(argument=argument):
                self.assertIn('"' + environment[variable] + '"', rendered)
                self.assertIn("fixture-" + variable, environment[variable])
        self.assertNotIn("{{", rendered)

    def test_optional_solana_provider_is_used_only_when_the_app_would_use_it(self):
        for usable in [
            "",
            "   ",
            "https://solana-mainnet.example-provider.com/v2/synthetic-key",
            "  https://rpc.example/synthetic-key  ",
            "HTTPS://RPC.EXAMPLE/Synthetic-Key",
            "https://rpc.example:8443/synthetic-key#section",
        ]:
            with self.subTest(usable=usable):
                rendered = GENERATOR.render(TEMPLATE, {"FL_SOLANA_RPC_URL": usable})
                self.assertIn("providerURL: String = " + GENERATOR.swift_literal(usable), rendered)
        for unusable in [
            '"https://rpc.example/synthetic-key"',
            "'https://rpc.example/synthetic-key'",
            "http://rpc.example/synthetic-key",
            "https://rpc.example/?api-key=synthetic-key",
            "https://rpc.example/synthetic-key?",
            "https://",
            "https:///synthetic-key",
            "https://:443/synthetic-key",
            "https://user:synthetic-key@rpc.example/v2",
            "https://rpc.example:port/synthetic-key",
            "rpc.example/synthetic-key",
            "https://rpc.example/synthetic key",
            "ftp://rpc.example/synthetic-key",
            "https://rpc.ex\u00e4mple/synthetic-key",
        ]:
            with self.subTest(unusable=unusable):
                with self.assertRaises(GENERATOR.UnusableSolanaProviderURL) as raised:
                    GENERATOR.render(TEMPLATE, {"FL_SOLANA_RPC_URL": unusable})
                self.assertNotIn("synthetic", str(raised.exception))

    def test_cli_refuses_an_unusable_solana_provider_without_logging_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "fearless").mkdir()
            (root / "fearless/CIKeys.stencil").write_text(TEMPLATE)
            environment = {"PATH": os.environ["PATH"], "PROJECT_DIR": str(root)}
            success = subprocess.run([sys.executable, str(SCRIPT)], env=environment, capture_output=True, text=True)
            self.assertEqual(success.returncode, 0)
            prior = (root / "CIKeys.generated.swift").read_bytes()
            environment["FL_SOLANA_RPC_URL"] = '"https://rpc.example/synthetic-do-not-log"'
            failure = subprocess.run([sys.executable, str(SCRIPT)], env=environment, capture_output=True, text=True)
            self.assertEqual(failure.returncode, 1)
            self.assertIn("FL_SOLANA_RPC_URL must be an https URL", failure.stderr)
            self.assertNotIn("synthetic", failure.stdout + failure.stderr)
            self.assertEqual((root / "CIKeys.generated.swift").read_bytes(), prior)

    def test_retired_sora_card_paywings_and_x1_settings_are_not_generated(self):
        # SORA Card (with its PayWings sign-in and X1 top-up widget) was removed;
        # its credentials must not come back into signed builds. MoonPay stays.
        rendered = GENERATOR.render(TEMPLATE, self.fixture_environment())
        for retired in ["SoraCardCIKeys", "PayWingsCIKeys", "XOneCIKeys", "soraCard", "paywings", "x1"]:
            with self.subTest(retired=retired):
                self.assertNotIn(retired, TEMPLATE)
                self.assertNotIn(retired, rendered)
        for variable in GENERATOR.ARGUMENT_ENVIRONMENT.values():
            with self.subTest(variable=variable):
                self.assertFalse(variable.startswith(("SORA_CARD_", "PAY_WINGS_", "X1_")))
        self.assertEqual(
            {argument: GENERATOR.ARGUMENT_ENVIRONMENT[argument] for argument in ["moonPaySecretKey", "moonPayTestSecretKey", "moonPayPublicKey"]},
            {
                "moonPaySecretKey": "MOONPAY_PRODUCTION_SECRET",
                "moonPayTestSecretKey": "MOONPAY_TEST_SECRET",
                "moonPayPublicKey": "MOONPAY_PUBLIC_KEY",
            },
        )
        self.assertIn('enum MoonPayCIKeys {', rendered)

    def test_unset_optional_values_are_empty_not_sourcery_booleans(self):
        rendered = GENERATOR.render(TEMPLATE, {"FL_TON_API_KEY": "fixture-ton-key"})
        self.assertIn('tonApiKey: String = "fixture-ton-key"', rendered)
        self.assertIn('secretKey: String = ""', rendered)
        self.assertNotIn('"true"', rendered)
        self.assertNotIn('"false"', rendered)

    def test_swift_string_round_trip_preserves_quotes_controls_unicode_and_interpolation(self):
        value = 'synthetic,"key"=\\(fatalError())\n\r\t\x00\x7fこんにちは {{ literal }}'
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "Literal.swift"
            script.write_text("import Foundation\nlet value = " + GENERATOR.swift_literal(value) + "\nprint(Data(value.utf8).base64EncodedString())\n")
            result = subprocess.run(["swift", str(script)], capture_output=True, text=True, check=True)
        import base64
        self.assertEqual(base64.b64decode(result.stdout.strip()).decode(), value)

    def test_unknown_missing_and_unsupported_template_syntax_fail(self):
        for template in [
            TEMPLATE.replace("argument.tonApiKey ", "argument.unreviewedArgument "),
            TEMPLATE.replace('"{{ argument.tonApiKey }}"', '""'),
            TEMPLATE + "\n{% if secret %}unsupported{% endif %}",
        ]:
            with self.subTest(template=template[-40:]), self.assertRaises(ValueError):
                GENERATOR.render(template, {})

    def test_generation_is_private_atomic_and_does_not_mutate_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "fearless").mkdir()
            (root / "fearless/CIKeys.stencil").write_text(TEMPLATE)
            (root / "fearless/Info.plist").write_text("unchanged plist")
            (root / "fearless/config.xcconfig").write_text("unchanged config")
            output = root / "CIKeys.generated.swift"
            output.write_text("old output")
            GENERATOR.generate(root, {"FL_TON_API_KEY": "synthetic-token"})
            expected = output.read_text()
            self.assertIn('"synthetic-token"', expected)
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)
            self.assertEqual((root / "fearless/Info.plist").read_text(), "unchanged plist")
            self.assertEqual((root / "fearless/config.xcconfig").read_text(), "unchanged config")
            with patch.object(GENERATOR.os, "replace", side_effect=OSError("synthetic-secret")):
                with self.assertRaises(OSError):
                    GENERATOR.generate(root, {})
            self.assertEqual(output.read_text(), expected)
            self.assertEqual(list(root.glob(".CIKeys.*")), [])

    def test_identical_configuration_preserves_timestamp_and_restores_private_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "fearless").mkdir()
            (root / "fearless/CIKeys.stencil").write_text(TEMPLATE)
            GENERATOR.generate(root, {})
            output = root / "CIKeys.generated.swift"
            output.chmod(0o644)
            modified = output.stat().st_mtime_ns
            with patch.object(GENERATOR.os, "replace", side_effect=AssertionError("identical output replaced")):
                GENERATOR.generate(root, {})
            self.assertEqual(output.stat().st_mtime_ns, modified)
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)

    def test_symlink_output_is_rejected_without_changing_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "fearless").mkdir()
            (root / "fearless/CIKeys.stencil").write_text(TEMPLATE)
            target = root / "untouched"
            target.write_text("original")
            (root / "CIKeys.generated.swift").symlink_to(target)
            with self.assertRaises(ValueError):
                GENERATOR.generate(root, {})
            self.assertEqual(target.read_text(), "original")

    def test_cli_does_not_log_values_on_success_or_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "fearless").mkdir()
            template = root / "fearless/CIKeys.stencil"
            template.write_text(TEMPLATE)
            environment = {"PATH": os.environ["PATH"], "PROJECT_DIR": str(root), "FL_TON_API_KEY": "synthetic-do-not-log"}
            success = subprocess.run([sys.executable, str(SCRIPT)], env=environment, capture_output=True, text=True)
            self.assertEqual(success.returncode, 0)
            self.assertNotIn(environment["FL_TON_API_KEY"], success.stdout + success.stderr)
            prior = (root / "CIKeys.generated.swift").read_bytes()
            template.write_text("{{ argument.synthetic_do_not_log }}")
            failure = subprocess.run([sys.executable, str(SCRIPT)], env=environment, capture_output=True, text=True)
            self.assertEqual(failure.returncode, 1)
            self.assertNotIn("synthetic", failure.stdout + failure.stderr)
            self.assertEqual((root / "CIKeys.generated.swift").read_bytes(), prior)


if __name__ == "__main__":
    unittest.main()
