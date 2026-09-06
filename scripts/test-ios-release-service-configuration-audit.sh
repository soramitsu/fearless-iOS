#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PYTHONDONTWRITEBYTECODE=1 python3 - "$SCRIPT_DIR/.." <<'PY'
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
REPO = Path(sys.argv.pop()).resolve()


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, REPO / 'scripts/ci' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


A = load('audit', 'audit-ios-release-service-configuration.py')
I = load('inject', 'inject-ios-google-service-configuration.py')
TEMPLATE = (REPO / 'fearless/CIKeys.stencil').read_bytes()
SCHEMA = A.parse_declarations(TEMPLATE, template=True)
NATIVE_CLIENT = '123456789-nativeSyntheticId.apps.googleusercontent.com'
WEB_CLIENT = '987654321-webSyntheticId.apps.googleusercontent.com'
SCHEME = 'com.googleusercontent.apps.123456789-nativeSyntheticId'


def values():
    result = {field: hashlib.sha256(field.encode()).hexdigest() if field in A.REQUIRED else '' for field in SCHEMA}
    result['WalletConnect.projectId'] = 'abc012340123456789abcdef12345678'
    result['GoogleBackup.googleToken'] = WEB_CLIENT
    result['GoogleBackup.googleUrlScheme'] = SCHEME
    return result


def generated(fields):
    groups = {}
    for name, value in fields.items():
        enum, field = name.split('.')
        groups.setdefault(enum, []).append('    static var ' + field + ': String = ' + json.dumps(value))
    return ('// Synthetic service fixtures only\n' + '\n\n'.join('enum ' + enum + ' {\n' + '\n'.join(rows) + '\n}' for enum, rows in groups.items()) + '\n').encode()


