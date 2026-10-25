#!/usr/bin/env python3
"""Cut a V14 runtime metadata blob down to the call enums of a few pallets.

The test fixtures under Tests/ come from live chains. The full blob is far too large to keep in the
repository, so this keeps only what call encoding needs and leaves everything the encoder reads
byte-for-byte as the chain published it:

* the selected pallets keep their name, module index and the variant list of their call enum
  (names, field types and variant indexes, including the gaps between indexes);
* every type reachable from those call enums is kept under its original id;
* generic parameters that point at a type outside that set (for example the runtime-wide
  ``RuntimeCall`` of ``VersionedXcm<RuntimeCall>``) are cleared, which scale-info allows
  (``Option<type>``), instead of dragging the whole runtime into the fixture;
* storage, events, errors, constants, signed extensions and documentation are dropped, and the
  extrinsic/runtime type ids are pointed at the first kept call enum.

The result is only meant for call encoding and decoding. Nothing else about the chain can be
learned from it.

Usage:
    trim-runtime-metadata.py --metadata state_getMetadata.json --pallet Balances --pallet PolkadotXcm \
        --out fixture.hex --manifest fixture.manifest.json --chain "Polkadot Asset Hub" \
        --genesis-hash 0x... --spec-version 2005000

``--metadata`` takes either the raw JSON-RPC response of ``state_getMetadata`` or a file with the
0x-prefixed hex string.
"""
import argparse
import hashlib
import json
import sys

PRIMITIVES = ['bool', 'char', 'str', 'u8', 'u16', 'u32', 'u64', 'u128', 'u256', 'i8', 'i16',
              'i32', 'i64', 'i128', 'i256']


class Reader:
    def __init__(self, data):
        self.data = data
        self.pos = 0

    def u8(self):
        value = self.data[self.pos]
        self.pos += 1
        return value

    def take(self, count):
        value = self.data[self.pos:self.pos + count]
        if len(value) != count:
            raise ValueError('metadata ends early')
        self.pos += count
        return value

    def u32(self):
        return int.from_bytes(self.take(4), 'little')

    def compact(self):
        mode = self.data[self.pos] & 3
        if mode == 0:
            value = self.data[self.pos] >> 2
            self.pos += 1
        elif mode == 1:
            value = int.from_bytes(self.data[self.pos:self.pos + 2], 'little') >> 2
            self.pos += 2
        elif mode == 2:
            value = int.from_bytes(self.data[self.pos:self.pos + 4], 'little') >> 2
            self.pos += 4
        else:
            length = (self.data[self.pos] >> 2) + 4
            self.pos += 1
            value = int.from_bytes(self.take(length), 'little')
        return value

    def string(self):
        return self.take(self.compact()).decode('utf-8')

    def option(self, read):
        tag = self.u8()
        if tag == 0:
            return None
        if tag != 1:
            raise ValueError('bad option tag %d' % tag)
        return read()

    def vec(self, read):
        return [read() for _ in range(self.compact())]


