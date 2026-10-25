#!/usr/bin/env python3
"""Trace the replaced libed25519 and blake2lib XCFramework objects to published build outputs.

Reads the previous frameworks from git history and fetches the archives Soramitsu
committed to soramitsu/ios-crypto and the build directory committed to
ERussel/ed25519. Every object in every slice must be code-identical to its
counterpart: equal non-debug section bytes, relocations (resolved to symbol or
section targets), symbols, unwind data and platform. The frameworks were relinked,
so DWARF, temporary labels, relocation order and encoding, and padded unwind
lengths may differ; their simulator arm64 objects also carry a rewritten platform
load command, which is reported. The ERussel archives must contain byte-identical
members. Embedded compiler command lines and the CMake version string are printed.
"""

import argparse
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LEGACY_REVISION = "eebd107feb8a8899fbd09f1ff41d313a20d895cd"
IOS_CRYPTO = "https://github.com/soramitsu/ios-crypto.git"
ERUSSEL_ED25519 = "https://github.com/ERussel/ed25519.git"
# (repository, revision, path) of each archive the framework objects came from.
SOURCES = {
    "iroha-ed25519": (IOS_CRYPTO, "95be0acf53a6520d5ed289fdec83bc128fbc7f7e", "IrohaCryptoImp/libed25519.a"),
    "ed25519-sha2": (IOS_CRYPTO, "b17867294577e862e867cd3f984c3a15054b9bd0", "ed25519Imp/libed25519_sha2.a"),
    "blake2": (IOS_CRYPTO, "d593430ed915c01466c539f84479924bc8ee8c6d", "blake2Imp/libblake2.a"),
}
ERUSSEL_BUILD = ("8cce03c086af04af5577ca452f43868fb4b9cb26", {
    "arm64": "build/Debug-iphoneos/libed25519_sha2.a",
    "x86_64": "build/Debug-iphonesimulator/libed25519_sha2.a",
})
SLICES = ("ios-arm64", "ios-arm64_x86_64-simulator")

LC_SEGMENT_64, LC_SYMTAB = 0x19, 0x2
LC_VERSION_MIN_IPHONEOS, LC_BUILD_VERSION = 0x25, 0x32
LC_DATA_IN_CODE, LC_LINKER_OPTIMIZATION_HINT = 0x29, 0x2E
N_STAB, N_EXT, N_TYPE, N_SECT = 0xE0, 0x01, 0x0E, 0x0E
CPU_TYPE_ARM64, CPU_TYPE_X86_64 = 0x0100000C, 0x01000007
ARM64_RELOC_SUBTRACTOR, ARM64_RELOC_ADDEND, X86_64_RELOC_SUBTRACTOR = 1, 10, 5
X86_64_PCREL_EXTRA = {6: 1, 7: 2, 8: 4}  # SIGNED_1/2/4: immediate bytes after the displacement
S_ATTR_SOME_INSTRUCTIONS = 0x400


# Mach-O object comparison ------------------------------------------------------------