def info():
    return {'CFBundleURLTypes': [{'CFBundleURLSchemes': ['fearless', 'tonkeeper', 'tc']}], 'GIDClientID': ''}


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='fearless-config-audit-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'fearless').mkdir()
        (self.root / 'fearless/CIKeys.stencil').write_bytes(TEMPLATE)
        (self.root / 'fearless/Info.plist').write_bytes(plistlib.dumps(info()))
        self.fields = values()
        self.generated = self.root / 'CIKeys.generated.swift'
        self.generated.write_bytes(generated(self.fields))
        self.receipt = self.root / 'before.json'
        self.archive = self.root / 'archive.xcarchive'
        self.app = self.archive / 'Products/Applications/fearless.app'
        self.app.mkdir(parents=True)
        self.plist = self.app / 'Info.plist'
        self.plist.write_bytes(plistlib.dumps(info()))

    def test_valid_preflight_allows_empty_source_plist_and_optional_settings(self):
        result = A.audit(self.root)
        self.assertEqual(42, len(result['fields']))
        self.assertEqual(len(A.REQUIRED), sum(f['required'] for f in result['fields'].values()))
        self.assertTrue(all(not row['present'] and row['sha256'] is None for name, row in result['fields'].items() if name not in A.REQUIRED))
        encoded = json.dumps(result)
        for value in self.fields.values():
            if value:
                self.assertNotIn(value, encoded)
        self.assertEqual(A.sha256(self.generated.read_bytes()), result['generatedSourceSha256'])

    def test_every_required_setting_rejects_missing_empty_and_boolean_placeholders(self):
        for field in sorted(A.REQUIRED):
            for value in ('', 'true', 'false', 'YES', 'No', 'null', '{{ argument.secret }}', 'YOUR_API_KEY', 'dummy', 'changeme'):
                with self.subTest(field=field, value=value):
                    candidate = self.fields | {field: value}
                    with self.assertRaises(A.AuditFailure):
                        A.validate_values(candidate, SCHEMA)
            with self.subTest(field=field, missing=True):
                candidate = dict(self.fields)
                del candidate[field]
                with self.assertRaises(A.AuditFailure):
                    A.validate_values(candidate, SCHEMA)

    def test_retired_blast_credentials_are_optional_after_provider_removal(self):
        retired = [name for name in SCHEMA if name.startswith('EthereumNodesApiKeys.')]
        self.assertEqual(5, len(retired))
        self.assertFalse(A.REQUIRED.intersection(retired))
        A.validate_values(self.fields | {name: '' for name in retired}, SCHEMA)
        source = (REPO / 'fearless/Common/Helpers/EthereumNodeFetching.swift').read_text()
        self.assertNotIn('EthereumNodesApiKeys', source)
        self.assertNotIn('appendingPathComponent', source)

    def test_dwellir_is_optional_with_catalog_connection_fallback(self):
        field = 'DwellirNodeApiKey.dwellirApiKey'
        self.assertNotIn(field, A.REQUIRED)
        A.validate_values(self.fields | {field: ''}, SCHEMA)

    def test_oklink_is_optional_with_replacement_providers_and_explorer_recovery(self):
        field = 'BlockExplorerApiKeys.oklinkApiKey'
        self.assertNotIn(field, A.REQUIRED)
        A.validate_values(self.fields | {field: ''}, SCHEMA)

    def test_optional_placeholders_are_rejected_but_real_optional_values_are_allowed(self):
        for field in SCHEMA.keys() - A.REQUIRED:
            with self.subTest(field=field):
                with self.assertRaises(A.AuditFailure):
                    A.validate_values(self.fields | {field: 'false'}, SCHEMA)
                A.validate_values(self.fields | {field: 'synthetic-optional-value'}, SCHEMA)

    def test_whitespace_controls_short_and_invalid_identifiers(self):
        cases = [
            ('TonNodeApiKey.tonApiKey', '  real-looking-secret'),
            ('TonNodeApiKey.tonApiKey', 'real-looking-secret\n'),
            ('TonNodeApiKey.tonApiKey', 'value\x00secret'),
            ('TonNodeApiKey.tonApiKey', 'short'),
            ('WalletConnect.projectId', 'a-valid-looking-but-nonhex-project'),
            ('GoogleBackup.googleToken', '1234567-wrong-provider.example.com'),
            ('GoogleBackup.googleUrlScheme', 'not-the-google-callback'),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                with self.assertRaises(A.AuditFailure):
                    A.validate_values(self.fields | {field: value}, SCHEMA)

    def test_parser_rejects_executable_duplicate_incomplete_and_conditional_declarations(self):
        baseline = self.generated.read_text()
        first = next(line for line in baseline.splitlines() if 'static var' in line)
        mutations = [
            baseline.replace(first, first + '\n' + first, 1),
            baseline + '\nenum WalletConnect {\n}\n',
            baseline + '\nprint("synthetic-private-value")\n',
            baseline.replace(first, '    static var stolen: String = ProcessInfo.processInfo.environment["TOKEN"]!', 1),
            baseline.replace(first, '    static var stolen: String = "\\(dangerous())"', 1),
            baseline.replace(first, '    static var stolen: String = true', 1),
            '#if DEBUG\n' + baseline + '\n#endif',
            baseline.rsplit('}', 1)[0],
        ]
        for number, candidate in enumerate(mutations):
            with self.subTest(number=number):
                with self.assertRaises(A.AuditFailure):
                    A.parse_declarations(candidate.encode())

    def test_unknown_or_comment_only_declaration_cannot_satisfy_schema(self):
        for candidate in (self.fields | {'Unexpected.secret': 'synthetic-secret'}, {k: v for k, v in self.fields.items() if k != 'TonNodeApiKey.tonApiKey'}):
            with self.assertRaises(A.AuditFailure):
                A.validate_values(candidate, SCHEMA)

    def test_literal_escaped_quote_backslash_is_read_without_evaluation(self):
        self.fields['MoonPayCIKeys.secretKey'] = 'safe-quote-"-backslash-\\-literal'
        parsed = A.parse_declarations(generated(self.fields))
        self.assertEqual(self.fields, parsed)
        A.validate_values(parsed, SCHEMA)

    def test_generated_symlink_missing_and_invalid_utf8_rejected(self):
        original = self.generated.read_bytes()
        self.generated.unlink()
        with self.assertRaises(A.AuditFailure):
            A.audit(self.root)
        target = self.root / 'elsewhere.swift'
        target.write_bytes(original)
        self.generated.symlink_to(target)
        with self.assertRaises(A.AuditFailure):
            A.audit(self.root)
        self.generated.unlink()
        self.generated.write_bytes(b'\xff')
        with self.assertRaises(UnicodeError):
            A.audit(self.root)

    def test_unchanged_configuration_receipt_passes_and_valid_rotation_during_build_fails(self):
        A.write_receipt(self.receipt, A.audit(self.root))
        self.assertEqual(0o600, self.receipt.stat().st_mode & 0o777)
        A.audit(self.root, expected_receipt=self.receipt)
        self.fields['TonNodeApiKey.tonApiKey'] = 'synthetic-but-different-service-value'
        self.generated.write_bytes(generated(self.fields))
        with self.assertRaisesRegex(A.AuditFailure, 'changed during'):
            A.audit(self.root, expected_receipt=self.receipt)

    def test_template_or_generator_header_drift_during_build_fails(self):
        A.write_receipt(self.receipt, A.audit(self.root))
        self.generated.write_bytes(b'// changed generator version\n' + self.generated.read_bytes())
        with self.assertRaisesRegex(A.AuditFailure, 'changed during'):
            A.audit(self.root, expected_receipt=self.receipt)

    def test_receipt_cannot_overwrite_or_follow_symlink(self):
        result = A.audit(self.root)
        A.write_receipt(self.receipt, result)
        original = self.receipt.read_bytes()
        with self.assertRaises(FileExistsError):
            A.write_receipt(self.receipt, result)
        link = self.root / 'link.json'
        link.symlink_to(self.receipt)
        with self.assertRaises(FileExistsError):
            A.write_receipt(link, result)
        self.assertEqual(original, self.receipt.read_bytes())
        with self.assertRaises(A.AuditFailure):
            A.audit(self.root, expected_receipt=link)

    def test_malformed_or_empty_receipt_fails(self):
        for data in (b'{broken', b'{}'):
            self.receipt.write_bytes(data)
            with self.assertRaises(A.AuditFailure):
                A.audit(self.root, expected_receipt=self.receipt)

    def test_archive_google_callback_binding_accepts_distinct_native_and_web_client(self):
        built = info()
        built['GIDClientID'] = NATIVE_CLIENT
        built['CFBundleURLTypes'].append({'CFBundleURLSchemes': [SCHEME]})
        self.plist.write_bytes(plistlib.dumps(built))
        A.write_receipt(self.receipt, A.audit(self.root))
        result = A.audit(self.root, self.archive, self.receipt)
        self.assertEqual(A.sha256(NATIVE_CLIENT.encode()), result['archivedGoogleIdentity']['clientIdSha256'])
        self.assertNotIn(NATIVE_CLIENT, json.dumps(result))

    def test_archive_missing_wrong_duplicate_and_unbound_google_identity_fail(self):
        cases = []
        base = info()
        cases.append(base)
        for native, schemes in ((WEB_CLIENT, [SCHEME]), (NATIVE_CLIENT, [SCHEME, SCHEME]), (NATIVE_CLIENT, ['com.googleusercontent.apps.111-other']), ('true', [SCHEME])):
            candidate = info()
            candidate['GIDClientID'] = native
            candidate['CFBundleURLTypes'].append({'CFBundleURLSchemes': schemes})
            cases.append(candidate)
        for candidate in cases:
            with self.subTest(candidate=candidate):
                with self.assertRaises(A.AuditFailure):
                    A.validate_built_plist(plistlib.dumps(candidate), SCHEME)
        for data in (b'broken', plistlib.dumps({'CFBundleURLTypes': 'bad-structure'})):
            with self.assertRaises(A.AuditFailure):
                A.validate_built_plist(data, SCHEME)

    def test_cli_never_logs_setting_values_on_success_or_failure(self):
        scripts = self.root / 'scripts/ci'
        scripts.mkdir(parents=True)
        script = scripts / 'audit-ios-release-service-configuration.py'
        shutil.copyfile(REPO / 'scripts/ci' / script.name, script)
        for bad in (False, True):
            if bad:
                self.fields['TonNodeApiKey.tonApiKey'] = 'Sensitive-Marker-Should-Never-Be-Logged\n'
                self.generated.write_bytes(generated(self.fields))
            result = subprocess.run([sys.executable, str(script)], text=True, capture_output=True)
            self.assertEqual(1 if bad else 0, result.returncode)
            for value in self.fields.values():
                if value:
                    self.assertNotIn(value.strip(), result.stdout + result.stderr)


class InjectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='fearless-google-config-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.built = self.root / 'build'
        self.app = self.built / 'fearless.app'
        self.app.mkdir(parents=True)
        self.plist = self.app / 'Info.plist'
        self.plist.write_bytes(plistlib.dumps(info()))
        self.env = {'CONFIGURATION': 'Release', 'ACTION': 'install', 'BUILT_PRODUCTS_DIR': str(self.built), 'INFOPLIST_PATH': 'fearless.app/Info.plist', 'GOOGLE_CLIENT_ID': NATIVE_CLIENT, 'GOOGLE_URL_SCHEME': SCHEME}

    def test_injection_changes_only_built_plist_and_preserves_all_other_url_schemes(self):
        source = self.root / 'fearless'
        (source / 'Configs').mkdir(parents=True)
        (source / 'Info.plist').write_bytes(plistlib.dumps(info()))
        (source / 'Configs/Release.xcconfig').write_text('SOURCE_CONFIGURATION = unchanged\n')
        snapshot = {str(p): p.read_bytes() for p in source.rglob('*') if p.is_file()}
        I.inject(self.env)
        output = plistlib.loads(self.plist.read_bytes())
        self.assertEqual(NATIVE_CLIENT, output['GIDClientID'])
        schemes = [s for row in output['CFBundleURLTypes'] for s in row['CFBundleURLSchemes']]
        self.assertEqual(['fearless', 'tonkeeper', 'tc', SCHEME], schemes)
        self.assertEqual(snapshot, {str(p): p.read_bytes() for p in source.rglob('*') if p.is_file()})
        A.validate_built_plist(self.plist.read_bytes(), SCHEME)

    def test_binary_plist_format_and_mode_preserved_and_repeated_injection_is_identical(self):
        self.plist.write_bytes(plistlib.dumps(info(), fmt=plistlib.FMT_BINARY))
        self.plist.chmod(0o644)
        I.inject(self.env)
        first = self.plist.read_bytes()
        self.assertTrue(first.startswith(b'bplist'))
        self.assertEqual(0o644, self.plist.stat().st_mode & 0o777)
        I.inject(self.env)
        self.assertEqual(first, self.plist.read_bytes())

    def test_archive_target_directory_accepts_products_app_symlink_without_source_writes(self):
        target = self.root / 'InstallationBuildProductsLocation/Applications'
        target.mkdir(parents=True)
        source = self.root / 'fearless/Info.plist'
        source.parent.mkdir()
        source.write_bytes(plistlib.dumps(info()))
        before = source.read_bytes()
        installed_app = target / self.app.name
        self.app.rename(installed_app)
        self.app.symlink_to(installed_app, target_is_directory=True)
        self.assertTrue(I.inject(self.env | {'TARGET_BUILD_DIR': str(target)}))
        A.validate_built_plist((installed_app / 'Info.plist').read_bytes(), SCHEME)
        self.assertTrue(self.app.is_symlink())
        self.assertEqual(before, source.read_bytes())

    def test_target_directory_rejects_escaping_paths_and_app_symlink_without_falling_back(self):
        target = self.root / 'InstallationBuildProductsLocation/Applications'
        target.mkdir(parents=True)
        source_app = self.root / 'source/fearless.app'
        source_app.mkdir(parents=True)
        source = source_app / 'Info.plist'
        source.write_bytes(plistlib.dumps(info()))
        (target / 'fearless.app').symlink_to(source_app, target_is_directory=True)
        before = source.read_bytes()
        built_before = self.plist.read_bytes()
        for relative in ('../../source/fearless.app/Info.plist', str(source), 'fearless.app/Info.plist'):
            with self.assertRaises(I.audit.AuditFailure):
                I.inject(self.env | {'TARGET_BUILD_DIR': str(target), 'INFOPLIST_PATH': relative})
        self.assertEqual(before, source.read_bytes())
        self.assertEqual(built_before, self.plist.read_bytes())

    def test_missing_explicit_target_directory_does_not_fall_back_to_products(self):
        before = self.plist.read_bytes()
        with self.assertRaises(FileNotFoundError):
            I.inject(self.env | {'TARGET_BUILD_DIR': str(self.root / 'missing-target')})
        self.assertEqual(before, self.plist.read_bytes())

    def test_explicit_environment_wins_over_legacy_file_variables(self):
        env = self.env | {'google_client_id': WEB_CLIENT, 'google_url_scheme': 'com.googleusercontent.apps.987654321-webSyntheticId'}
        I.inject(env)
        A.validate_built_plist(self.plist.read_bytes(), SCHEME)

    def test_legacy_environment_aliases_are_supported(self):
        for client_key, scheme_key in (('FEARLESS_GOOGLE_TOKEN', 'FEARLESS_GOOGLE_URL_SCHEME'), ('google_client_id', 'google_url_scheme')):
            candidate = {k: v for k, v in self.env.items() if k not in ('GOOGLE_CLIENT_ID', 'GOOGLE_URL_SCHEME')}
            candidate.update({client_key: NATIVE_CLIENT, scheme_key: SCHEME})
            I.inject(candidate)
            A.validate_built_plist(self.plist.read_bytes(), SCHEME)

    def test_missing_release_config_fails_without_changing_product_debug_can_skip(self):
        env = {k: v for k, v in self.env.items() if k not in ('GOOGLE_CLIENT_ID', 'GOOGLE_URL_SCHEME')}
        before = self.plist.read_bytes()
        with self.assertRaises(I.audit.AuditFailure):
            I.inject(env)
        self.assertFalse(I.inject(env | {'CONFIGURATION': 'Debug'}))
        self.assertFalse(I.inject(env | {'ACTION': 'build'}))
        self.assertFalse(I.inject(env | {'ACTION': 'test'}))
        self.assertEqual(before, self.plist.read_bytes())

    def test_mismatched_client_or_scheme_fails_before_any_write(self):
        before = self.plist.read_bytes()
        for candidate in (self.env | {'GOOGLE_CLIENT_ID': WEB_CLIENT}, self.env | {'GOOGLE_URL_SCHEME': 'true'}, self.env | {'GOOGLE_CLIENT_ID': 'true'}):
            with self.assertRaises(I.audit.AuditFailure):
                I.inject(candidate)
            self.assertEqual(before, self.plist.read_bytes())

    def test_path_traversal_absolute_and_symlink_cannot_write_source(self):
        outside = self.root / 'Info.plist'
        outside.write_bytes(plistlib.dumps(info()))
        for relative in ('../Info.plist', str(outside)):
            with self.assertRaises(I.audit.AuditFailure):
                I.inject(self.env | {'INFOPLIST_PATH': relative})
        self.plist.unlink()
        self.plist.symlink_to(outside)
        with self.assertRaises(I.audit.AuditFailure):
            I.inject(self.env)
        self.assertEqual('', plistlib.loads(outside.read_bytes())['GIDClientID'])

    def test_failed_atomic_replace_preserves_original_and_removes_temp(self):
        before = self.plist.read_bytes()
        with mock.patch.object(I.os, 'replace', side_effect=OSError('synthetic write failure')):
            with self.assertRaises(OSError):
                I.inject(self.env)
        self.assertEqual(before, self.plist.read_bytes())
        self.assertEqual([self.plist], list(self.app.iterdir()))

    def test_injection_cli_redacts_bad_configuration(self):
        env = os.environ | self.env | {'GOOGLE_CLIENT_ID': 'Sensitive-Marker-Should-Never-Be-Logged'}
        result = subprocess.run([sys.executable, str(REPO / 'scripts/ci/inject-ios-google-service-configuration.py')], env=env, text=True, capture_output=True)
        self.assertEqual(1, result.returncode)
        self.assertNotIn(env['GOOGLE_CLIENT_ID'], result.stdout + result.stderr)


class BuildWiringTests(unittest.TestCase):
    def test_project_uses_helpers_exports_ignored_env_and_never_rewrites_sources(self):
        project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(REPO / 'fearless.xcodeproj/project.pbxproj')]))
        objects = project['objects']
        self.assertEqual(['${TARGET_BUILD_DIR}/${INFOPLIST_PATH}'], objects['FAD429442A8A1A74001D6A16']['inputPaths'])
        expected = {'AE2060202636DA5900357578': 'generate-ios-service-configuration.py', 'FAD429442A8A1A74001D6A16': 'inject-ios-google-service-configuration.py'}
        for identity, helper in expected.items():
            phase = objects[identity]
            script = phase['shellScript']
            self.assertIn('python3 "$PROJECT_DIR/scripts/ci/' + helper + '"', script)
            self.assertIn('set -a', script)
            self.assertIn('. "$PROJECT_DIR/$PROJECT_NAME/env-vars.sh"', script)
            self.assertEqual('0', str(phase['showEnvVarsInLog']))
            self.assertEqual('1', str(phase['alwaysOutOfDate']))
            for forbidden in ('PlistBuddy', '/fearless/Info.plist', '/Configs/', '--args', 'sourcery'):
                self.assertNotIn(forbidden, script)
            subprocess.run(['/bin/sh', '-n'], input=script, text=True, check=True)

    def test_actual_project_phases_generate_and_inject_without_source_mutations_or_secret_logs(self):
        generator = load('generator', 'generate-ios-service-configuration.py')
        project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(REPO / 'fearless.xcodeproj/project.pbxproj')]))
        with tempfile.TemporaryDirectory(prefix='fearless-config-phases-') as directory:
            root = Path(directory)
            scripts = root / 'scripts/ci'
            scripts.mkdir(parents=True)
            for name in ('generate-ios-service-configuration.py', 'inject-ios-google-service-configuration.py', 'audit-ios-release-service-configuration.py'):
                shutil.copyfile(REPO / 'scripts/ci' / name, scripts / name)
            (root / 'fearless/Configs').mkdir(parents=True)
            (root / 'fearless/CIKeys.stencil').write_bytes(TEMPLATE)
            (root / 'fearless/Info.plist').write_bytes(plistlib.dumps(info()))
            (root / 'fearless/Configs/Release.xcconfig').write_text('UNCHANGED = yes\n')
            fields, private_environment, enum = values(), {}, None
            for line in TEMPLATE.decode().splitlines():
                match = re.match(r'enum (\w+) \{', line)
                if match:
                    enum = match[1]
                field = re.search(r'static var (\w+): String = "\{\{ argument\.(\w+) \}\}"', line)
                if field and enum + '.' + field[1] in A.REQUIRED:
                    private_environment[generator.ARGUMENT_ENVIRONMENT[field[2]]] = fields[enum + '.' + field[1]]
            private_environment.update(GOOGLE_CLIENT_ID=NATIVE_CLIENT, GOOGLE_URL_SCHEME=SCHEME)
            # Deliberately omit export: the project phases must export sourced values.
            (root / 'fearless/env-vars.sh').write_text(''.join(key + '=' + shlex.quote(value) + '\n' for key, value in private_environment.items()))
            tracked = [root / 'fearless/CIKeys.stencil', root / 'fearless/Info.plist', root / 'fearless/Configs/Release.xcconfig']
            before = {str(p): p.read_bytes() for p in tracked}
            archive = root / 'archive.xcarchive'
            app = archive / 'Products/Applications/fearless.app'
            app.mkdir(parents=True)
            (app / 'Info.plist').write_bytes(plistlib.dumps(info()))
            products = root / 'BuildProductsPath/Release-iphoneos'
            products.mkdir(parents=True)
            (products / 'fearless.app').symlink_to(app, target_is_directory=True)
            env = {'PATH': os.environ['PATH'], 'PROJECT_DIR': str(root), 'PROJECT_NAME': 'fearless', 'PODS_ROOT': str(root / 'Pods'), 'CONFIGURATION': 'Release', 'ACTION': 'install', 'BUILT_PRODUCTS_DIR': str(products), 'TARGET_BUILD_DIR': str(app.parent), 'INFOPLIST_PATH': 'fearless.app/Info.plist'}
            for identity in ('AE2060202636DA5900357578', 'FAD429442A8A1A74001D6A16'):
                phase = project['objects'][identity]['shellScript']
                result = subprocess.run(['/bin/sh', '-c', phase], env=env, text=True, capture_output=True)
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                for value in private_environment.values():
                    self.assertNotIn(value, result.stdout + result.stderr)
            self.assertEqual(before, {str(p): p.read_bytes() for p in tracked})
            A.audit(root, archive=archive)
            self.assertEqual([], list(scripts.rglob('__pycache__')))

    def test_archive_requires_pre_and_post_generated_bytes_and_built_plist(self):
        script = (REPO / 'scripts/ci/build-audited-ios-release-archive.sh').read_text()
        command = 'python3 "$SCRIPT_DIR/audit-ios-release-service-configuration.py"'
        self.assertEqual(2, script.count(command))
        before, after = [m.start() for m in re.finditer(re.escape(command), script)]
        archive = script.index('xcodebuild "${xcodebuild_arguments[@]}"')
        signed = script.index('bash "$SCRIPT_DIR/audit-ios-signed-release-artifact.sh"')
        self.assertLess(before, archive)
        self.assertLess(archive, after)
        self.assertLess(after, signed)
        post = script[after:script.index('bash "$SCRIPT_DIR/materialize', after)]
        self.assertIn('--expected-receipt "$service_configuration_before"', post)
        self.assertIn('--archive "$archive"', post)
        self.assertIn('--receipt "$service_configuration_after"', post)


unittest.main(verbosity=2)
PY
