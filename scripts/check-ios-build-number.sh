#!/usr/bin/env bash
set -euo pipefail

# Fails unless the production Release build is a fresh App Store Connect
# successor for 4.2.0 and every release tool pins that same build.
#
# App Store Connect orders CFBundleVersion by numeric components, so
# 2026.10.1 follows 2026.9.6 even though it sorts before it as text. A build
# that is not strictly greater than every consumed build is rejected by Apple
# at upload time; this check fails before an archive is ever produced.
#
# Usage:
#   bash scripts/check-ios-build-number.sh [REPOSITORY_ROOT]

readonly LOG_PREFIX="[ios-build-number]"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd "${1:-$SCRIPT_DIR/..}" && pwd -P)"
readonly EXPECTED_MARKETING_VERSION="4.2.0"
# Builds already uploaded for 4.2.0. Add each newly consumed build here.
readonly CONSUMED_BUILDS="2026.7.26 2026.7.28 2026.8.10 2026.8.13 2026.8.14 2026.8.34 2026.9.6"

python3 - "$REPO_ROOT" "$EXPECTED_MARKETING_VERSION" "$CONSUMED_BUILDS" "$LOG_PREFIX" <<'PYTHON'
import json
import re
import subprocess
import sys
from pathlib import Path

root, marketing_version, consumed, prefix = sys.argv[1:]
root = Path(root)
canonical = re.compile(r'[1-9][0-9]{0,3}(\.[0-9]{1,2}){0,2}')


def fail(message):
    print(f'{prefix} FAIL: {message}', file=sys.stderr)
    sys.exit(1)


def ordinal(build):
    return tuple(int(component) for component in build.split('.'))


def read(relative):
    path = root / relative
    if not path.is_file() or path.is_symlink():
        fail(f'{relative} is missing or not a regular file')
    return path.read_text()


def single(relative, pattern):
    values = re.findall(pattern, read(relative), re.MULTILINE)
    if len(values) != 1:
        fail(f'{relative} must pin exactly one build, found {len(values)}')
    return values[0]


project = root / 'fearless.xcodeproj/project.pbxproj'
try:
    objects = json.loads(subprocess.check_output(
        ['plutil', '-convert', 'json', '-o', '-', str(project)], stderr=subprocess.DEVNULL
    ))['objects']
except (subprocess.CalledProcessError, KeyError, ValueError):
    fail('fearless.xcodeproj/project.pbxproj is not a readable project')
targets = [obj for obj in objects.values() if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'fearless']
if len(targets) != 1:
    fail('production target must be unique')
configurations = objects[targets[0]['buildConfigurationList']]['buildConfigurations']
release = [objects[key]['buildSettings'] for key in configurations if objects[key].get('name') == 'Release']
if len(release) != 1:
    fail('production Release configuration must be unique')
build = release[0].get('CURRENT_PROJECT_VERSION', '')
if not canonical.fullmatch(build):
    fail(f'Release CURRENT_PROJECT_VERSION {build!r} is not a canonical CFBundleVersion')
if release[0].get('MARKETING_VERSION') != marketing_version:
    fail(f'Release MARKETING_VERSION must be {marketing_version}')

predecessors = set(consumed.split())
gate_source = read('scripts/audit-testflight-upgrade-usability-gate.py')
gate_predecessors = re.search(r'^EXPECTED_PREVIOUS_BUILDS = \(\n((?:    "[0-9.]+",\n)+)\)$', gate_source, re.MULTILINE)
if not gate_predecessors:
    fail('usability gate EXPECTED_PREVIOUS_BUILDS is unreadable')
predecessors.update(re.findall(r'"([0-9.]+)"', gate_predecessors.group(1)))
latest = max(predecessors, key=ordinal)
if ordinal(build) <= ordinal(latest):
    fail(f'Release build {build} is not greater than latest consumed build {latest}')

pins = {
    'Jenkinsfile': single('Jenkinsfile', r'^\s*IOS_EXPECTED_BUILD_NUMBER=([0-9.]+) \\$'),
    'fastlane/.env.example': single('fastlane/.env.example', r'^TESTFLIGHT_BUILD=([0-9.]+)$'),
    'fastlane/README.md finalize_existing': single(
        'fastlane/README.md', r'^scripts/fastlane\.sh ios finalize_existing \\\n  version:[0-9.]+ \\\n  build:([0-9.]+)$'
    ),
    'fastlane/README.md publish_archive': single(
        'fastlane/README.md', r'^scripts/fastlane\.sh ios publish_archive \\\n  version:[0-9.]+ \\\n  build:([0-9.]+)$'
    ),
    'scripts/ci/build-audited-ios-release-archive.sh': single(
        'scripts/ci/build-audited-ios-release-archive.sh', r'^readonly EXPECTED_BUILD="([0-9.]+)"$'
    ),
    'scripts/audit-testflight-upgrade-usability-gate.py': single(
        'scripts/audit-testflight-upgrade-usability-gate.py', r'^EXPECTED_BUILD = "([0-9.]+)"$'
    ),
    'scripts/capture-testflight-startup.py': single(
        'scripts/capture-testflight-startup.py', r'^SAFE_UPGRADE_BUILD_NUMBER = "([0-9.]+)"$'
    ),
}
for location, pinned in pins.items():
    if pinned != build:
        fail(f'{location} pins {pinned}, but the Release target builds {build}')

testflight_version = single('fastlane/.env.example', r'^TESTFLIGHT_VERSION=([0-9.]+)$')
if testflight_version != marketing_version:
    fail(f'fastlane/.env.example TESTFLIGHT_VERSION must be {marketing_version}')

capture_source = read('scripts/capture-testflight-startup.py')
supported = re.search(r'^SUPPORTED_CAPTURE_BUILD_NUMBERS = \(\n((?:    [A-Z0-9_]+,\n)+)\)$', capture_source, re.MULTILINE)
if not supported or '    SAFE_UPGRADE_BUILD_NUMBER,\n' not in supported.group(1):
    fail('startup capture does not allowlist SAFE_UPGRADE_BUILD_NUMBER')

print(f'{prefix} PASS: Release {marketing_version} ({build}) follows {len(predecessors)} consumed builds and {len(pins)} tools agree')
PYTHON