def parse(data, name):
    magic, cputype, _, _, ncmds = struct.unpack_from("<IiiII", data, 0)
    if magic != 0xFEEDFACF:
        raise SystemExit(f"{name}: not a 64-bit Mach-O object")
    offset, sections, platform, linkedit = 32, [], [], {}
    symoff = nsyms = stroff = 0
    for _ in range(ncmds):
        command, size = struct.unpack_from("<II", data, offset)
        if command == LC_SEGMENT_64:
            cursor = offset + 72
            for _ in range(struct.unpack_from("<I", data, offset + 64)[0]):
                section = data[cursor:cursor + 16].rstrip(b"\0").decode()
                segment = data[cursor + 16:cursor + 32].rstrip(b"\0").decode()
                address, length, fileoff, align, reloff, nreloc, flags = struct.unpack_from(
                    "<QQIIIII", data, cursor + 32)
                zerofill = (flags & 0xFF) in (0x1, 0xC, 0x12)
                sections.append(dict(
                    name=f"{segment},{section}", addr=address, size=length, align=align, flags=flags,
                    content=b"" if zerofill else data[fileoff:fileoff + length],
                    relocs=[struct.unpack_from("<iI", data, reloff + 8 * i) for i in range(nreloc)]))
                cursor += 80
        elif command == LC_SYMTAB:
            symoff, nsyms, stroff, _ = struct.unpack_from("<IIII", data, offset + 8)
        elif command in (LC_VERSION_MIN_IPHONEOS, LC_BUILD_VERSION):
            platform.append(data[offset:offset + size].hex())
        elif command in (LC_DATA_IN_CODE, LC_LINKER_OPTIMIZATION_HINT):
            dataoff, datasize = struct.unpack_from("<II", data, offset + 8)
            if datasize:
                linkedit[command] = data[dataoff:dataoff + datasize]
        offset += size
    symbols = []
    for i in range(nsyms):
        strx, kind, section, desc, value = struct.unpack_from("<IBBHQ", data, symoff + 16 * i)
        end = data.index(b"\0", stroff + strx)
        symbols.append(dict(name=data[stroff + strx:end].decode(), type=kind, sect=section, desc=desc, value=value))
    return dict(name=name, cputype=cputype, sections=sections, syms=symbols, platform=platform, linkedit=linkedit)


def target(obj, number, external):
    if external:
        symbol = obj["syms"][number]
        if (symbol["type"] & N_TYPE) == N_SECT:
            section = obj["sections"][symbol["sect"] - 1]
            return section["name"], symbol["value"] - section["addr"]
        return symbol["name"], 0
    section = obj["sections"][number - 1]
    return section["name"], -section["addr"]


def normalized_relocations(obj, section):
    """Relocations as layout-independent targets, with the fixed-up bytes masked or folded."""
    content = bytearray(section["content"])
    raw = []
    for address, info in section["relocs"]:
        if address < 0:
            raise SystemExit(f"{obj['name']}: scattered relocation")
        raw.append((address, info & 0xFFFFFF, (info >> 24) & 1, (info >> 25) & 3, (info >> 27) & 1, info >> 28))
    subtractor = ARM64_RELOC_SUBTRACTOR if obj["cputype"] == CPU_TYPE_ARM64 else X86_64_RELOC_SUBTRACTOR
    result, addend, i = [], None, 0
    while i < len(raw):
        address, number, pcrel, length, external, kind = raw[i]
        width = 1 << length
        stored = int.from_bytes(content[address:address + width], "little", signed=True)
        if obj["cputype"] == CPU_TYPE_ARM64 and kind == ARM64_RELOC_ADDEND:
            addend, i = number, i + 1
            continue
        if kind == subtractor:
            _, minuend_number, _, _, minuend_external, minuend_kind = raw[i + 1]
            if raw[i + 1][0] != address or minuend_kind != 0:
                raise SystemExit(f"{obj['name']}: unpaired SUBTRACTOR at {address}")
            subtrahend = target(obj, number, external)
            minuend = target(obj, minuend_number, minuend_external)
            if subtrahend[0] == minuend[0]:
                # Same-section difference: a constant, often stored as a literal instead.
                constant = minuend[1] + stored - subtrahend[1]
                content[address:address + width] = constant.to_bytes(width, "little", signed=True)
            else:
                content[address:address + width] = bytes(width)
                relative = minuend[1] + stored + address - subtrahend[1]
                result.append((address, length, "field-relative", (minuend[0], relative)))
            i += 2
            continue
        if obj["cputype"] == CPU_TYPE_X86_64 and pcrel and width == 4:
            extra = X86_64_PCREL_EXTRA.get(kind, 0)
            if external:
                name, offset = target(obj, number, external)
                offset += stored + extra
            else:
                absolute = section["addr"] + address + 4 + extra + stored
                owner = next(s for s in obj["sections"] if s["addr"] <= absolute < s["addr"] + max(s["size"], 1))
                name, offset = owner["name"], absolute - owner["addr"]
            content[address:address + width] = bytes(width)
            result.append((address, pcrel, length, kind, (name, offset), addend))
            i += 1
            continue
        unsigned = kind == 0 and not pcrel and width in (4, 8)
        name, offset = target(obj, number, external)
        if not external:
            offset = offset + stored if unsigned else 0
        elif unsigned:
            offset += stored
        if unsigned:
            content[address:address + width] = bytes(width)
        result.append((address, pcrel, length, kind, (name, offset), addend))
        addend, i = None, i + 1
    if section["name"] == "__LD,__compact_unwind":
        # Entry lengths may or may not include the padding after each function.
        for entry in range(0, len(content), 32):
            content[entry + 8:entry + 12] = bytes(4)
    return sorted(result, key=repr), bytes(content)


