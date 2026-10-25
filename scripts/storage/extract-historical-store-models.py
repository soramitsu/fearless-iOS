#!/usr/bin/env python3
"""Inventory every Core Data store model that a Fearless iOS build shipped.

For every tag of the public and private iOS repositories, for the TestFlight
heads and for the untagged development commits listed below, this resolves the
model each build opened its Substrate and User stores with, using only
read-only `git show` / `git rev-parse` / `git tag` / `git rev-list`:

- Substrate store: the `.xccurrentversion` of `SubstrateDataModel.xcdatamodeld`
  (the facade opens the whole `.momd`), or the single model of the 1.x layout.
- User store: `UserStorageParams.modelVersion` mapped through the build's own
  `UserStorageVersion` raw values, looked up where that build looked it up (the
  app's compatibility sources, the shared-features `SSFAccountManagmentStorage`
  bundle pinned by the build, or the app's own `UserDataModel.xcdatamodeld`).
  1.x builds without `modelVersion` open the `.momd`, so `.xccurrentversion`.

Blobs are grouped by schema digest (see historical-model-digest.swift). The
landing hop, the reviewed drop allowlist and exclusions come from POLICY below;
whether a digest is already recognised comes from the models this checkout
bundles. The output is the checked-in provenance:

- fearless/Common/Storage/HistoricalStoreModels/Source/<resource>.xcdatamodel/contents
  (verbatim blob, plus the conventional final LF when the blob has none)
- fearlessTests/Resources/HistoricalStoreModels/manifest.json

Compiled `.mom` files are produced afterwards by
compile-historical-store-models.sh, and everything is checked by
audit-historical-store-models.sh.

`--verify` writes nothing. It re-resolves every tag and head and fails unless
the checked-in manifest records exactly that inventory, and it checks that the
in-repo User lineage sources equal the shared-features models the app bundles.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))

SUBSTRATE_MODELD = "fearless/Common/Storage/SubstrateDataModel.xcdatamodeld"
USER_MODELD = "fearless/Common/Storage/UserDataModel.xcdatamodeld"
USER_FACADE = "fearless/Common/Storage/UserDataStorageFacade.swift"
USER_COMPATIBILITY_SOURCE = "fearless/Common/Storage/CompatibilityModels/Source"
SUBSTRATE_COMPATIBILITY_COMPILED = "fearless/Common/Storage/SubstrateCompatibilityModels/Compiled"
USER_COMPATIBILITY_COMPILED = "fearless/Common/Storage/CompatibilityModels/Compiled"
SSF_USER_MODELD = "Sources/SSFAccountManagmentStorage/Resources/UserDataModel.xcdatamodeld"
SSF_BUNDLE_MARKER = "Modules_SSFAccountManagmentStorage.bundle"
PACKAGE_RESOLVED = "fearless.xcworkspace/xcshareddata/swiftpm/Package.resolved"

DEFAULT_MODELS_ROOT = os.path.join(ROOT_DIR, "fearless/Common/Storage/HistoricalStoreModels")
DEFAULT_MANIFEST = os.path.join(ROOT_DIR, "fearlessTests/Resources/HistoricalStoreModels/manifest.json")

RESOURCE_PREFIX = {"substrate": "SubstrateHistorical_", "user": "UserHistorical_"}
STORE_ORDER = {"substrate": 0, "user": 1}

# TestFlight builds that were distributed from untagged commits. Both stores.
HEADS = [
    ("pub", "2e45e55dc03ad904598e730cfb5994fb5c1072dc", "TestFlight 4.2.0 (2026.7.x)"),
    ("pub", "dae82913e06fad59112bea51d8e6d07a2ff269c6", "codex/testflight-4.2.0-2026.8.10"),
    ("pub", "645c15373bef2c9e384abf4f28deaef34007e7bf", "TestFlight 4.2.0 (2026.9.6) build source"),
    ("pub", "621844920713aaee3e71828b01b210b0f6fdb9ff", "codex/testflight-4.2.0-2026.9.6"),
]

# Untagged development commits whose current Substrate model differs from every
# tagged one. Development builds wrote these stores, so they are inventoried
# (decision D1). Substrate store only.
DEVELOPMENT_COMMITS = [
    ("pub", "97910eee7995d55160d1c982bd1d0705e7928df4", "v5 development 2023-11-02"),
    ("pub", "60c2a57f41082b703556fdfc5116fbbdc759ddaf", "v5 development 2023-11-10"),
    ("pub", "e8c56c3fcbef64b22cef045a71734d05afa0274b", "v5 development 2023-11-10"),
    ("pub", "b78bfde42ae50a07d2a79cbb54573b5157866bae", "v5 development 2024-05-03"),
    ("pub", "133c581b75dfe1faf4151025a3ae039988a40806", "v8 development 2024-08-08"),
    ("pub", "af5cc7a4f6e332537bcdb3518e67623aeac84cbc", "v8 development 2024-08-09"),
    ("pub", "c54ff3923e765894db2d229edae4ffc3677c464f", "v8 development 2024-08-12"),
    ("pub", "b2342dc6ca9d5a7e13614586f557bc7471f370c1", "v8 development 2024-08-22"),
    ("pub", "9a14307f6ef22a242a674971b63f2d7796ce3344", "v8 development 2024-08-23"),
    ("pub", "8d094ae268a9ac21da29ad7c5785f7e62c009b80", "v8 development 2024-08-26"),
    ("pub", "16ed040730c887e34847dd883818d17fc12ba379", "v8 development 2024-08-29"),
    ("pub", "8691e5c703db009bab3a6c041782c00b1a0fc331", "v8 development 2024-08-30"),
]


def drops(entities=(), attributes=()):
    return {"entities": sorted(entities), "attributes": sorted(attributes)}


LEGACY_TRANSFER_CALL_PATH = {
    # What 1.7 wrote for local transfers (CallCodingPath, decision D3).
    "CDTransactionHistoryItem.callName": "transfer",
    "CDTransactionHistoryItem.moduleName": "Balances",
}

UNNAMED_TON_CONNECTED_APP = {
    # The build recorded no name; v10 requires one. Everything else is kept.
    "CDTonConnectedApp.name": "",
}

# Reviewed landing hop per unrecognised digest (ios-keys.md section 7). The
# landing is the lineage model of the same schema family, so the real downstream
# hops only run on data that has not been through them. `allowedDrops` must
# equal the inferred mapping's drop set exactly; every entry is cache-only.
POLICY = {
    "substrate": {
        # 0.4.0-1.6: no callName/moduleName yet; local transfer history keeps its
        # rows with the 1.7 call path, `amount` is dropped as 1.7 did.
        "27378408dc2e9402": {"landing": "SubstrateDataModel",
                             "allowedDrops": drops(attributes=["CDTransactionHistoryItem.amount"]),
                             "requiredConstants": LEGACY_TRANSFER_CALL_PATH},
        "d713024629483ef3": {"landing": "SubstrateDataModel",
                             "allowedDrops": drops(attributes=["CDTransactionHistoryItem.amount"]),
                             "requiredConstants": LEGACY_TRANSFER_CALL_PATH},
        "021514c396c2d844": {"landing": "SubstrateDataModel", "allowedDrops": drops()},
        "6ca82510c9ee52ee": {"landing": "SubstrateDataModel", "allowedDrops": drops()},
        "5cffa3d6ae6c920b": {"landing": "SubstrateDataModel", "allowedDrops": drops(entities=["CDMockEntity"])},
        "ddb3684b41b1ea24": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "244dfde33ea8f2ba": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "f83c370eecf5cb6f": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops(attributes=["CDChain.unused"])},
        "16812164d61dbeb4": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops(attributes=["CDAsset.type"])},
        "b9a6768e87baa040": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops(attributes=["CDAsset.type"])},
        "71d5bd5ded4db12f": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops(attributes=["CDAsset.type"])},
        "a2680a724929571f": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops(attributes=["CDAsset.type"])},
        "6082d96e8929023c": {"landing": "SubstrateDataModel_v2",
                             "allowedDrops": drops(attributes=["CDAsset.accountInfo", "CDAsset.type"])},
        "92b1571afd8bc9e9": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "1607d3b0b76a26fb": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "467c422cbed3e413": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "e37c88089f0ec8a3": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "6a9e0bb518359972": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "b80d247b980d5efd": {"landing": "SubstrateDataModel_v3", "allowedDrops": drops()},
        "f2c90835e0c0cf24": {"landing": "SubstrateDataModel_v4", "allowedDrops": drops()},
        "46a317e0e5d34fa7": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "858c2b993253d609": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "7d0188e7cd13bedc": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        "829b48f2aaeaa058": {"landing": "SubstrateDataModel_v2", "allowedDrops": drops()},
        # v5 family (XCM relationships): land at v5, never v4, so the legacy XCM
        # transform does not run twice. CDSingleValue is a JSON provider cache.
        "8dbf44e2f59b814a": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops(entities=["CDSingleValue"])},
        "40fac78f488eef8e": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops(entities=["CDSingleValue"])},
        "32ac3b4f6e7c6023": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops(entities=["CDSingleValue"])},
        "d484c09eddea88ca": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops(entities=["CDSingleValue"])},
        "02d51fe4d9ec39aa": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops()},
        "e65bafe1d9757c47": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops()},
        "4f4d570ff919c021": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops()},
        "f41928b60f59b412": {"landing": "SubstrateDataModel_v5",
                             "allowedDrops": drops(entities=["CDSingleValue"],
                                                   attributes=["CDChainXcmConfig.bridgeParachainId"])},
        "038ca011be713713": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops(entities=["CDSingleValue"])},
        "b297477951df254c": {"landing": "SubstrateDataModel_v5", "allowedDrops": drops(entities=["CDSingleValue"])},
        # v8 family (TON): land at v10 directly, as the public v8/v9 models do.
        "201c41162d1b1604": {"landing": "SubstrateDataModel_v10", "allowedDrops": drops()},
        "186efaedb554f36c": {"landing": "SubstrateDataModel_v10", "allowedDrops": drops()},
        # August 2024 TON development builds. CDAsset.price/fiatDayChange are
        # price caches. The earliest TonConnect builds stored no app name, which
        # v10 requires; those rows keep everything and get an empty name.
        "621ce0ac92c09ceb": {"landing": "SubstrateDataModel_v10",
                             "allowedDrops": drops(attributes=["CDAsset.fiatDayChange", "CDAsset.price"])},
        "497f2e4a5aaef4ce": {"landing": "SubstrateDataModel_v10", "allowedDrops": drops()},
        "3d1e762d3131e9a4": {"landing": "SubstrateDataModel_v10",
                             "allowedDrops": drops(attributes=["CDAsset.fiatDayChange", "CDAsset.price"]),
                             "requiredConstants": UNNAMED_TON_CONNECTED_APP},
        "d56a527740e8c53f": {"landing": "SubstrateDataModel_v10", "allowedDrops": drops(),
                             "requiredConstants": UNNAMED_TON_CONNECTED_APP},
        "ca676bc0fe523c61": {"landing": "SubstrateDataModel_v10", "allowedDrops": drops(),
                             "requiredConstants": UNNAMED_TON_CONNECTED_APP},
        "2275e38844008174": {"landing": "SubstrateDataModel_v10", "allowedDrops": drops()},
        # Transformable CDAsset.priceData is not in the migrator's resilient
        # transformable allowlist; IK-4's guided recovery covers these stores.
        "82f764a9d8438b0b": {"excluded": "unsupported transformable"},
        "2ce53fef97b6be28": {"excluded": "unsupported transformable"},
    },
    "user": {
        "0470cf6eb7223e09": {"landing": "MultiassetUserDataModel_v3", "allowedDrops": drops()},
        "399fe7c2a5ba8b2c": {"landing": "MultiassetUserDataModel_v9", "allowedDrops": drops()},
        "ea8584ece2603f2a": {"landing": "MultiassetUserDataModel_v10", "allowedDrops": drops()},
    },
}


def fail(message):
    print(f"[historical-model-extract][error] {message}", file=sys.stderr)
    sys.exit(1)


class Repository:
    def __init__(self, label, path, bare=False):
        self.label = label
        self.path = path
        self.bare = bare
        self._batch = None

    def _command(self, *args):
        prefix = ["git", f"--git-dir={self.path}"] if self.bare else ["git", "-C", self.path]
        return prefix + list(args)

    def git(self, *args):
        result = subprocess.run(self._command(*args), capture_output=True)
        return result.stdout if result.returncode == 0 else None

    def _object(self, spec):
        """(object id, type, bytes) for any revision expression, through one
        long-lived read-only `git cat-file --batch`; None when it does not exist."""
        if self._batch is None:
            self._batch = subprocess.Popen(self._command("cat-file", "--batch"),
                                           stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        self._batch.stdin.write(spec.encode() + b"\n")
        self._batch.stdin.flush()
        header = self._batch.stdout.readline().split()
        if len(header) != 3:
            return None
        data = self._batch.stdout.read(int(header[2]))
        self._batch.stdout.read(1)
        return header[0].decode(), header[1].decode(), data

    def close(self):
        if self._batch is not None:
            self._batch.stdin.close()
            self._batch.wait()
            self._batch.stdout.close()
            self._batch = None

    def raw(self, rev, path):
        found = self._object(f"{rev}:{path}")
        return found[2] if found and found[1] == "blob" else None

    def text(self, rev, path):
        data = self.raw(rev, path)
        return data.decode("utf-8", "replace") if data is not None else None

    def blob(self, rev, path):
        found = self._object(f"{rev}:{path}")
        return found[0] if found and found[1] == "blob" else None

    def blob_bytes(self, blob):
        found = self._object(blob)
        return found[2] if found and found[1] == "blob" else None

    def commit(self, rev):
        found = self._object(f"{rev}^{{commit}}")
        return found[0] if found and found[1] == "commit" else None

    def commit_time(self, rev):
        found = self._object(f"{rev}^{{commit}}")
        match = re.search(rb"^committer .* (\d+) [+-]\d{4}$", found[2], re.M) if found else None
        return int(match.group(1)) if match else 0

    def tags(self):
        out = self.git("tag", "--sort=creatordate")
        return out.decode().split() if out else []


def current_version(repo, rev, modeld):
    plist = repo.text(rev, f"{modeld}/.xccurrentversion")
    if plist:
        match = re.search(r"<string>([^<]+)\.xcdatamodel</string>", plist)
        if match:
            return match.group(1)
    return None


def substrate_model(repo, rev):
    name = current_version(repo, rev, SUBSTRATE_MODELD)
    if name is None:
        # 1.x layout: one unversioned model inside the .xcdatamodeld.
        name = "SubstrateDataModel"
        if repo.blob(rev, f"{SUBSTRATE_MODELD}/{name}.xcdatamodel/contents") is None:
            return None
    path = f"{SUBSTRATE_MODELD}/{name}.xcdatamodel/contents"
    blob = repo.blob(rev, path)
    return {"name": name, "blob": blob, "repo": repo.label, "path": path} if blob else None


def ssf_revision(repo, rev, ssf):
    """The shared-features revision a build pinned (kept as in the audit tooling)."""
    resolved = repo.text(rev, PACKAGE_RESOLVED)
    if resolved:
        try:
            data = json.loads(resolved)
            pins = data.get("pins") or data.get("object", {}).get("pins", [])
            for pin in pins:
                identity = (pin.get("identity") or pin.get("package") or "").lower()
                location = pin.get("location") or pin.get("repositoryURL") or ""
                if "shared-features" in identity or "shared-features" in location:
                    return pin["state"].get("revision"), "resolved"
        except (ValueError, KeyError, TypeError):
            pass
    project = repo.text(rev, "fearless.xcodeproj/project.pbxproj")
    if project and "shared-features-spm" in project:
        match = re.search(
            r'XCRemoteSwiftPackageReference "shared-features-spm" \*/ = \{.*?requirement = \{(.*?)\};',
            project, re.S)
        if match:
            requirement = match.group(1)
            revision = re.search(r"revision = ([0-9a-f]+);", requirement)
            branch = re.search(r'branch = "?([^";]+)"?;', requirement)
            if revision:
                return revision.group(1), "pbx-revision"
            if branch and ssf is not None:
                date = repo.git("log", "-1", "--format=%cI", rev).decode().strip()
                out = ssf.git("rev-list", "-1", f"--before={date}", branch.group(1))
                if out:
                    return out.decode().strip(), f"branch:{branch.group(1)}@{date}"
                return None, f"branch:{branch.group(1)}?"
    return None, None


# Where UserStorageVersion lived; anything else falls back to `git grep`.
USER_STORAGE_VERSION_PATHS = [
    "fearless/Common/Storage/Migration/UserStorage/UserStorageVersion.swift",
    "fearless/Common/Migration/UserStorage/UserStorageVersion.swift",
    "fearless/Common/Migration/UserStorageVersion.swift",
]


def user_storage_raw_value(repo, rev, case_name, ssf, ssf_rev):
    pattern = re.compile(r"case\s+" + re.escape(case_name) + r'\s*=\s*"([^"]+)"')
    for path in USER_STORAGE_VERSION_PATHS:
        text = repo.text(rev, path)
        if text and "enum UserStorageVersion" in text:
            match = pattern.search(text)
            if match:
                return match.group(1)
    listing = repo.git("grep", "-l", "enum UserStorageVersion", rev, "--", "fearless")
    for line in (listing.decode().splitlines() if listing else []):
        path = line.split(":", 1)[1]
        match = pattern.search(repo.text(rev, path) or "")
        if match:
            return match.group(1)
    if ssf is not None and ssf_rev:
        listing = ssf.git("grep", "-l", "enum UserStorageVersion", ssf_rev, "--", "Sources")
        for line in (listing.decode().splitlines() if listing else []):
            path = line.split(":", 1)[1]
            match = pattern.search(ssf.text(ssf_rev, path) or "")
            if match:
                return match.group(1)
    return None


def user_model(repo, rev, ssf):
    facade = repo.text(rev, USER_FACADE) or ""
    version_match = re.search(r"static let modelVersion: UserStorageVersion = \.(\w+)", facade)
    directory_match = re.search(r'static let modelDirectory: String = "([^"]*)"', facade)

    if version_match is None:
        name = current_version(repo, rev, USER_MODELD) or "UserDataModel"
        path = f"{USER_MODELD}/{name}.xcdatamodel/contents"
        blob = repo.blob(rev, path)
        if blob is None:
            return None
        return {"name": name, "blob": blob, "repo": repo.label, "path": path}

    directory = directory_match.group(1) if directory_match else ""
    in_ssf = SSF_BUNDLE_MARKER in directory
    ssf_rev, how = ssf_revision(repo, rev, ssf) if in_ssf else (None, None)
    raw = user_storage_raw_value(repo, rev, version_match.group(1), ssf, ssf_rev)
    if raw is None:
        return {"unresolved": f"no raw value for UserStorageVersion.{version_match.group(1)}"}

    # Compatibility resources are looked up at the bundle root, whatever the
    # model directory says.
    path = f"{USER_COMPATIBILITY_SOURCE}/{raw}.xcdatamodel/contents"
    blob = repo.blob(rev, path)
    if blob:
        return {"name": raw, "blob": blob, "repo": repo.label, "path": path}

    if in_ssf:
        if ssf is None or not ssf_rev:
            return {"unresolved": f"shared-features revision unavailable ({how})"}
        path = f"{SSF_USER_MODELD}/{raw}.xcdatamodel/contents"
        blob = ssf.blob(ssf_rev, path)
        if blob is None:
            return {"unresolved": f"{raw} missing in shared-features {ssf_rev}"}
        return {"name": raw, "blob": blob, "repo": ssf.label, "path": path, "ssfRevision": ssf_rev}

    path = f"{USER_MODELD}/{raw}.xcdatamodel/contents"
    blob = repo.blob(rev, path)
    if blob is None:
        return {"unresolved": f"{raw} missing in {USER_MODELD}"}
    return {"name": raw, "blob": blob, "repo": repo.label, "path": path}


def version_key(tag):
    numbers = [int(part) for part in re.findall(r"\d+", tag)]
    return numbers, tag


def is_release_tag(tag):
    return re.fullmatch(r"\d+\.\d+\.\d+", tag) is not None


def tier_for(releases, interim_tags, heads):
    """appStore: an x.y.z release tag shipped it; testFlight: only build tags
    (x.y.z.n, -n, RC) or TestFlight heads did; development: untagged commits only."""
    if releases:
        return "appStore"
    if interim_tags or heads:
        return "testFlight"
    return "development"


def resolve_inventory(repos, ssf):
    """[(store, model, provenance)] for every tag, head and development commit."""
    observations = []
    tags_without_models = []
    unresolved = []
    for label in ("pub", "priv"):
        repo = repos.get(label)
        if repo is None:
            continue
        for tag in repo.tags():
            rev = repo.commit(f"refs/tags/{tag}")
            if rev is None:
                unresolved.append(f"{label}:{tag} is not a commit")
                continue
            found = False
            provenance = {"kind": "tag", "repo": label, "tag": tag, "commit": rev,
                          "time": repo.commit_time(rev)}
            substrate = substrate_model(repo, rev)
            if substrate:
                observations.append(("substrate", substrate, provenance))
                found = True
            user = user_model(repo, rev, ssf)
            if user and "unresolved" in user:
                unresolved.append(f"{label}:{tag} user model: {user['unresolved']}")
            elif user:
                observations.append(("user", user, provenance))
                found = True
            if not found:
                tags_without_models.append(f"{label}:{tag}")
    for label, commit, title in HEADS + DEVELOPMENT_COMMITS:
        repo = repos.get(label)
        rev = repo.commit(commit) if repo else None
        if rev is None:
            unresolved.append(f"{title} ({commit}) is not available in {label}")
            continue
        is_head = (label, commit, title) in HEADS
        provenance = {"kind": "head" if is_head else "development", "repo": label, "commit": rev,
                      "title": title, "time": repo.commit_time(rev)}
        substrate = substrate_model(repo, rev)
        if substrate:
            observations.append(("substrate", substrate, provenance))
        if is_head:
            user = user_model(repo, rev, ssf)
            if user and "unresolved" in user:
                unresolved.append(f"{title} user model: {user['unresolved']}")
            elif user:
                observations.append(("user", user, provenance))
    return observations, sorted(tags_without_models, key=lambda t: (t.split(":")[0], version_key(t.split(":")[1]))), unresolved


def momc_compile(source_dirs, output_dir):
    """Compiles <name>.xcdatamodel directories with the production momc flags."""
    staging = os.path.join(output_dir, "_sources")
    os.makedirs(staging, exist_ok=True)
    for name, path in source_dirs.items():
        target = os.path.join(staging, f"{name}.xcdatamodel")
        if os.path.abspath(path) != os.path.abspath(target):
            shutil.copytree(path, target)
    subprocess.run([os.path.join(SCRIPT_DIR, "compile-historical-store-models.sh"),
                    "--source-dir", staging, "--flat-output-dir", output_dir],
                   check=True, stdout=subprocess.DEVNULL)
    return {name: os.path.join(output_dir, f"{name}.mom") for name in source_dirs}


def build_tool(source, output, module_cache):
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=module_cache, SWIFT_MODULECACHE_PATH=module_cache)
    subprocess.run(["xcrun", "swiftc", os.path.join(SCRIPT_DIR, source), "-o", output],
                   check=True, env=env, stdout=subprocess.DEVNULL)
    return output


def digests(tool, paths):
    if not paths:
        return {}
    out = subprocess.run([tool] + list(paths), check=True, capture_output=True).stdout.decode()
    result = {}
    for line in out.splitlines():
        record = json.loads(line)
        result[record["path"]] = record
    return result


def lineage_digests(scratch, tool, store):
    """Digest of every version in this checkout's lineage .xcdatamodeld."""
    modeld = SUBSTRATE_MODELD if store == "substrate" else USER_MODELD
    sdk = subprocess.run(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], check=True,
                         capture_output=True).stdout.decode().strip()
    momd = os.path.join(scratch, "lineage", f"{store}.momd")
    os.makedirs(os.path.dirname(momd), exist_ok=True)
    subprocess.run(["xcrun", "momc", f"--sdkroot={sdk}", "--iphoneos-deployment-target", "14.1",
                    "--module", "fearless", "--no-warnings", os.path.join(ROOT_DIR, modeld), momd],
                   check=True, capture_output=True)
    moms = [os.path.join(momd, f) for f in sorted(os.listdir(momd)) if f.endswith(".mom")]
    return {os.path.basename(path)[:-4]: record["digest"] for path, record in digests(tool, moms).items()}


