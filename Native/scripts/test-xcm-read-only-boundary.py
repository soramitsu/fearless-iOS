#!/usr/bin/env python3
"""Fail when the XCM package grows a way to sign or send again.

SSFXCM is a discovery and fee quotation library. The wallet sends cross-chain transfers through its
own reviewed, authorized path, so this package must not offer an entry point that takes signing
material or builds a service around a signer that works. The rules, checked on the code with
comments removed:

1. No identifier that carries or creates signing material (``secretKeyData``,
   ``TransactionSignerAssembly``, ``SigningWrapperData``, ``createExtrincisServices``).
2. ``XcmAssembly`` exposes exactly one public static function, ``createReadOnlyServices``.
3. Nothing public mentions ``TransactionSignerProtocol``.
4. Every ``XcmExtrinsicService(`` is built with ``signingWrapper: XcmReadOnlySigner()``.
5. ``XcmReadOnlySigner`` refuses to sign.
6. ``XcmExtrinsicServices``, the bundle that holds the send-capable service, is not public.

Usage: test-xcm-read-only-boundary.py [--root REPO] [--self-test]
"""
import argparse
import re
import sys
from pathlib import Path

FORBIDDEN = ['secretKeyData', 'secretKey', 'TransactionSignerAssembly', 'SigningWrapperData',
             'signingWrapperData', 'createExtrincisServices']


def strip_comments(source):
    """Remove // and /* */ comments, keeping string literals and line numbers."""
    out = []
    i = 0
    n = len(source)
    while i < n:
        two = source[i:i + 2]
        if two == '//':
            while i < n and source[i] != '\n':
                i += 1
        elif two == '/*':
            depth = 1
            i += 2
            while i < n and depth:
                if source[i:i + 2] == '/*':
                    depth += 1
                    i += 2
                elif source[i:i + 2] == '*/':
                    depth -= 1
                    i += 2
                else:
                    if source[i] == '\n':
                        out.append('\n')
                    i += 1
        elif source[i] == '"':
            j = i + 1
            while j < n and source[j] != '"':
                j += 2 if source[j] == '\\' else 1
            out.append(source[i:j + 1])
            i = j + 1
        else:
            out.append(source[i])
            i += 1
    return ''.join(out)


def balanced_call(code, open_index):
    """Text of the parenthesised argument list that starts at code[open_index] == '('."""
    depth = 0
    for j in range(open_index, len(code)):
        if code[j] == '(':
            depth += 1
        elif code[j] == ')':
            depth -= 1
            if depth == 0:
                return code[open_index:j + 1]
    return code[open_index:]


def check(files):
    """files: {relative path: source}. Returns a list of violation strings."""
    problems = []
    seen = set()
    code = {path: strip_comments(source) for path, source in files.items()}

    for path, text in code.items():
        for word in FORBIDDEN:
            for match in re.finditer(r'\b%s\b' % re.escape(word), text):
                line = text.count('\n', 0, match.start()) + 1
                if (path, line, word) not in seen:
                    seen.add((path, line, word))
                    problems.append('%s:%d: `%s` carries or creates signing material'
                                    % (path, line, word))

        for match in re.finditer(r'^[^\n]*\bpublic\b[^\n]*\bTransactionSigner\w*', text, re.M):
            line = text.count('\n', 0, match.start()) + 1
            problems.append('%s:%d: a public declaration takes a signer' % (path, line))

        for match in re.finditer(r'\b(?:public|open)\b[^\n]*\bstruct\s+XcmExtrinsicServices\b', text):
            line = text.count('\n', 0, match.start()) + 1
            problems.append('%s:%d: XcmExtrinsicServices must not be public' % (path, line))

        for match in re.finditer(r'\bXcmExtrinsicService\s*\(', text):
            if re.search(r'\bfinal class\s+$|\bclass\s+$', text[max(0, match.start() - 20):match.start()]):
                continue
            arguments = balanced_call(text, match.end() - 1)
            if not re.search(r'signingWrapper\s*:\s*XcmReadOnlySigner\(\)', arguments):
                line = text.count('\n', 0, match.start()) + 1
                problems.append('%s:%d: XcmExtrinsicService must be built with XcmReadOnlySigner()'
                                % (path, line))

    assembly = [p for p in code if p.endswith('XcmAssembly.swift')]
    if not assembly:
        problems.append('XcmAssembly.swift not found')
    for path in assembly:
        # The functions inside `public enum XcmAssembly { ... }`.
        start = code[path].find('enum XcmAssembly')
        body = code[path][start:] if start >= 0 else ''
        publics = re.findall(r'\bpublic\s+(?:static\s+)?func\s+(\w+)', body)
        if publics != ['createReadOnlyServices']:
            problems.append('%s: XcmAssembly must expose only createReadOnlyServices, found %s'
                            % (path, publics or 'nothing'))

    signer = [p for p in code if re.search(r'final class XcmReadOnlySigner', code[p])]
    if not signer:
        problems.append('XcmReadOnlySigner not found')
    for path in signer:
        match = re.search(r'final class XcmReadOnlySigner[^{]*\{', code[path])
        body = balanced_call(code[path].replace('{', '(').replace('}', ')'), match.end() - 1)
        if 'throw' not in body or re.search(r'\breturn\b', body):
            problems.append('%s: XcmReadOnlySigner must throw and never return a signature' % path)
    return problems