def resolved(obj, section):
    content = bytearray(section["content"])
    subtractor = ARM64_RELOC_SUBTRACTOR if obj["cputype"] == CPU_TYPE_ARM64 else X86_64_RELOC_SUBTRACTOR
    entries = [(a, info & 0xFFFFFF, (info >> 25) & 3, (info >> 27) & 1, info >> 28) for a, info in section["relocs"]]

    def address_of(number, external):
        if not external:
            return 0
        symbol = obj["syms"][number]
        if (symbol["type"] & N_TYPE) != N_SECT:
            raise SystemExit(f"{obj['name']}: __eh_frame refers to undefined {symbol['name']}")
        return symbol["value"]

    i = 0
    while i < len(entries):
        address, number, length, external, kind = entries[i]
        width = 1 << length
        stored = int.from_bytes(content[address:address + width], "little", signed=True)
        if kind == subtractor:
            _, minuend, _, minuend_external, _ = entries[i + 1]
            value = address_of(minuend, minuend_external) + stored - address_of(number, external)
            i += 2
        elif kind == 0:
            value = stored + address_of(number, external)
            i += 1
        else:
            raise SystemExit(f"{obj['name']}: unexpected __eh_frame relocation {kind}")
        content[address:address + width] = (value & ((1 << (8 * width)) - 1)).to_bytes(width, "little")
    return bytes(content)


def eh_frame_records(obj, section):
    """CIE/FDE records with each FDE's pc_begin mapped to (section, offset)."""
    data, base, records, cies, position = resolved(obj, section), section["addr"], [], {}, 0
    while position < len(data):
        length = struct.unpack_from("<I", data, position)[0]
        if length == 0:
            records.append(("terminator",))
            break
        body = data[position + 4:position + 4 + length]
        pointer = struct.unpack_from("<I", body, 0)[0]
        if pointer == 0:
            if body[5:body.index(b"\0", 5)] != b"zR":
                raise SystemExit(f"{obj['name']}: unsupported CIE augmentation")
            cies[position] = len(records)
            records.append(("cie", body))
        else:
            begin = base + position + 8 + struct.unpack_from("<q", body, 4)[0]
            owner = next(s for s in obj["sections"] if s["addr"] <= begin < s["addr"] + max(s["size"], 1))
            records.append(("fde", cies[position + 4 - pointer], owner["name"], begin - owner["addr"],
                            struct.unpack_from("<Q", body, 12)[0], body[20:]))
        position += 4 + length
    return records


def temporary(name):
    return name.startswith(("ltmp", "L", "l", "EH_Frame")) or name == "func.eh"


def symbols(obj):
    result = []
    for symbol in obj["syms"]:
        if symbol["type"] & N_STAB or (not symbol["type"] & N_EXT and temporary(symbol["name"])):
            continue
        where, value = None, symbol["value"]
        if (symbol["type"] & N_TYPE) == N_SECT:
            section = obj["sections"][symbol["sect"] - 1]
            where, value = section["name"], value - section["addr"]
        result.append((symbol["name"], symbol["type"], where, symbol["desc"], value))
    return sorted(result)