def write_compact(value):
    if value < 1 << 6:
        return bytes([value << 2])
    if value < 1 << 14:
        return ((value << 2) | 1).to_bytes(2, 'little')
    if value < 1 << 30:
        return ((value << 2) | 2).to_bytes(4, 'little')
    raw = value.to_bytes((value.bit_length() + 7) // 8, 'little')
    return bytes([((len(raw) - 4) << 2) | 3]) + raw


def write_string(value):
    raw = value.encode('utf-8')
    return write_compact(len(raw)) + raw


def write_option(value, write):
    return b'\x00' if value is None else b'\x01' + write(value)


def write_vec(values, write):
    return write_compact(len(values)) + b''.join(write(v) for v in values)


def read_field(r):
    return {'name': r.option(r.string), 'ty': r.compact(), 'type_name': r.option(r.string),
            'docs': r.vec(r.string)}


def read_type(r):
    path = r.vec(r.string)
    params = r.vec(lambda: {'name': r.string(), 'ty': r.option(r.compact)})
    tag = r.u8()
    if tag == 0:
        definition = {'kind': 'composite', 'fields': r.vec(lambda: read_field(r))}
    elif tag == 1:
        def read_variant():
            return {'name': r.string(), 'fields': r.vec(lambda: read_field(r)), 'index': r.u8(),
                    'docs': r.vec(r.string)}
        definition = {'kind': 'variant', 'variants': r.vec(read_variant)}
    elif tag == 2:
        definition = {'kind': 'sequence', 'ty': r.compact()}
    elif tag == 3:
        definition = {'kind': 'array', 'len': r.u32(), 'ty': r.compact()}
    elif tag == 4:
        definition = {'kind': 'tuple', 'tys': r.vec(r.compact)}
    elif tag == 5:
        definition = {'kind': 'primitive', 'primitive': r.u8()}
    elif tag == 6:
        definition = {'kind': 'compact', 'ty': r.compact()}
    elif tag == 7:
        definition = {'kind': 'bitsequence', 'store': r.compact(), 'order': r.compact()}
    else:
        raise ValueError('bad type definition tag %d' % tag)
    docs = r.vec(r.string)
    return {'path': path, 'params': params, 'def': definition, 'docs': docs}


def read_storage_entry(r):
    r.string()
    r.u8()
    if r.u8() == 0:
        r.compact()
    else:
        r.vec(r.u8)
        r.compact()
        r.compact()
    r.vec(r.u8)
    r.vec(r.string)


def parse(blob):
    if blob[:4] != b'meta':
        raise ValueError('not a runtime metadata blob')
    r = Reader(blob)
    r.pos = 4
    version = r.u8()
    if version != 14:
        raise ValueError('only V14 metadata is supported, got V%d' % version)

    types = {}
    for _ in range(r.compact()):
        type_id = r.compact()
        types[type_id] = read_type(r)

    pallets = []
    for _ in range(r.compact()):
        name = r.string()
        r.option(lambda: (r.string(), r.vec(lambda: read_storage_entry(r))))
        calls = r.option(r.compact)
        r.option(r.compact)
        r.vec(lambda: (r.string(), r.compact(), r.vec(r.u8), r.vec(r.string)))
        r.option(r.compact)
        index = r.u8()
        pallets.append({'name': name, 'index': index, 'calls': calls})

    r.compact()
    r.u8()
    r.vec(lambda: (r.string(), r.compact(), r.compact()))
    r.compact()
    if r.pos != len(blob):
        raise ValueError('%d unread bytes after the metadata' % (len(blob) - r.pos))
    return {'types': types, 'pallets': pallets}


def referenced_types(definition):
    kind = definition['kind']
    if kind == 'composite':
        return [f['ty'] for f in definition['fields']]
    if kind == 'variant':
        return [f['ty'] for v in definition['variants'] for f in v['fields']]
    if kind in ('sequence', 'array', 'compact'):
        return [definition['ty']]
    if kind == 'tuple':
        return list(definition['tys'])
    if kind == 'bitsequence':
        return [definition['store'], definition['order']]
    return []


def reachable(types, roots):
    seen = set()
    stack = list(roots)
    while stack:
        type_id = stack.pop()
        if type_id in seen:
            continue
        seen.add(type_id)
        stack.extend(referenced_types(types[type_id]['def']))
    return seen


def write_field(f):
    return (write_option(f['name'], write_string) + write_compact(f['ty'])
            + write_option(f['type_name'], write_string) + write_vec([], write_string))


def write_type(t):
    out = write_vec(t['path'], write_string)
    out += write_vec(t['params'], lambda p: write_string(p['name'])
                     + write_option(p['ty'], write_compact))
    d = t['def']
    kind = d['kind']
    if kind == 'composite':
        out += b'\x00' + write_vec(d['fields'], write_field)
    elif kind == 'variant':
        out += b'\x01' + write_vec(
            d['variants'],
            lambda v: write_string(v['name']) + write_vec(v['fields'], write_field)
            + bytes([v['index']]) + write_vec([], write_string))
    elif kind == 'sequence':
        out += b'\x02' + write_compact(d['ty'])
    elif kind == 'array':
        out += b'\x03' + d['len'].to_bytes(4, 'little') + write_compact(d['ty'])
    elif kind == 'tuple':
        out += b'\x04' + write_vec(d['tys'], write_compact)
    elif kind == 'primitive':
        out += b'\x05' + bytes([d['primitive']])
    elif kind == 'compact':
        out += b'\x06' + write_compact(d['ty'])
    else:
        out += b'\x07' + write_compact(d['store']) + write_compact(d['order'])
    return out + write_vec([], write_string)


def trim(parsed, pallet_names):
    types = parsed['types']
    kept = []
    for name in pallet_names:
        matches = [p for p in parsed['pallets'] if p['name'] == name]
        if len(matches) != 1 or matches[0]['calls'] is None:
            raise ValueError('pallet %s not found or has no calls' % name)
        kept.append(matches[0])
    kept.sort(key=lambda p: parsed['pallets'].index(p))

    keep_ids = reachable(types, [p['calls'] for p in kept])
    trimmed = {}
    for type_id in sorted(keep_ids):
        t = types[type_id]
        params = [{'name': p['name'], 'ty': p['ty'] if p['ty'] in keep_ids else None}
                  for p in t['params']]
        trimmed[type_id] = {'path': t['path'], 'params': params, 'def': t['def'], 'docs': []}

    anchor = kept[0]['calls']
    out = b'meta' + bytes([14])
    out += write_compact(len(trimmed))
    for type_id in sorted(trimmed):
        out += write_compact(type_id) + write_type(trimmed[type_id])
    out += write_compact(len(kept))
    for p in kept:
        out += write_string(p['name']) + b'\x00' + b'\x01' + write_compact(p['calls'])
        out += b'\x00' + write_vec([], lambda c: b'') + b'\x00' + bytes([p['index']])
    out += write_compact(anchor) + b'\x04' + write_vec([], lambda s: b'') + write_compact(anchor)
    return out, kept, trimmed


def call_table(parsed, pallet):
    variants = parsed['types'][pallet['calls']]['def']['variants']
    return [{'name': v['name'], 'index': v['index'], 'position': position,
             'fields': [f['name'] for f in v['fields']]}
            for position, v in enumerate(variants)]


def load_hex(path):
    text = open(path).read().strip()
    if text.startswith('{'):
        text = json.loads(text)['result']
    if text.startswith('0x'):
        text = text[2:]
    return bytes.fromhex(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--metadata', required=True)
    ap.add_argument('--pallet', action='append', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--manifest', required=True)
    ap.add_argument('--chain', required=True)
    ap.add_argument('--genesis-hash', required=True)
    ap.add_argument('--spec-version', type=int, required=True)
    ap.add_argument('--fetched', required=True, help='date the metadata was fetched, YYYY-MM-DD')
    args = ap.parse_args()

    source = load_hex(args.metadata)
    parsed = parse(source)
    trimmed_blob, kept, trimmed_types = trim(parsed, args.pallet)

    # The trimmed blob must parse again, keep every call table intact and resolve every type id.
    again = parse(trimmed_blob)
    for original in kept:
        copy = [p for p in again['pallets'] if p['name'] == original['name']][0]
        assert copy['index'] == original['index']
        assert call_table(again, copy) == call_table(parsed, original)
    for t in again['types'].values():
        for ref in referenced_types(t['def']) + [p['ty'] for p in t['params'] if p['ty'] is not None]:
            assert ref in again['types'], 'dangling type id %d' % ref

    with open(args.out, 'w') as handle:
        handle.write('0x' + trimmed_blob.hex() + '\n')

    manifest = {
        'chain': args.chain,
        'genesisHash': args.genesis_hash,
        'specVersion': args.spec_version,
        'fetched': args.fetched,
        'source': 'state_getMetadata (V14)',
        'sourceBytes': len(source),
        'sourceSha256': hashlib.sha256(source).hexdigest(),
        'fixtureBytes': len(trimmed_blob),
        'fixtureSha256': hashlib.sha256(trimmed_blob).hexdigest(),
        'typeCount': {'source': len(parsed['types']), 'fixture': len(trimmed_types)},
        'pallets': [{'name': p['name'], 'moduleIndex': p['index'], 'calls': call_table(parsed, p)}
                    for p in kept],
    }
    with open(args.manifest, 'w') as handle:
        json.dump(manifest, handle, indent=2)
        handle.write('\n')
    print('%s: %d -> %d bytes, %d -> %d types' % (
        args.chain, len(source), len(trimmed_blob), len(parsed['types']), len(trimmed_types)))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, AssertionError) as error:
        sys.exit('error: %s' % error)