GOOD = {
    'XcmAssembly.swift': '''
public enum XcmAssembly {
    public static func createReadOnlyServices() -> Int {
        let e = XcmExtrinsicService(
            signingWrapper: XcmReadOnlySigner(),
            extrinsicBuilder: b)
        return 1
    }
    private static func makeServices() {}
}
struct XcmExtrinsicServices {}
''',
    'XcmReadOnlyServices.swift': '''
final class XcmReadOnlySigner: TransactionSignerProtocol {
    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        throw XcmReadOnlyError.signingUnavailable
    }
}
''',
}


def self_test():
    assert check(GOOD) == [], check(GOOD)

    def broken(path, old, new):
        files = dict(GOOD)
        assert old in files[path], old
        files[path] = files[path].replace(old, new)
        return check(files)

    cases = {
        'a second public entry point': broken(
            'XcmAssembly.swift', 'private static func makeServices() {}',
            'public static func createExtrincisServices(secretKeyData: Data) {}'),
        'a public signer parameter': broken(
            'XcmAssembly.swift', 'private static func makeServices() {}',
            'public static func other(signer: TransactionSignerProtocol) {}'),
        'a working signer': broken(
            'XcmAssembly.swift', 'signingWrapper: XcmReadOnlySigner()',
            'signingWrapper: TransactionSignerAssembly.signer()'),
        'a signer that signs': broken(
            'XcmReadOnlyServices.swift', 'throw XcmReadOnlyError.signingUnavailable',
            'return signature'),
        'a public services bundle': broken(
            'XcmAssembly.swift', 'struct XcmExtrinsicServices {}',
            'public struct XcmExtrinsicServices {}'),
        'a raw key holder': broken(
            'XcmAssembly.swift', 'struct XcmExtrinsicServices {}',
            'struct SigningWrapperData { let secretKeyData: Data }'),
    }
    for name, found in cases.items():
        assert found, 'rule did not fire for %s' % name

    commented = dict(GOOD)
    commented['XcmAssembly.swift'] += '\n// secretKeyData is gone\n/* TransactionSignerAssembly */\n'
    assert check(commented) == [], 'comments must not count'
    print('self-test: PASS (%d violation kinds detected, comments ignored)' % len(cases))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    self_test()
    if args.self_test:
        return

    sources = args.root / 'Sources' / 'SSFXCM'
    files = {str(p.relative_to(args.root)): p.read_text() for p in sorted(sources.rglob('*.swift'))}
    if not files:
        sys.exit('no Swift sources under %s' % sources)
    problems = check(files)
    for problem in problems:
        print('FAIL: ' + problem)
    if problems:
        sys.exit(1)
    print('PASS: %d SSFXCM sources, no way to sign or send' % len(files))


if __name__ == '__main__':
    main()