def flags(section):
    if section["name"] == "__TEXT,__eh_frame":
        return 0
    return section["flags"] & ~S_ATTR_SOME_INSTRUCTIONS if section["size"] == 0 else section["flags"]


def code_identical(a, b):
    """Return the differences between two objects that matter for the code they link."""
    differences = []
    if a["cputype"] != b["cputype"]:
        differences.append("CPU type")
    keep = lambda obj: {s["name"]: s for s in obj["sections"] if not s["name"].startswith("__DWARF,")}
    left, right = keep(a), keep(b)
    for name in sorted(set(left) | set(right)):
        if name not in left or name not in right:
            differences.append(f"{name} present in one object only")
            continue
        x, y = left[name], right[name]
        if name == "__TEXT,__eh_frame":
            if eh_frame_records(a, x) != eh_frame_records(b, y):
                differences.append(name)
            continue
        if normalized_relocations(a, x) != normalized_relocations(b, y) or x["size"] != y["size"] \
                or (x["align"], flags(x)) != (y["align"], flags(y)):
            differences.append(name)
    if symbols(a) != symbols(b):
        differences.append("symbols")
    if a["linkedit"] != b["linkedit"]:
        differences.append("data-in-code or linker hints")
    return differences


# Archives ----------------------------------------------------------------------------

def run(*args):
    return subprocess.run(args, check=True, capture_output=True)


def archive_members(data, arch, stage, label):
    """Members of one architecture of a (possibly universal) static archive."""
    folder = stage / label
    folder.mkdir(parents=True)
    archive = folder / "archive.a"
    archive.write_bytes(data)
    if b"Non-fat" not in run("lipo", "-info", str(archive)).stdout:
        run("lipo", "-thin", arch, str(archive), "-output", str(folder / "thin.a"))
        archive = folder / "thin.a"
    names = run("ar", "-t", str(archive)).stdout.decode().split()
    subprocess.run(["ar", "-x", str(archive)], check=True, cwd=folder)
    return {name: (folder / name).read_bytes() for name in names if name.endswith(".o")}


def fetch(repository, revision, cache):
    checkout = cache / revision
    if not checkout.exists():
        run("git", "init", "--quiet", str(checkout))
        run("git", "-C", str(checkout), "fetch", "--quiet", "--depth", "1", repository, revision)
    return checkout


def show(checkout, revision, path):
    return run("git", "-C", str(checkout), "show", f"{revision}:{path}").stdout


def legacy(path):
    if subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", f"{LEGACY_REVISION}^{{commit}}"],
                      capture_output=True).returncode:
        run("git", "-C", str(ROOT), "fetch", "--quiet", "--depth", "1", "origin", LEGACY_REVISION)
    return show(ROOT, LEGACY_REVISION, path)


def section(obj, name):
    return next((s["content"] for s in obj["sections"] if s["name"] == name), b"")


