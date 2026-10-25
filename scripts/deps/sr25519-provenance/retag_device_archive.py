#!/usr/bin/env python3
"""Mark an iOS *device* arm64 static archive as iOS-simulator so its machine code can
be linked into a process that runs in the arm64 simulator on Apple silicon.

Only the load command that names the platform is touched, in place:
- LC_BUILD_VERSION: the 4-byte `platform` field, 2 (iOS) -> 7 (iOS simulator);
- LC_VERSION_MIN_IPHONEOS (older objects, 16 bytes, no platform field): the command id
  becomes LC_SOURCE_VERSION (also 16 bytes, ignored by the linker), so the object no
  longer claims a platform.
No code, data, symbol or offset changes, and the script proves that by diffing input and
output byte by byte.

usage: retag_device_archive.py <device-archive> <output-archive>
"""
import struct
import sys

MH_MAGIC_64 = 0xFEEDFACF
LC_BUILD_VERSION = 0x32
LC_VERSION_MIN_IPHONEOS = 0x25
LC_SOURCE_VERSION = 0x2A
LC_VERSION_MIN_OTHER = {0x24: "macosx", 0x2F: "tvos", 0x30: "watchos"}
PLATFORM_IOS = 2
PLATFORM_IOSSIMULATOR = 7


def members(archive):
    assert archive[:8] == b"!<arch>\n", "not a thin ar archive"
    offset = 8
    while offset < len(archive):
        header = archive[offset:offset + 60]
        name = header[:16].decode().rstrip()
        size = int(header[48:58].decode().strip())
        body = offset + 60
        if name.startswith("#1/"):
            length = int(name[3:])
            name = archive[body:body + length].rstrip(b"\0").decode()
            body += length
            size -= length
        yield name, body, size
        offset = body + size
        offset += offset & 1


def main():
    source, destination = sys.argv[1:3]
    data = bytearray(open(source, "rb").read())
    original = bytes(data)
    objects = patched = neutralised = 0
    for name, start, size in members(original):
        if size < 32 or struct.unpack_from("<I", data, start)[0] != MH_MAGIC_64:
            continue
        objects += 1
        _magic, cputype, _sub, _filetype, ncmds, _sizeofcmds, _flags, _res = struct.unpack_from("<8I", data, start)
        assert cputype == 0x0100000C, f"{name}: not arm64"
        command = start + 32
        seen = False
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from("<II", data, command)
            if cmd in LC_VERSION_MIN_OTHER:
                raise SystemExit(f"{name}: built for {LC_VERSION_MIN_OTHER[cmd]}, not iOS")
            if cmd == LC_VERSION_MIN_IPHONEOS:
                assert cmdsize == 16, f"{name}: unexpected LC_VERSION_MIN size {cmdsize}"
                struct.pack_into("<I", data, command, LC_SOURCE_VERSION)
                seen = True
                neutralised += 1
            if cmd == LC_BUILD_VERSION:
                platform = struct.unpack_from("<I", data, command + 8)[0]
                assert platform == PLATFORM_IOS, f"{name}: platform {platform}, expected iOS device"
                struct.pack_into("<I", data, command + 8, PLATFORM_IOSSIMULATOR)
                seen = True
                patched += 1
            command += cmdsize
        if not seen:
            # Objects without a build version (empty codegen units) link on any platform.
            pass
    changed = [i for i in range(len(original)) if original[i] != data[i]]
    assert len(changed) == patched + neutralised, (len(changed), patched, neutralised)
    assert all((original[i], data[i]) in ((PLATFORM_IOS, PLATFORM_IOSSIMULATOR),
                                          (LC_VERSION_MIN_IPHONEOS, LC_SOURCE_VERSION)) for i in changed)
    open(destination, "wb").write(data)
    print(f"{source}: {objects} Mach-O members; {patched} LC_BUILD_VERSION platform fields "
          f"rewritten iOS->iOS simulator; {neutralised} LC_VERSION_MIN_IPHONEOS commands "
          f"neutralised; {len(changed)} of {len(original)} bytes changed")


if __name__ == "__main__":
    main()