def bundled_resources(scratch, tool):
    """Digest of every model this checkout already recognises, per store."""
    resources = {store: lineage_digests(scratch, tool, store) for store in ("substrate", "user")}
    for store, compiled in (("substrate", SUBSTRATE_COMPATIBILITY_COMPILED), ("user", USER_COMPATIBILITY_COMPILED)):
        directory = os.path.join(ROOT_DIR, compiled)
        moms = [os.path.join(directory, f) for f in sorted(os.listdir(directory)) if f.endswith(".mom")]
        for path, record in digests(tool, moms).items():
            resources[store][os.path.basename(path)[:-4]] = record["digest"]
    return resources


def policy_for(store, digest):
    return POLICY[store].get(digest)


def build_manifest(observations, tags_without_models, repos, ssf, scratch):
    module_cache = os.path.join(scratch, "module-cache")
    os.makedirs(module_cache, exist_ok=True)
    digest_tool = build_tool("historical-model-digest.swift", os.path.join(scratch, "digest"), module_cache)

    repo_by_label = dict(repos)
    if ssf is not None:
        repo_by_label["ssf"] = ssf

    blobs = {}
    for store, model, provenance in observations:
        entry = blobs.setdefault((store, model["blob"]), {"store": store, "blob": model["blob"],
                                                            "models": [], "provenance": []})
        entry["models"].append(model)
        entry["provenance"].append(provenance)

    sources = os.path.join(scratch, "blobs")
    source_dirs = {}
    blob_bytes = {}
    for (store, blob), entry in blobs.items():
        model = entry["models"][0]
        data = repo_by_label[model["repo"]].blob_bytes(blob)
        if data is None:
            fail(f"cannot read {store} blob {blob} from {model['repo']}")
        blob_bytes[blob] = data
        directory = os.path.join(sources, f"{store}-{blob}.xcdatamodel")
        os.makedirs(directory, exist_ok=True)
        with open(os.path.join(directory, "contents"), "wb") as handle:
            handle.write(data)
        source_dirs[f"{store}-{blob}"] = directory

    compiled = momc_compile(source_dirs, os.path.join(scratch, "compiled"))
    records = digests(digest_tool, compiled.values())
    bundled = bundled_resources(scratch, digest_tool)

    by_digest = {}
    for (store, blob), entry in blobs.items():
        record = records[compiled[f"{store}-{blob}"]]
        group = by_digest.setdefault((store, record["digest"]), {"store": store, "digest": record["digest"],
                                                                 "versionChecksum": record["versionChecksum"],
                                                                 "blobs": []})
        if group["versionChecksum"] != record["versionChecksum"]:
            fail(f"{store} digest {record['digest']} has two version checksums")
        entry["firstTime"] = min(p["time"] for p in entry["provenance"])
        group["blobs"].append(entry)

    models = []
    for (store, digest), group in by_digest.items():
        group["blobs"].sort(key=lambda e: (e["firstTime"], e["blob"]))
        primary = group["blobs"][0]
        provenance = [p for e in group["blobs"] for p in e["provenance"]]
        releases = sorted({f"{p['repo']}:{p['tag']}" for p in provenance
                           if p["kind"] == "tag" and is_release_tag(p["tag"])},
                          key=lambda t: (version_key(t.split(":")[1]), t))
        interim = sorted({f"{p['repo']}:{p['tag']}" for p in provenance
                          if p["kind"] == "tag" and not is_release_tag(p["tag"])},
                         key=lambda t: (version_key(t.split(":")[1]), t))
        heads = sorted({(p["commit"], p["title"]) for p in provenance if p["kind"] == "head"})
        development = sorted({(p["commit"], p["title"]) for p in provenance if p["kind"] == "development"})
        tier = tier_for(releases, interim, heads)

        matches = sorted(name for name, d in bundled[store].items() if d == digest)
        if len(matches) > 1:
            fail(f"{store} digest {digest} matches several bundled models: {matches}")
        policy = policy_for(store, digest)
        entry = {
            "store": store,
            "digest": digest,
            "resource": RESOURCE_PREFIX[store] + digest,
            "gitBlob": primary["blob"],
            "equivalentGitBlobs": [e["blob"] for e in group["blobs"][1:]],
            "xmlSha256": hashlib.sha256(blob_bytes[primary["blob"]]).hexdigest(),
            "versionChecksum": group["versionChecksum"],
            "sourceRepo": primary["models"][0]["repo"],
            "sourcePath": primary["models"][0]["path"],
            "modelNames": sorted({m["name"] for e in group["blobs"] for m in e["models"]}),
            "tier": tier,
            "releases": releases,
            "interimTags": interim,
            "heads": [{"commit": c, "title": t} for c, t in heads],
            "developmentCommits": [{"commit": c, "title": t} for c, t in development],
            "matchesBundled": matches[0] if matches else None,
            "landing": None,
            "allowedDrops": None,
            "requiredConstants": {},
            "excluded": None,
        }
        if matches:
            if policy is not None:
                fail(f"{store} digest {digest} is bundled as {matches[0]} but also has a landing policy")
        elif policy is None:
            fail(f"{store} digest {digest} ({primary['blob']}, {entry['modelNames']}) is not recognised and "
                 f"has no reviewed policy; add a landing and allowedDrops to POLICY")
        elif "excluded" in policy:
            entry["excluded"] = policy["excluded"]
        else:
            entry["landing"] = policy["landing"]
            entry["allowedDrops"] = policy["allowedDrops"]
            entry["requiredConstants"] = dict(sorted(policy.get("requiredConstants", {}).items()))
        entry["_sort"] = (STORE_ORDER[store], primary["firstTime"], digest)
        models.append(entry)

    models.sort(key=lambda e: e["_sort"])
    for entry in models:
        del entry["_sort"]

    used = {(m["store"], m["digest"]) for m in models}
    for store, table in POLICY.items():
        for digest in table:
            if (store, digest) not in used:
                fail(f"POLICY entry {store} {digest} matches no inventoried model")

    manifest = {
        "format": "fearless.historical-store-models",
        "version": 1,
        "digestAlgorithm": "sha256 of the entity version hashes sorted by name as name=base64(hash) joined by ';', "
                  "first 16 hex characters",
        "momc": {"module": "fearless", "iphoneosDeploymentTarget": "14.1"},
        "sourceRepositories": {
            "pub": "fearless-iOS (public)",
            "priv": "fearless-iOS-priv (private App Store line)",
            "ssf": "shared-features-spm (SSFAccountManagmentStorage)",
        },
        "tagsWithoutStoreModels": tags_without_models,
        "models": models,
    }
    return manifest, blob_bytes


