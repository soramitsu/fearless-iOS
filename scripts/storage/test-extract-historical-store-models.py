#!/usr/bin/env python3
"""Resolution rules of extract-historical-store-models.py against synthetic
repositories: which model each kind of build opened its stores with."""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("extract-historical-store-models.py")
SPEC = importlib.util.spec_from_file_location("extract_historical_store_models", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
EXTRACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXTRACT)

SUBSTRATE = EXTRACT.SUBSTRATE_MODELD
USER = EXTRACT.USER_MODELD
FACADE = EXTRACT.USER_FACADE
COMPATIBILITY = EXTRACT.USER_COMPATIBILITY_SOURCE
SSF_MODELS = EXTRACT.SSF_USER_MODELD


def model(name: str) -> str:
    return f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<model name="{name}"/>'


def current_version(name: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>'
        f"<key>_XCCurrentVersionName</key><string>{name}.xcdatamodel</string></dict></plist>\n"
    )


def facade(case: str, directory: str) -> str:
    return (
        "enum UserStorageParams {\n"
        f"    static let modelVersion: UserStorageVersion = .{case}\n"
        f'    static let modelDirectory: String = "{directory}"\n'
        "}\n"
    )


def storage_version(cases: dict[str, str]) -> str:
    body = "".join(f'    case {case} = "{raw}"\n' for case, raw in cases.items())
    return f"enum UserStorageVersion: String, CaseIterable {{\n{body}}}\n"


class Git:
    def __init__(self, path: Path, bare: bool = False) -> None:
        self.path = path
        subprocess.run(["git", "init", "-q"] + (["--bare"] if bare else []) + [str(path)], check=True)

    def run(self, *args: str) -> str:
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
                   GIT_COMMITTER_EMAIL="t@t", GIT_AUTHOR_DATE="2024-01-01T00:00:00Z",
                   GIT_COMMITTER_DATE="2024-01-01T00:00:00Z")
        isolated = ["-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", "-c", "core.hooksPath=/dev/null"]
        return subprocess.run(["git", "-C", str(self.path)] + isolated + list(args), check=True,
                              capture_output=True, env=env).stdout.decode().strip()

    def commit(self, files: dict[str, str], message: str) -> str:
        for name in self.run("ls-files").splitlines():
            if name not in files:
                self.run("rm", "-q", name)
        for name, contents in files.items():
            target = self.path / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(contents)
            self.run("add", name)
        self.run("commit", "-q", "--allow-empty", "-m", message)
        return self.run("rev-parse", "HEAD")

    def blob(self, contents: str) -> str:
        return subprocess.run(["git", "hash-object", "--stdin"], input=contents.encode(), check=True,
                              capture_output=True).stdout.decode().strip()


class HistoricalModelResolutionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.app = Git(root / "app")
        self.ssf_work = Git(root / "ssf-work")
        self.repo = EXTRACT.Repository("pub", str(root / "app"))

        self.ssf_revision = self.ssf_work.commit({
            f"{SSF_MODELS}/.xccurrentversion": current_version("MultiassetUserDataModel_v12"),
            f"{SSF_MODELS}/MultiassetUserDataModel_v11.xcdatamodel/contents": model("ssf-v11"),
            f"{SSF_MODELS}/MultiassetUserDataModel_v12.xcdatamodel/contents": model("ssf-v12"),
        }, "shared features")
        subprocess.run(["git", "clone", "-q", "--bare", str(root / "ssf-work"), str(root / "ssf.git")], check=True)
        self.ssf = EXTRACT.Repository("ssf", str(root / "ssf.git"), bare=True)

    def tearDown(self) -> None:
        self.repo.close()
        self.ssf.close()
        self.directory.cleanup()

    def test_single_model_era_uses_the_only_models(self) -> None:
        rev = self.app.commit({
            f"{SUBSTRATE}/SubstrateDataModel.xcdatamodel/contents": model("s1"),
            f"{USER}/UserDataModel.xcdatamodel/contents": model("u1"),
        }, "1.x")

        substrate = EXTRACT.substrate_model(self.repo, rev)
        user = EXTRACT.user_model(self.repo, rev, self.ssf)

        self.assertEqual(substrate["name"], "SubstrateDataModel")
        self.assertEqual(substrate["blob"], self.app.blob(model("s1")))
        self.assertEqual(user["name"], "UserDataModel")
        self.assertEqual(user["blob"], self.app.blob(model("u1")))

    def test_substrate_store_follows_the_current_version(self) -> None:
        rev = self.app.commit({
            f"{SUBSTRATE}/.xccurrentversion": current_version("SubstrateDataModel_v2"),
            f"{SUBSTRATE}/SubstrateDataModel.xcdatamodel/contents": model("s1"),
            f"{SUBSTRATE}/SubstrateDataModel_v2.xcdatamodel/contents": model("s2"),
        }, "2.x")

        substrate = EXTRACT.substrate_model(self.repo, rev)

        self.assertEqual(substrate["name"], "SubstrateDataModel_v2")
        self.assertEqual(substrate["blob"], self.app.blob(model("s2")))

    def test_user_store_follows_model_version_not_the_current_version(self) -> None:
        # The facade opens `modelVersion` inside the .momd, whatever .xccurrentversion says.
        rev = self.app.commit({
            FACADE: facade("version3", "UserDataModel.momd"),
            "fearless/Common/Migration/UserStorageVersion.swift": storage_version({
                "version2": "MultiassetUserDataModel",
                "version3": "MultiassetUserDataModel_v2",
            }),
            f"{USER}/.xccurrentversion": current_version("MultiassetUserDataModel_v3"),
            f"{USER}/MultiassetUserDataModel_v2.xcdatamodel/contents": model("u-v2"),
            f"{USER}/MultiassetUserDataModel_v3.xcdatamodel/contents": model("u-v3"),
        }, "2.0.x")

        user = EXTRACT.user_model(self.repo, rev, self.ssf)

        self.assertEqual(user["name"], "MultiassetUserDataModel_v2")
        self.assertEqual(user["blob"], self.app.blob(model("u-v2")))

    def test_user_store_in_shared_features_uses_the_pinned_revision(self) -> None:
        resolved = json.dumps({"pins": [{
            "identity": "shared-features-spm",
            "location": "https://github.com/soramitsu/shared-features-spm.git",
            "state": {"revision": self.ssf_revision},
        }]})
        rev = self.app.commit({
            FACADE: facade("version12", "Modules_SSFAccountManagmentStorage.bundle//UserDataModel.momd"),
            "fearless/Common/Storage/Migration/UserStorage/UserStorageVersion.swift": storage_version({
                "version12": "MultiassetUserDataModel_v11",
            }),
            EXTRACT.PACKAGE_RESOLVED: resolved,
        }, "3.7.x")

        user = EXTRACT.user_model(self.repo, rev, self.ssf)

        self.assertEqual(user["repo"], "ssf")
        self.assertEqual(user["name"], "MultiassetUserDataModel_v11")
        self.assertEqual(user["blob"], self.app.blob(model("ssf-v11")))

    def test_compatibility_user_model_wins_over_the_model_directory(self) -> None:
        rev = self.app.commit({
            FACADE: facade("version14", "Modules_SSFAccountManagmentStorage.bundle//UserDataModel.momd"),
            "fearless/Common/Storage/Migration/UserStorage/UserStorageVersion.swift": storage_version({
                "version14": "CompatibleUserDataModel_v13",
            }),
            f"{COMPATIBILITY}/CompatibleUserDataModel_v13.xcdatamodel/contents": model("compat-v13"),
        }, "4.2.0")

        user = EXTRACT.user_model(self.repo, rev, self.ssf)

        self.assertEqual(user["repo"], "pub")
        self.assertEqual(user["path"], f"{COMPATIBILITY}/CompatibleUserDataModel_v13.xcdatamodel/contents")

    def test_unresolvable_user_model_is_reported_not_guessed(self) -> None:
        rev = self.app.commit({
            FACADE: facade("version9", "UserDataModel.momd"),
            "fearless/Common/Storage/Migration/UserStorage/UserStorageVersion.swift": storage_version({
                "version9": "MultiassetUserDataModel_v8",
            }),
        }, "missing model")

        self.assertIn("unresolved", EXTRACT.user_model(self.repo, rev, self.ssf))

    def test_inventory_resolves_tags_and_records_tags_without_models(self) -> None:
        self.app.commit({"README.md": "empty\n"}, "0.1.0")
        self.app.run("tag", "0.1.0")
        release = self.app.commit({
            f"{SUBSTRATE}/SubstrateDataModel.xcdatamodel/contents": model("s1"),
            f"{USER}/UserDataModel.xcdatamodel/contents": model("u1"),
        }, "1.0.0")
        self.app.run("tag", "-a", "-m", "release", "1.0.0")
        # A branch with a tag's name must not change what the tag resolves to.
        self.app.commit({"README.md": "later\n"}, "later")
        self.app.run("branch", "1.0.0")

        original = EXTRACT.HEADS, EXTRACT.DEVELOPMENT_COMMITS
        EXTRACT.HEADS, EXTRACT.DEVELOPMENT_COMMITS = [], []
        try:
            observations, without, unresolved = EXTRACT.resolve_inventory({"pub": self.repo}, self.ssf)
        finally:
            EXTRACT.HEADS, EXTRACT.DEVELOPMENT_COMMITS = original

        self.assertEqual(unresolved, [])
        self.assertEqual(without, ["pub:0.1.0"])
        self.assertEqual(sorted((store, p["tag"], p["commit"]) for store, _, p in observations),
                         [("substrate", "1.0.0", release), ("user", "1.0.0", release)])

    def test_tiers_and_release_tags(self) -> None:
        self.assertTrue(EXTRACT.is_release_tag("3.5.3"))
        for tag in ("3.2.2.1", "2.0.0-1", "1.6RC1", "v1.0.2", "9999"):
            self.assertFalse(EXTRACT.is_release_tag(tag), tag)
        self.assertEqual(EXTRACT.tier_for(["pub:3.5.3"], ["pub:3.5.3.1"], []), "appStore")
        self.assertEqual(EXTRACT.tier_for([], ["pub:3.6.1.1"], []), "testFlight")
        self.assertEqual(EXTRACT.tier_for([], [], [("c", "TestFlight head")]), "testFlight")
        self.assertEqual(EXTRACT.tier_for([], [], []), "development")
        self.assertLess(EXTRACT.version_key("2.0.9"), EXTRACT.version_key("2.0.10"))

    def test_policy_lands_only_on_lineage_names_and_sorts_drops(self) -> None:
        for store, table in EXTRACT.POLICY.items():
            for digest, policy in table.items():
                self.assertRegex(digest, "^[0-9a-f]{16}$")
                if "excluded" in policy:
                    self.assertEqual(set(policy), {"excluded"})
                    continue
                prefix = "SubstrateDataModel" if store == "substrate" else "MultiassetUserDataModel"
                self.assertTrue(policy["landing"].startswith(prefix), digest)
                drops = policy["allowedDrops"]
                self.assertEqual(drops["entities"], sorted(drops["entities"]))
                self.assertEqual(drops["attributes"], sorted(drops["attributes"]))


if __name__ == "__main__":
    unittest.main()
