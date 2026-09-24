#!/usr/bin/env python3
"""Read generated service settings without evaluating Swift or exposing values.

This checks configuration shape and build continuity, not provider authorization.
Actual production-key provenance and service qualification remain release inputs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import sys

PREFIX = '[ios-release-service-configuration]'
# Active Release credential consumers: ChainRegistry,
# WalletConnectService, Google backup, Alchemy and Etherscan V2 history.
REQUIRED = frozenset({
    'TonNodeApiKey.tonApiKey',
    'WalletConnect.projectId',
    'GoogleBackup.googleToken',
    'GoogleBackup.googleUrlScheme',
    'ThirdPartyServicesApiKeys.alchemyApiKey',
    'BlockExplorerApiKeys.etherscanApiKey',
})
# Retired Blast/Goerli fields are no longer consumed by EVM node selection.
# Dwellir is optional with catalog failover. Retired chain-specific explorer
# keys remain in the generated schema for compatibility but are not needed by
# Etherscan V2 history. Rejected OKLink credentials are omitted;
# replacement history providers and explicit explorer recovery handle its catalog routes.
# These, Debug credentials and optional partner/card integrations may be empty.
# No generated setting may contain a nonempty placeholder.
PLACEHOLDER = re.compile(
    r'^(?:true|false|yes|no|nil|null|none|undefined|0|1|todo|tbd|dummy|placeholder|'
    r'changeme|change[-_ ]?me|replace[-_ ]?me|test|testing|example|sample|'
    r'your[-_ ].*|<.*>|\$.*|.*\{\{.*|.*\}\}.*)$', re.IGNORECASE)
CLIENT_ID = re.compile(r'[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com')
GOOGLE_SCHEME = re.compile(r'com\.googleusercontent\.apps\.[0-9]+-[A-Za-z0-9_-]+')


class AuditFailure(Exception):
    """Only predefined nonsecret diagnostics may be placed in this exception."""


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_file(path, label):
    if path.is_symlink() or not path.is_file():
        raise AuditFailure(label + ' must be a regular nonsymlink file')
    return path.read_bytes()


def parse_declarations(data, template=False):
    """Accept only the generated enum/String-literal grammar; fail closed."""
    source = data.decode('utf-8')
    declarations, enums, current = {}, set(), None
    for line_number, original in enumerate(source.splitlines(), 1):
        line = original.strip()
        if not line or line.startswith('//'):
            continue
        enum = re.fullmatch(r'enum ([A-Za-z][A-Za-z0-9_]*) \{', line)
        if enum and current is None and enum[1] not in enums:
            current = enum[1]
            enums.add(current)
            continue
        if line == '}' and current is not None:
            current = None
            continue
        declaration = re.fullmatch(r'static (?:var|let) ([A-Za-z][A-Za-z0-9_]*): String = (".*")', line)
        if declaration and current is not None:
            field = current + '.' + declaration[1]
            if field in declarations:
                raise AuditFailure('duplicate generated service declaration')
            if template:
                declarations[field] = ''
            else:
                try:
                    value = json.loads(declaration[2])
                except (ValueError, TypeError):
                    raise AuditFailure('nonliteral generated service value at line ' + str(line_number)) from None
                if not isinstance(value, str):
                    raise AuditFailure('nonstring generated service value')
                declarations[field] = value
            continue
        raise AuditFailure('unsupported generated service syntax at line ' + str(line_number))
    if current is not None or not declarations:
        raise AuditFailure('incomplete generated service declarations')
    return declarations


def validate_values(values, schema):
    if set(values) != set(schema) or not REQUIRED.issubset(schema):
        raise AuditFailure('generated service schema differs from the reviewed template')
    failures = []
    for field, value in values.items():
        # Field identifiers come from the reviewed schema, never raw values.
        if not value:
            if field in REQUIRED:
                failures.append(field + ': missing required setting')
            continue
        if value != value.strip() or any(ord(c) < 32 or ord(c) == 127 for c in value):
            failures.append(field + ': whitespace/control characters')
        elif PLACEHOLDER.fullmatch(value):
            failures.append(field + ': placeholder')
        elif field in REQUIRED and len(value) < 8:
            failures.append(field + ': implausibly short required setting')
    if failures:
        raise AuditFailure('; '.join(failures))
    if not re.fullmatch(r'[0-9a-fA-F]{32}', values['WalletConnect.projectId']):
        raise AuditFailure('WalletConnect.projectId: invalid project identifier shape')
    if not CLIENT_ID.fullmatch(values['GoogleBackup.googleToken']):
        raise AuditFailure('GoogleBackup.googleToken: invalid Google OAuth client shape')
    if not GOOGLE_SCHEME.fullmatch(values['GoogleBackup.googleUrlScheme']):
        raise AuditFailure('GoogleBackup.googleUrlScheme: invalid Google callback shape')


def validate_google_identity(client_id, scheme):
    if not isinstance(client_id, str) or not CLIENT_ID.fullmatch(client_id):
        raise AuditFailure('built Google OAuth client identity is missing or invalid')
    expected = 'com.googleusercontent.apps.' + client_id.removesuffix('.apps.googleusercontent.com')
    if scheme != expected:
        raise AuditFailure('built Google callback is not bound to its OAuth client identity')


def validate_built_plist(data, expected_scheme):
    try:
        info = plistlib.loads(data)
        schemes = [scheme for entry in info.get('CFBundleURLTypes', [])
                   for scheme in entry.get('CFBundleURLSchemes', [])
                   if isinstance(scheme, str) and scheme.startswith('com.googleusercontent.apps.')]
        client_id = info.get('GIDClientID')
    except (ValueError, TypeError, AttributeError, plistlib.InvalidFileException):
        raise AuditFailure('built app has an invalid Google Info.plist structure') from None
    if schemes != [expected_scheme]:
        raise AuditFailure('built app must contain exactly the generated Release Google callback')
    validate_google_identity(client_id, expected_scheme)
    return {'clientIdSha256': sha256(client_id.encode()), 'callbackSha256': sha256(expected_scheme.encode())}


def audit(root, archive=None, expected_receipt=None):
    generated = read_file(root / 'CIKeys.generated.swift', 'generated service configuration')
    template = read_file(root / 'fearless/CIKeys.stencil', 'service template')
    values = parse_declarations(generated)
    validate_values(values, parse_declarations(template, template=True))
    result = {
        'schemaVersion': 1,
        'configuration': 'Release',
        'generatedSourceSha256': sha256(generated),
        'templateSha256': sha256(template),
        'fields': {field: {'present': bool(value), 'required': field in REQUIRED,
                           'sha256': sha256(value.encode()) if value else None}
                   for field, value in sorted(values.items())},
    }
    if expected_receipt is not None:
        try:
            previous = json.loads(read_file(expected_receipt, 'prebuild configuration receipt'))
        except (ValueError, TypeError):
            raise AuditFailure('invalid prebuild configuration receipt') from None
        if previous != result:
            raise AuditFailure('generated service configuration changed during the archive build')
    if archive is not None:
        info = read_file(archive / 'Products/Applications/fearless.app/Info.plist', 'archived Info.plist')
        result['archivedGoogleIdentity'] = validate_built_plist(info, values['GoogleBackup.googleUrlScheme'])
        result['archivedInfoPlistSha256'] = sha256(info)
    return result


def write_receipt(path, result):
    # Exclusive creation avoids silently replacing prior qualification evidence.
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    with os.fdopen(os.open(path, flags, 0o600), 'w') as stream:
        json.dump(result, stream, sort_keys=True, indent=2)
        stream.write('\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--expected-receipt', type=Path)
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    try:
        result = audit(Path(__file__).resolve().parents[2], args.archive, args.expected_receipt)
        if args.receipt:
            write_receipt(args.receipt, result)
        print(PREFIX + ' PASS: Release settings present; source sha256=' + result['generatedSourceSha256'])
        return 0
    except AuditFailure as error:
        print(PREFIX + ' FAIL: ' + str(error), file=sys.stderr)
    except (OSError, UnicodeError, ValueError, TypeError):
        # Never print parser exceptions or their input, which can contain keys.
        print(PREFIX + ' FAIL: configuration or receipt could not be safely read/written', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
