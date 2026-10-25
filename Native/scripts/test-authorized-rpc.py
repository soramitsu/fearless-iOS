#!/usr/bin/env python3
"""Compile byte-identical production RPC sources in a narrow macOS test package.

No production checkout or resolved dependency is changed. App/device integration
still requires the full pinned iOS package and distribution builds.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--output-dir', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = args.output_dir or Path(tempfile.mkdtemp(prefix='fearless-rpc-tests-'))
if args.output_dir:
    out.mkdir(parents=True, exist_ok=False)
network = root / 'Sources/SSFUtils/SSFUtils/Classes/Network'
common = root / 'Sources/SSFUtils/SSFUtils/Classes/Common'
source_map = {
    'SSFUtils': [network / p for p in ['JSONRPCEngine.swift', 'JSONRPCOperation.swift', 'JSONRPCInfo.swift',
        'JSONRPCData.swift', 'Health.swift', 'ReconnectionStrategy.swift', 'RPCMethod.swift',
        'WebSocketEngine.swift', 'WebSocketEngine+Protocol.swift', 'WebSocketEngine+Delegate.swift',
        'Reachability/ReachabilityManager.swift']] + [common / p for p in ['Scheduler.swift','ReaderWriterLock.swift','Logger.swift']],
    'SSFModels': [root / 'Sources/SSFModels/SSFModels/Constants.swift'],
    'RobinHood': [root / 'Sources/RobinHood/Classes/Operations/Base/BaseOperation.swift']
}
package_source = (root / 'Package.swift').read_bytes()
hashes = {'Package.swift': hashlib.sha256(package_source).hexdigest()}
for module, sources in source_map.items():
    target = out / 'Sources' / module
    target.mkdir(parents=True)
    for source in sources:
        data = source.read_bytes()
        (target / source.name).write_bytes(data)
        hashes[str(source.relative_to(root))] = hashlib.sha256(data).hexdigest()
shutil.copytree(root / 'Sources/Starscream', out / 'Sources/Starscream')
for source in sorted((root / 'Sources/Starscream').rglob('*')):
    if source.is_file():
        hashes[str(source.relative_to(root))] = hashlib.sha256(source.read_bytes()).hexdigest()
shutil.copytree(root / 'Tests/AuthorizedRPC', out / 'Tests/AuthorizedRPCTests')
harness_manifest = '''// swift-tools-version:5.2
import PackageDescription
let package = Package(name: "FearlessRPCContract", platforms: [.macOS(.v10_14)], dependencies: [
    .package(url: "https://github.com/ashleymills/Reachability.swift", .revision("21d1dc412cfecbe6e34f1f4c4eb88d3f912654a6"))
], targets: [
    .target(name: "SSFModels"), .target(name: "RobinHood"), .target(name: "Starscream", exclude: ["LICENSE"]),
    .target(name: "SSFUtils", dependencies: ["SSFModels", "RobinHood", "Starscream", .product(name: "Reachability", package: "Reachability.swift")]),
    .testTarget(name: "AuthorizedRPCTests", dependencies: ["SSFUtils", "RobinHood", "Starscream"])
])
'''
(out / 'Package.swift').write_text(harness_manifest)
(out / 'source-sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
result = subprocess.run(['swift', 'test', '--package-path', str(out)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
(out / 'test.log').write_text(result.stdout)
sys.stdout.write(result.stdout)
for source, digest in hashes.items():
    if hashlib.sha256((root / source).read_bytes()).hexdigest() != digest:
        sys.exit('Production source changed while contract tests ran: ' + source)
if result.returncode:
    sys.exit(result.returncode)
passed = re.findall(r"^Test Case (.+) passed \(", result.stdout, re.MULTILINE)
if len(passed) != 37 or len(set(passed)) != 37 or re.search(r"^Test Case .+ (?:failed|skipped) \(", result.stdout, re.MULTILINE):
    sys.exit('Expected exactly 37 distinct passing XCTest cases, no skips')
print('PASS: 37 distinct cases; app-owned RPC and transport source hashes bound')
print('Contract evidence:', out)
