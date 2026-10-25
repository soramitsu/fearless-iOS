#!/usr/bin/env python3
"""List the members of a (possibly fat) BSD ar archive as name, size, sha256.

usage: arlist.py <archive> [arch]   -> TSV on stdout
"""
import hashlib
import struct
import sys

FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
CPU = {0x0100000C: "arm64", 0x01000007: "x86_64"}


def slices(blob):
    magic = struct.unpack(">I", blob[:4])[0]
    if magic not in (FAT_MAGIC, FAT_MAGIC_64):
        yield "thin", blob
        return
    count = struct.unpack(">I", blob[4:8])[0]
    offset = 8
    for _ in range(count):
        if magic == FAT_MAGIC:
            cpu, _sub, start, size, _align = struct.unpack(">IIIII", blob[offset:offset + 20])
            offset += 20
        else:
            cpu, _sub, start, size, _align, _res = struct.unpack(">IIQQII", blob[offset:offset + 32])
            offset += 32
        yield CPU.get(cpu, hex(cpu)), blob[start:start + size]


def members(archive):
    assert archive[:8] == b"!<arch>\n", "not an ar archive"
    offset = 8
    while offset < len(archive):
        header = archive[offset:offset + 60]
        name = header[:16].decode().rstrip()
        size = int(header[48:58].decode().strip())
        body = archive[offset + 60:offset + 60 + size]
        if name.startswith("#1/"):
            length = int(name[3:])
            name = body[:length].rstrip(b"\0").decode()
            body = body[length:]
        yield name, body
        offset += 60 + size + (size & 1)


def main():
    blob = open(sys.argv[1], "rb").read()
    wanted = sys.argv[2] if len(sys.argv) > 2 else None
    for arch, data in slices(blob):
        if wanted and arch != wanted:
            continue
        for name, body in members(data):
            print("\t".join((arch, name, str(len(body)), hashlib.sha256(body).hexdigest())))


if __name__ == "__main__":
    main()