def platform(obj):
    raw = bytes.fromhex(obj["platform"][0])
    command = struct.unpack_from("<I", raw, 0)[0]
    if command == LC_BUILD_VERSION:
        kind, minos, sdk = struct.unpack_from("<III", raw, 8)
        name = {2: "iOS", 7: "iOS Simulator"}.get(kind, str(kind))
    else:
        minos, sdk = struct.unpack_from("<II", raw, 8)
        name = "iOS (LC_VERSION_MIN)"
    version = lambda value: f"{value >> 16}.{(value >> 8) & 0xFF}" if value else "n/a"
    return f"{name} min {version(minos)} sdk {version(sdk)}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print the per-object results as JSON")
    args = parser.parse_args()
    report, problems = [], []
    with tempfile.TemporaryDirectory(prefix="ed25519-blake2-trace-") as temporary_folder:
        stage = Path(temporary_folder)
        cache = stage / "upstream"
        cache.mkdir()
        references = {}
        for label, (repository, revision, path) in SOURCES.items():
            data = show(fetch(repository, revision, cache), revision, path)
            for arch in ("arm64", "x86_64"):
                members = archive_members(data, arch, stage, f"{label}-{arch}")
                references.update({(arch, name): (label, member) for name, member in members.items()})
        erussel = fetch(ERUSSEL_ED25519, ERUSSEL_BUILD[0], cache)
        for arch, path in ERUSSEL_BUILD[1].items():
            built = archive_members(show(erussel, ERUSSEL_BUILD[0], path), arch, stage, f"erussel-{arch}")
            for name, data in built.items():
                committed = references[(arch, name)][1]
                if data != committed:
                    problems.append(f"ERussel/ed25519 {path}:{name} differs from ios-crypto's {name}")
            report.append(dict(check=f"ERussel/ed25519@{ERUSSEL_BUILD[0][:7]}:{path}",
                               identical_members=len(built)))

        for library in ("libed25519", "blake2lib"):
            for slice_name in SLICES:
                path = f"Binaries/{library}.xcframework/{slice_name}/{library}.framework/{library}"
                data = legacy(path)
                for arch in ("arm64", "x86_64") if "simulator" in slice_name else ("arm64",):
                    members = archive_members(data, arch, stage, f"legacy-{library}-{slice_name}-{arch}")
                    for name, member in sorted(members.items()):
                        shipped = parse(member, f"{path}({arch}):{name}")
                        entry = dict(object=f"{library}/{slice_name}/{arch}/{name}", platform=platform(shipped),
                                     cmdline=section(shipped, "__LLVM,__cmdline").replace(b"\0", b" ").decode().strip())
                        if name.endswith("_vers.o"):
                            entry["source"] = "Xcode-generated version symbols"
                        elif (arch, name) not in references:
                            problems.append(f"{entry['object']}: no counterpart in the published archives")
                            entry["source"] = None
                        else:
                            label, reference = references[(arch, name)]
                            differences = code_identical(shipped, parse(reference, name))
                            entry["source"] = SOURCES[label][2] + "@" + SOURCES[label][1][:7]
                            entry["platform_rewritten"] = shipped["platform"] != parse(reference, name)["platform"]
                            if differences:
                                problems.append(f"{entry['object']}: differs from {entry['source']} "
                                                f"in {', '.join(differences)}")
                        if name == "ed25519_dummy.c.o":
                            entry["version_string"] = section(shipped, "__TEXT,__cstring").rstrip(b"\0").decode()
                        report.append(entry)

    if args.json:
        print(json.dumps(report, indent=1))
    else:
        objects = [entry for entry in report if "object" in entry]
        for library in ("libed25519", "blake2lib"):
            for slice_name in SLICES:
                rows = [e for e in objects if e["object"].startswith(f"{library}/{slice_name}/")]
                for arch in ("arm64", "x86_64"):
                    selected = [e for e in rows if f"/{arch}/" in e["object"]]
                    if not selected:
                        continue
                    sources = sorted({e["source"] or "unknown" for e in selected})
                    rewritten = sum(bool(e.get("platform_rewritten")) for e in selected)
                    note = f"; {rewritten} with a rewritten platform ({selected[-1]['platform']})" if rewritten else ""
                    print(f"{library} {slice_name} {arch}: {len(selected)} objects from {', '.join(sources)}{note}")
        for flags_line in sorted({e["cmdline"] for e in objects if e["cmdline"]}):
            print(f"embedded compile flags: {flags_line}")
        for e in objects:
            if "version_string" in e:
                print(f"{e['object']}: {e['version_string']}")
                break
        for entry in report:
            if "check" in entry:
                print(f"{entry['check']}: {entry['identical_members']} members byte-identical to ios-crypto")
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print("Every replaced object is code-identical to a published Soramitsu build output")
    return 0


if __name__ == "__main__":
    sys.exit(main())