def write_outputs(manifest, blob_bytes, models_root, manifest_path):
    source_root = os.path.join(models_root, "Source")
    staging = tempfile.mkdtemp(prefix=".Source.", dir=models_root)
    try:
        for entry in manifest["models"]:
            directory = os.path.join(staging, f"{entry['resource']}.xcdatamodel")
            os.makedirs(directory)
            with open(os.path.join(directory, "contents"), "wb") as handle:
                # Verbatim blob; the repository's convention adds a final LF
                # to the blobs (all before 2026) that were written without one.
                data = blob_bytes[entry["gitBlob"]]
                handle.write(data if data.endswith(b"\n") else data + b"\n")
        if os.path.exists(source_root):
            shutil.rmtree(source_root)
        os.rename(staging, source_root)
    finally:
        if os.path.exists(staging):
            shutil.rmtree(staging)

    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=False)
        handle.write("\n")


def verify(manifest_path, observations, tags_without_models, unresolved, repos, ssf, scratch):
    with open(manifest_path, encoding="utf-8") as handle:
        manifest = json.load(handle)
    problems = list(unresolved)

    owner = {}
    for entry in manifest["models"]:
        for blob in [entry["gitBlob"]] + entry.get("equivalentGitBlobs", []):
            owner[(entry["store"], blob)] = entry

    seen_releases = {}
    for store, model, provenance in observations:
        entry = owner.get((store, model["blob"]))
        where = (f"{provenance['repo']}:{provenance['tag']}" if provenance["kind"] == "tag"
                 else f"{provenance['title']} {provenance['commit'][:9]}")
        if entry is None:
            problems.append(f"{where}: {store} model {model['name']} blob {model['blob']} has no manifest entry")
            continue
        seen_releases.setdefault(entry["resource"], set())
        if provenance["kind"] == "tag":
            seen_releases[entry["resource"]].add(f"{provenance['repo']}:{provenance['tag']}")
        else:
            key = "heads" if provenance["kind"] == "head" else "developmentCommits"
            if provenance["commit"] not in {h["commit"] for h in entry.get(key, [])}:
                problems.append(f"{where}: {entry['resource']} does not list this commit in {key}")

    for entry in manifest["models"]:
        recorded = set(entry.get("releases", [])) | set(entry.get("interimTags", []))
        actual = seen_releases.get(entry["resource"], set())
        for tag in sorted(actual - recorded):
            problems.append(f"{entry['resource']} is shipped by {tag} but the manifest does not list it")
        for tag in sorted(recorded - actual):
            problems.append(f"{entry['resource']} lists {tag} but that tag ships a different model")

    for entry in manifest["models"]:
        policy = policy_for(entry["store"], entry["digest"]) or {}
        expected = {
            "landing": policy.get("landing"),
            "allowedDrops": policy.get("allowedDrops"),
            "requiredConstants": dict(sorted(policy.get("requiredConstants", {}).items())),
            "excluded": policy.get("excluded"),
        }
        actual = {key: entry.get(key) for key in expected}
        if actual != expected and not (entry.get("matchesBundled") and not policy):
            problems.append(f"{entry['resource']}: manifest role {actual} differs from POLICY {expected}")
    for store, table in POLICY.items():
        for digest in table:
            if not any(e["store"] == store and e["digest"] == digest for e in manifest["models"]):
                problems.append(f"POLICY entry {store} {digest} has no manifest entry")

    if sorted(manifest.get("tagsWithoutStoreModels", [])) != sorted(tags_without_models):
        problems.append(f"tagsWithoutStoreModels differ: manifest={manifest.get('tagsWithoutStoreModels')} "
                        f"repos={tags_without_models}")

    problems.extend(verify_user_lineage_proxy(repos, ssf, scratch))

    if problems:
        for problem in problems:
            print(f"[historical-model-extract][error] {problem}", file=sys.stderr)
        sys.exit(1)
    tags = sum(1 for _, _, p in observations if p["kind"] == "tag")
    print(f"[historical-model-extract] Verified {tags} tag/store observations, "
          f"{len(HEADS)} heads and {len(DEVELOPMENT_COMMITS)} development commits against "
          f"{len(manifest['models'])} manifest entries")


