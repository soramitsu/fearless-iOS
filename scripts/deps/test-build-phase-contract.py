#!/usr/bin/env python3
"""Exercise the build-tool contract of the checked-in Fearless Xcode target."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class BuildPhaseContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        project = ROOT / "fearless.xcodeproj/project.pbxproj"
        objects = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", project]))["objects"]
        target, = [obj for obj in objects.values() if obj.get("isa") == "PBXNativeTarget" and obj["name"] == "fearless"]
        cls.phases = [objects[key] for key in target["buildPhases"]]
        cls.scripts = {phase["name"]: phase for phase in cls.phases if phase["isa"] == "PBXShellScriptBuildPhase"}

    def test_verified_host_tools_run_before_app_compilation(self):
        order = [phase.get("name", phase["isa"]) for phase in self.phases]
        expected_scripts = {
            "R.swift": '"$PROJECT_DIR/build/source-tools/bin/rswift" generate "$PROJECT_DIR/R.generated.swift"',
            "SwiftFormat": '"$PROJECT_DIR/build/source-tools/bin/swiftformat" --lint "$SRCROOT/fearless"',
        }
        self.assertEqual(self.scripts["Verify Native Sources"]["alwaysOutOfDate"], "1")
        for name, command in expected_scripts.items():
            with self.subTest(phase=name):
                self.assertEqual(order.count(name), 1)
                self.assertLess(order.index("Verify Native Sources"), order.index(name))
                self.assertLess(order.index(name), order.index("PBXSourcesBuildPhase"))
                self.assertEqual(self.scripts[name]["shellScript"].strip(), command)

    def test_tool_verification_failure_stops_the_xcode_phase(self):
        phase = self.scripts["Verify Native Sources"]
        with tempfile.TemporaryDirectory(prefix="build phase ") as tmp:
            root = Path(tmp)
            (root / "SourcePackages/checkouts").mkdir(parents=True)
            stub = root / "python3"
            stub.write_text(
                '#!/bin/sh\n'
                'if [ "$1" = -I ] && [ "$2" = "$PROJECT_DIR/scripts/deps/verify-build-tools.py" ] '
                '&& [ "$3" = "$PROJECT_DIR" ]; then exit 87; fi\nexit 0\n'
            )
            stub.chmod(0o755)
            env = dict(PATH=tmp + os.pathsep + os.defpath, PROJECT_DIR=tmp,
                       SOURCE_PACKAGES_DIR=str(root / "SourcePackages"), PODS_ROOT=str(root / "Pods"))
            result = subprocess.run([phase["shellPath"], "-c", phase["shellScript"]], cwd=root,
                                    env=env, capture_output=True)
            self.assertEqual(result.returncode, 87, result.stderr)

    def test_pods_supply_the_runtime_library_and_no_build_tool(self):
        podfile = (ROOT / "Podfile").read_bytes()
        installed = (ROOT / "Podfile.lock").read_text()
        declared = re.findall(r'''^\s*pod\s+['"]([^'"]+)['"]''', podfile.decode(), re.MULTILINE)
        locked = re.findall(r"^\s*-\s+([\w./-]+)", installed, re.MULTILINE)
        for names in (declared, locked):
            self.assertIn("R.swift.Library", names)
            self.assertFalse({"R.swift", "SwiftFormat"} & {name.split("/")[0] for name in names})
        self.assertIn("  - R.swift.Library (5.3.0)\n", installed)
        self.assertIn("PODFILE CHECKSUM: " + hashlib.sha1(podfile).hexdigest() + "\n", installed)


if __name__ == "__main__":
    unittest.main()
