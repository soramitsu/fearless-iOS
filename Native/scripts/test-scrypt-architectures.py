#!/usr/bin/env python3
"""Check real scrypt output and link all supported Apple architecture variants.

Requires Xcode and Python 3. Runs RFC 7914 section 12 vectors on the host;
cross-linking is build coverage only, not device acceptance.
"""

import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/scrypt"
FILES = ["crypto_scrypt.c", "crypto_scrypt_smix.c", "crypto_scrypt_smix_sse2.c",
         "sha256.c", "insecure_memzero.c", "warnp.c"]
VECTORS = [
    ("", "", 16, 1, 1,
     "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442"
     "fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906"),
    ("password", "NaCl", 1024, 8, 16,
     "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b373162"
     "2eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640"),
    ("pleaseletmein", "SodiumChloride", 16384, 8, 1,
     "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2"
     "d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887"),
]
HARNESS = r'''
#include "scrypt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
    if (argc != 6) return 2;
    unsigned char result[64];
    int status = crypto_scrypt((const uint8_t *)argv[1], strlen(argv[1]),
        (const uint8_t *)argv[2], strlen(argv[2]), strtoull(argv[3], NULL, 10),
        (uint32_t)strtoul(argv[4], NULL, 10), (uint32_t)strtoul(argv[5], NULL, 10),
        result, sizeof(result));
    if (status != 0) return 1;
    for (size_t i = 0; i < sizeof(result); i++) printf("%02x", result[i]);
    return 0;
}
'''


class ScryptArchitectureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="fearless-scrypt-")
        cls.directory = pathlib.Path(cls.temporary.name)
        cls.harness = cls.directory / "main.c"
        cls.harness.write_text(HARNESS)
        cls.host = cls.build("host", "macosx", [])

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    @classmethod
    def build(cls, name, sdk, flags):
        output = cls.directory / name
        command = ["xcrun", "--sdk", sdk, "clang", "-O2", "-Werror=implicit-function-declaration",
                   "-I", str(SOURCE), "-I", str(SOURCE / "include"), *flags,
                   *[str(SOURCE / file) for file in FILES], str(cls.harness), "-o", str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(f"{name} compilation failed: {result.stderr}")
        return output

    def test_rfc7914_vectors(self):
        for password, salt, n, r, p, expected in VECTORS:
            with self.subTest(n=n, r=r, p=p):
                result = subprocess.run(
                    [str(self.host), password, salt, str(n), str(r), str(p)], capture_output=True)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, expected.encode("ascii"))
                self.assertEqual(result.stderr, b"")

    def test_invalid_cost_rejected(self):
        for cost in [0, 1, 3, 15]:
            with self.subTest(cost=cost):
                result = subprocess.run([str(self.host), "", "", str(cost), "1", "1"],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, "")
                self.assertEqual(result.stderr, "")

    def test_zero_work_factors_rejected_without_crashing(self):
        for r, p in [(0, 1), (1, 0), (0, 0)]:
            with self.subTest(r=r, p=p):
                result = subprocess.run([str(self.host), "", "", "16", str(r), str(p)],
                                        capture_output=True)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, b"")
                self.assertEqual(result.stderr, b"")

    def test_apple_architecture_linking(self):
        configurations = [
            ("device-arm64", "iphoneos", ["-target", "arm64-apple-ios14.0"]),
            ("sim-arm64", "iphonesimulator", ["-target", "arm64-apple-ios14.0-simulator"]),
            ("sim-x86_64", "iphonesimulator", ["-target", "x86_64-apple-ios14.0-simulator"]),
            ("sim-x86_64-generic", "iphonesimulator",
             ["-target", "x86_64-apple-ios14.0-simulator", "-mno-ssse3"]),
        ]
        for name, sdk, flags in configurations:
            with self.subTest(architecture=name):
                self.assertTrue(self.build(name, sdk, flags).is_file())


if __name__ == "__main__":
    unittest.main(verbosity=2)