def verify_user_lineage_proxy(repos, ssf, scratch):
    """The app opens User stores with the shared-features models; this checkout's
    UserDataModel.xcdatamodeld must hash identically, because the offline audit
    uses it as the User lineage."""
    if ssf is None:
        return ["shared-features repository is required to verify the User lineage"]
    pub = repos["pub"]
    revision, how = ssf_revision(pub, "HEAD", ssf)
    if not revision:
        return [f"cannot resolve the pinned shared-features revision ({how})"]
    listing = ssf.git("ls-tree", "--name-only", f"{revision}:{SSF_USER_MODELD}")
    if listing is None:
        return [f"shared-features {revision} has no {SSF_USER_MODELD}"]
    module_cache = os.path.join(scratch, "module-cache")
    os.makedirs(module_cache, exist_ok=True)
    tool = build_tool("historical-model-digest.swift", os.path.join(scratch, "digest-verify"), module_cache)

    source_dirs = {}
    for name in listing.decode().split():
        if not name.endswith(".xcdatamodel"):
            continue
        data = ssf.raw(revision, f"{SSF_USER_MODELD}/{name}/contents")
        directory = os.path.join(scratch, "ssf-user", name)
        os.makedirs(directory, exist_ok=True)
        with open(os.path.join(directory, "contents"), "wb") as handle:
            handle.write(data)
        source_dirs[f"ssf-{name[:-len('.xcdatamodel')]}"] = directory
    compiled = momc_compile(source_dirs, os.path.join(scratch, "ssf-user-compiled"))
    ssf_digests = {name[len("ssf-"):]: record["digest"]
                   for name, path in compiled.items()
                   for record in [digests(tool, [path])[path]]}
    local = lineage_digests(os.path.join(scratch, "proxy"), tool, "user")
    problems = []
    for name in sorted(set(ssf_digests) | set(local)):
        if local.get(name) != ssf_digests.get(name):
            problems.append(f"User lineage {name}: shared-features {revision[:10]} digest {ssf_digests.get(name)}, "
                            f"{USER_MODELD} digest {local.get(name)}")
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    main_checkout = os.path.dirname(os.path.abspath(
        subprocess.run(["git", "-C", ROOT_DIR, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                       capture_output=True, check=True).stdout.decode().strip()))
    parser.add_argument("--public-repo", default=os.environ.get("FEARLESS_IOS_PUBLIC_REPO", ROOT_DIR))
    parser.add_argument("--private-repo", default=os.environ.get(
        "FEARLESS_IOS_PRIVATE_REPO", os.path.join(os.path.dirname(main_checkout), "fearless-iOS-priv")))
    parser.add_argument("--ssf-repo", default=os.environ.get(
        "FEARLESS_SSF_REPO", os.path.join(main_checkout, "SourcePackages/repositories/shared-features-spm-6a339796")))
    parser.add_argument("--models-root", default=DEFAULT_MODELS_ROOT)
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST)
    parser.add_argument("--verify", action="store_true",
                        help="write nothing; fail unless the manifest records exactly the repositories' inventory")
    args = parser.parse_args()

    for label, path in (("public", args.public_repo), ("private", args.private_repo), ("shared-features", args.ssf_repo)):
        if not os.path.isdir(path):
            fail(f"{label} repository not found: {path}")
    repos = {"pub": Repository("pub", args.public_repo), "priv": Repository("priv", args.private_repo)}
    ssf = Repository("ssf", args.ssf_repo, bare=True)

    observations, tags_without_models, unresolved = resolve_inventory(repos, ssf)
    scratch = tempfile.mkdtemp(prefix="fearless-historical-models.")
    try:
        if args.verify:
            verify(args.manifest, observations, tags_without_models, unresolved, repos, ssf, scratch)
            return
        if unresolved:
            fail("unresolved store models:\n  " + "\n  ".join(unresolved))
        manifest, blob_bytes = build_manifest(observations, tags_without_models, repos, ssf, scratch)
        write_outputs(manifest, blob_bytes, args.models_root, args.manifest)
        counts = {store: sum(1 for m in manifest["models"] if m["store"] == store) for store in STORE_ORDER}
        print(f"[historical-model-extract] Wrote {counts['substrate']} Substrate and {counts['user']} User "
              f"models to {args.manifest}")
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
        for repo in list(repos.values()) + [ssf]:
            repo.close()


if __name__ == "__main__":
    main()
