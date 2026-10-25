#!/usr/bin/env python3
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('guard', Path(__file__).with_name('check-raw-colours.py'))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
SOURCE_PATH = 'fearless/Modules/Fixture.swift'
COLOUR = 'let ink = UIColor(red: 1, green: 0, blue: 0, alpha: 1)'


class RawColourRatchetTests(unittest.TestCase):
    def fixture(self, source=COLOUR):
        temp = tempfile.TemporaryDirectory(prefix='ios-colour-fixture-')
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / SOURCE_PATH).parent.mkdir(parents=True)
        (root / SOURCE_PATH).write_text(source)
        guard.git(root, 'init', '-q')
        self.commit(root)
        baseline = {'schemaVersion': 1, 'sourceCommit': guard.resolved_commit(root, 'HEAD'),
                    'sites': guard.raw_colour_sites(SOURCE_PATH, source)}
        self.save_baseline(root, baseline)
        return root, baseline

    def commit(self, root):
        guard.git(root, 'add', '.')
        guard.git(root, '-c', 'user.name=Public fixture', '-c', 'user.email=fixture@example.invalid',
                  '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture')

    def save_baseline(self, root, baseline):
        (root / guard.BASELINE_PATH).parent.mkdir(exist_ok=True)
        (root / guard.BASELINE_PATH).write_text(json.dumps(baseline))

    def test_current_production_matches_every_exact_exception(self):
        root = Path(__file__).resolve().parents[1]
        baseline = guard.parse_baseline(json.loads((root / guard.BASELINE_PATH).read_text()))
        self.assertEqual(guard.compare_sites(guard.scan_raw_colours(root), baseline['sites']),
                         {'added': [], 'stale': []})

    def test_multiline_nested_arguments_and_hex_are_complete(self):
        source = ('let ink = UIColor(\n red: min(1, value),\n green: .5, blue: 0, alpha: 1)\n'
                  'let other = UIColor ( hex: "#AABBCC" )\n')
        sites = guard.raw_colour_sites(SOURCE_PATH, source)
        self.assertEqual(sum(row['count'] for row in sites), 2)
        changed = guard.raw_colour_sites(SOURCE_PATH, source.replace('green: .5', 'green: .6'))
        self.assertEqual(len(guard.compare_sites(changed, sites)['added']), 1)
        self.assertIn('green: .5', sites[0]['source'])

    def test_exempts_only_exact_theme_folder_and_only_requested_initializers(self):
        self.assertEqual(guard.raw_colour_sites('fearless/Common/DesignSystem/Test.swift', COLOUR), [])
        self.assertEqual(len(guard.raw_colour_sites('fearless/Common/DesignSystemOther/Test.swift', COLOUR)), 1)
        self.assertEqual(guard.raw_colour_sites(SOURCE_PATH, 'HexColorConverter.hexStringToUIColor(hex: dynamic)'), [])
        self.assertEqual(guard.raw_colour_sites(SOURCE_PATH, 'let x = UIColor(named: "FWText1")'), [])

    def test_quoted_parentheses_and_multiple_same_line_calls(self):
        source = 'let x = [UIColor(hex: "#abc)"), UIColor(hex: "#def") ]'
        sites = guard.raw_colour_sites(SOURCE_PATH, source)
        self.assertEqual(len(sites), 1)
        self.assertEqual(sites[0]['count'], 2)
        guard.parse_baseline({'schemaVersion': 1, 'sourceCommit': 'a' * 40, 'sites': sites})

    def test_comments_are_intentionally_counted_and_unclosed_calls_fail(self):
        self.assertEqual(len(guard.raw_colour_sites(SOURCE_PATH, '// ' + COLOUR)), 1)
        with self.assertRaisesRegex(ValueError, 'Unclosed'):
            guard.raw_colour_sites(SOURCE_PATH, 'let ink = UIColor(red: 1, green: 0')

    def test_nested_swift_comments_cannot_hide_constructor_or_later_channels(self):
        source = ('let ink = UIColor /* outer /* nested */ comment */ (\n'
                  ' red /* label */ : 1,\n green: /* ) */ .5, blue: 0, alpha: 1)')
        sites = guard.raw_colour_sites(SOURCE_PATH, source)
        self.assertEqual(len(sites), 1)
        self.assertIn('alpha: 1)', sites[0]['source'])
        changed = guard.raw_colour_sites(SOURCE_PATH, source.replace('blue: 0', 'blue: 1'))
        self.assertTrue(guard.compare_sites(changed, sites)['added'])
        self.assertEqual(len(guard.raw_colour_sites(SOURCE_PATH, 'let ink = UIColor // label\n (hex: "#abc")')), 1)
        with self.assertRaisesRegex(ValueError, 'Unclosed block comment'):
            guard.raw_colour_sites(SOURCE_PATH, '/* unclosed')

    def test_added_changed_and_duplicate_literals_fail_source_gate(self):
        root, _ = self.fixture()
        for source in [COLOUR + '\n' + COLOUR, COLOUR.replace('red: 1', 'red: .9'),
                       COLOUR + '\nlet other = UIColor(hex: 0xffffff)']:
            (root / SOURCE_PATH).write_text(source)
            with self.assertRaisesRegex(ValueError, 'Raw-colour drift'):
                guard.audit_raw_colours(root)

    def test_stale_exception_must_be_removed_then_empty_baseline_is_valid(self):
        root, baseline = self.fixture()
        (root / SOURCE_PATH).write_text('let ink = FWTokens.Color.text1')
        with self.assertRaisesRegex(ValueError, 'stale'):
            guard.audit_raw_colours(root)
        baseline['sites'] = []
        self.save_baseline(root, baseline)
        self.assertEqual(guard.audit_raw_colours(root)['occurrences'], 0)

    def test_file_context_and_counts_cannot_reuse_exception(self):
        old = guard.raw_colour_sites(SOURCE_PATH, COLOUR)
        for path, source in [('fearless/Else.swift', COLOUR), (SOURCE_PATH, COLOUR.replace('ink', 'fill')),
                             (SOURCE_PATH, COLOUR + '\n' + COLOUR)]:
            self.assertTrue(guard.compare_sites(guard.raw_colour_sites(path, source), old)['added'])
        self.assertEqual(guard.compare_sites(guard.raw_colour_sites(SOURCE_PATH, '\n  ' + COLOUR + '  \n'), old),
                         {'added': [], 'stale': []})

    def test_malformed_duplicate_traversal_wildcard_and_zero_count_rejected(self):
        _, baseline = self.fixture()
        for change in [{'count': 0}, {'count': True}, {'path': 'fearless/../Other.swift'},
                       {'path': 'fearless/./Other.swift'}, {'path': 'fearless/*/Other.swift'},
                       {'path': 'fearless//Other.swift'}, {'source': '*'}, {'source': ''}]:
            malformed = copy.deepcopy(baseline)
            malformed['sites'][0].update(change)
            with self.assertRaises(ValueError):
                guard.parse_baseline(malformed)
        duplicate = copy.deepcopy(baseline)
        duplicate['sites'] *= 2
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            guard.parse_baseline(duplicate)
        for key, value in [('schemaVersion', 2), ('sourceCommit', 'HEAD'), ('sites', None)]:
            malformed = copy.deepcopy(baseline)
            malformed[key] = value
            with self.assertRaises(ValueError):
                guard.parse_baseline(malformed)

    def test_symlink_file_directory_source_root_and_baseline_fail_closed(self):
        for kind in ['file', 'directory', 'root', 'baseline']:
            root, _ = self.fixture()
            if kind == 'file':
                (root / 'fearless/Linked.swift').symlink_to(root / SOURCE_PATH)
            elif kind == 'directory':
                (root / 'fearless/Linked').symlink_to(root / 'fearless/Modules', target_is_directory=True)
            elif kind == 'root':
                (root / 'fearless').rename(root / 'real')
                (root / 'fearless').symlink_to(root / 'real', target_is_directory=True)
            else:
                file = root / guard.BASELINE_PATH
                file.rename(root / 'saved.json')
                file.symlink_to(root / 'saved.json')
            with self.assertRaisesRegex(ValueError, 'link'):
                guard.audit_raw_colours(root)

    def test_initial_adoption_requires_exact_existing_git_source(self):
        root, baseline = self.fixture()
        self.assertIn('initial adoption', guard.audit_raw_colours(root)['baselineComparison'])
        (root / SOURCE_PATH).write_text(COLOUR + '\n' + COLOUR)
        baseline['sites'][0]['count'] = 2
        self.save_baseline(root, baseline)
        with self.assertRaisesRegex(ValueError, 'Initial exceptions exceed'):
            guard.audit_raw_colours(root)

    def test_initial_adoption_cannot_grandfather_an_anchor_from_inside_the_branch(self):
        root, baseline = self.fixture()
        base = guard.resolved_commit(root, 'HEAD')  # This actual base has no baseline.
        new_source = COLOUR + '\nlet newColour = UIColor(hex: 0x123456)'
        (root / SOURCE_PATH).write_text(new_source)
        self.commit(root)
        baseline['sourceCommit'] = guard.resolved_commit(root, 'HEAD')
        baseline['sites'] = guard.raw_colour_sites(SOURCE_PATH, new_source)
        self.save_baseline(root, baseline)
        with self.assertRaisesRegex(ValueError, 'comparison base'):
            guard.audit_raw_colours(root, base)

    def test_baseline_schema_version_rejects_boolean_and_float(self):
        _, baseline = self.fixture()
        for value in [True, 1.0]:
            with self.subTest(value=value, value_type=type(value)):
                malformed = copy.deepcopy(baseline)
                malformed['schemaVersion'] = value
                with self.assertRaises(ValueError):
                    guard.parse_baseline(malformed)

    def test_missing_and_invalid_base_or_initial_anchor_never_silently_skip(self):
        root, baseline = self.fixture()
        for ref in ['', 'missing-ref', '-h']:
            with self.assertRaises((ValueError, subprocess.SubprocessError)):
                guard.audit_raw_colours(root, ref)
        baseline['sourceCommit'] = 'a' * 40
        self.save_baseline(root, baseline)
        with self.assertRaises(subprocess.SubprocessError):
            guard.audit_raw_colours(root)

    def test_real_git_base_rejects_reintroduction_and_source_anchor_change(self):
        root, baseline = self.fixture()
        self.commit(root)
        original = copy.deepcopy(baseline)
        baseline['sites'] = []
        self.save_baseline(root, baseline)
        (root / SOURCE_PATH).write_text('let ink = FWTokens.Color.text1')
        self.assertEqual(guard.audit_raw_colours(root)['occurrences'], 0)
        self.commit(root)
        self.save_baseline(root, original)
        (root / SOURCE_PATH).write_text(COLOUR)
        with self.assertRaisesRegex(ValueError, 'only shrink'):
            guard.audit_raw_colours(root)
        original['sites'] = []
        original['sourceCommit'] = guard.resolved_commit(root, 'HEAD')
        self.save_baseline(root, original)
        (root / SOURCE_PATH).write_text('let ink = FWTokens.Color.text1')
        with self.assertRaisesRegex(ValueError, 'only shrink'):
            guard.audit_raw_colours(root)

    def test_simultaneous_removal_does_not_hide_a_new_exception(self):
        _, baseline = self.fixture()
        current = copy.deepcopy(baseline)
        current['sites'] = guard.raw_colour_sites(SOURCE_PATH, COLOUR.replace('red: 1', 'red: 0'))
        with self.assertRaisesRegex(ValueError, 'only shrink'):
            guard.assert_baseline_shrinks(current, baseline)

    def test_cli_exit_status_uses_real_git_and_new_untracked_source(self):
        root, _ = self.fixture()
        self.commit(root)
        command = ['python3', str(Path(__file__).with_name('check-raw-colours.py')), '--root', str(root), '--base-ref', 'HEAD']
        good = subprocess.run(command, text=True, capture_output=True)
        self.assertEqual(good.returncode, 0, good.stderr)
        (root / 'fearless/New.swift').write_text(COLOUR)
        bad = subprocess.run(command, text=True, capture_output=True)
        self.assertEqual(bad.returncode, 1)
        self.assertIn('fearless/New.swift', bad.stderr)

    def test_ci_requires_resolved_history_instead_of_head_or_silent_fallback(self):
        self.assertEqual(guard.ci_base_reference({'FW_COLOUR_BASE_REF': 'abc'}), 'abc')
        self.assertEqual(guard.ci_base_reference({'CHANGE_TARGET': 'release/ready'}),
                         'refs/remotes/origin/release/ready')
        self.assertEqual(guard.ci_base_reference({'GIT_PREVIOUS_SUCCESSFUL_COMMIT': 'abc'}), 'abc')
        for environment in [{}, {'FW_COLOUR_BASE_REF': ''}, {'FW_COLOUR_BASE_REF': '0' * 40}]:
            with self.assertRaisesRegex(ValueError, 'no source-only fallback'):
                guard.ci_base_reference(environment)

    def test_local_matrix_checks_before_any_dependency_cleanup_or_build(self):
        # Execute the real entry point with a failing guard interpreter. The
        # sentinel must be its first subprocess; no xcode/cache cleanup may run.
        root = Path(__file__).resolve().parents[1]
        temp = tempfile.TemporaryDirectory(prefix='ios-matrix-gate-')
        self.addCleanup(temp.cleanup)
        bin_dir = Path(temp.name)
        log = bin_dir / 'calls.txt'
        python = bin_dir / 'python3'
        python.write_text('#!/bin/sh\nprintf "%s\\n" "$*" > "$RAW_GATE_LOG"\nexit 42\n')
        python.chmod(0o755)
        import os
        environment = dict(os.environ, PATH=str(bin_dir) + ':' + os.environ['PATH'], RAW_GATE_LOG=str(log))
        result = subprocess.run(['bash', 'scripts/test-matrix.sh'], cwd=root,
                                env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(log.read_text().strip(), 'scripts/check-raw-colours.py')

    def test_ci_cli_failure_has_nonzero_exit_without_a_comparison_base(self):
        import os
        root, _ = self.fixture()
        environment = dict(os.environ)
        for key in ['FW_COLOUR_BASE_REF', 'CHANGE_TARGET', 'GIT_PREVIOUS_SUCCESSFUL_COMMIT']:
            environment.pop(key, None)
        result = subprocess.run(['python3', str(Path(__file__).with_name('check-raw-colours.py')),
                                 '--root', str(root), '--ci'], env=environment,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('no source-only fallback', result.stderr)


if __name__ == '__main__':
    unittest.main()
