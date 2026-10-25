#!/usr/bin/env python3
"""No-dependency, exact-site source ratchet for design-system section 14.0."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

BASELINE_PATH = 'design/fw.raw-colour-baseline.ios.json'
SOURCE_ROOT = 'fearless/'
THEME_ROOT = 'fearless/Common/DesignSystem/'
EXPRESSION = re.compile(r'\bUIColor\s*\(\s*(?:red|hex)\s*:')


def eligible(path):
    parts = PurePosixPath(path).parts
    return (path.startswith(SOURCE_ROOT) and not path.startswith(THEME_ROOT)
            and path.lower().endswith('.swift') and '..' not in parts
            and PurePosixPath(path).as_posix() == path
            and not any(character in path for character in '\\*?[]\0\n\r'))


def closing_parenthesis(source, opening):
    # Keep complete argument expressions, including nested calls and quoted ')',
    # so a later channel change cannot reuse an exception for the opening line.
    # This is deliberately grep-like, not a Swift parser: comments are scanned.
    depth = 0
    quote = False
    escaped = False
    for index in range(opening, len(source)):
        character = source[index]
        if quote:
            if escaped:
                escaped = False
            elif character == '\\':
                escaped = True
            elif character == '"':
                quote = False
        elif character == '"':
            quote = True
        elif character == '(':
            depth += 1
        elif character == ')':
            depth -= 1
            if depth == 0:
                return index + 1
    raise ValueError('Unclosed raw UIColor expression; cannot audit its full arguments')


def mask_comments(source):
    """Preserve offsets while allowing Swift comments between constructor tokens."""
    result = list(source)
    index, block_depth, quote, escaped = 0, 0, False, False
    while index < len(source):
        pair = source[index:index + 2]
        if block_depth:
            if pair == '/*':
                block_depth += 1
            elif pair == '*/':
                block_depth -= 1
            else:
                if source[index] != '\n':
                    result[index] = ' '
                index += 1
                continue
            result[index:index + 2] = [' ', ' ']
            index += 2
            continue
        if quote:
            if escaped:
                escaped = False
            elif source[index] == '\\':
                escaped = True
            elif source[index] == '"':
                quote = False
        elif source[index] == '"':
            quote = True
        elif pair == '/*':
            block_depth = 1
            result[index:index + 2] = [' ', ' ']
            index += 2
            continue
        elif pair == '//':
            end = source.find('\n', index)
            end = len(source) if end < 0 else end
            result[index:end] = [' '] * (end - index)
            index = end
            continue
        index += 1
    if block_depth:
        raise ValueError('Unclosed block comment; cannot audit Swift colour source')
    return ''.join(result)


def raw_colour_sites(path, source):
    if not eligible(path):
        return []
    sites = Counter()
    masked = mask_comments(source)
    # Also retain direct matches inside comments, as the documented grep rule
    # does. Masked matches supersede them for balancing actual call arguments.
    matches = {match.start(): source for match in EXPRESSION.finditer(source)}
    matches.update({match.start(): masked for match in EXPRESSION.finditer(masked)})
    for offset, balanced_source in matches.items():
        end = closing_parenthesis(balanced_source, balanced_source.index('(', offset))
        start = source.rfind('\n', 0, offset) + 1
        newline = source.find('\n', end)
        text = source[start:len(source) if newline < 0 else newline].strip()
        sites[(path, text)] += 1
    return [{'path': path, 'source': source, 'count': count}
            for (path, source), count in sorted(sites.items())]


def scan_raw_colours(root):
    source_root = root / SOURCE_ROOT
    if not source_root.is_dir() or source_root.is_symlink():
        raise ValueError('Missing or linked production source root')
    sites = []
    for directory, directories, files in os.walk(source_root, followlinks=False):
        for name in directories + files:
            path = Path(directory) / name
            if path.is_symlink():
                raise ValueError('Source symlink cannot bypass colour audit: ' + str(path))
        for name in files:
            path = Path(directory) / name
            relative = path.relative_to(root).as_posix()
            if eligible(relative):
                sites.extend(raw_colour_sites(relative, path.read_text()))
    return sorted(sites, key=lambda item: (item['path'], item['source']))


def parse_baseline(value):
    if (not isinstance(value, dict) or type(value.get('schemaVersion')) is not int
            or value['schemaVersion'] != 1
            or not isinstance(value.get('sourceCommit'), str)
            or not re.fullmatch(r'[0-9a-f]{40}', value['sourceCommit'])
            or not isinstance(value.get('sites'), list)):
        raise ValueError('Malformed raw-colour baseline')
    seen = set()
    for site in value['sites']:
        if (not isinstance(site, dict) or not isinstance(site.get('path'), str)
                or not eligible(site['path']) or not isinstance(site.get('source'), str)
                or not site['source'] or site['source'].strip() != site['source']
                or type(site.get('count')) is not int or site['count'] < 1):
            raise ValueError('Malformed raw-colour baseline site')
        key = (site['path'], site['source'])
        if key in seen:
            raise ValueError('Duplicate raw-colour baseline site')
        detected = raw_colour_sites(site['path'], site['source'])
        if not detected or any(row['source'] != site['source'] for row in detected):
            raise ValueError('Baseline site is not one exact raw-colour source context')
        seen.add(key)
    return value


def compare_sites(current, allowed):
    def counts(sites):
        return {(site['path'], site['source']): site['count'] for site in sites}
    actual, baseline = counts(current), counts(allowed)
    return {'added': [site for site in current if site['count'] > baseline.get((site['path'], site['source']), 0)],
            'stale': [site for site in allowed if site['count'] > actual.get((site['path'], site['source']), 0)]}


def assert_baseline_shrinks(current, previous):
    parse_baseline(current)
    parse_baseline(previous)
    if (current['sourceCommit'] != previous['sourceCommit']
            or compare_sites(current['sites'], previous['sites'])['added']):
        raise ValueError('Raw-colour baseline may only shrink; use a semantic theme role')


def git(root, *arguments):
    return subprocess.check_output(['git', *arguments], cwd=root, text=True, stderr=subprocess.PIPE)


def resolved_commit(root, reference):
    if not reference or reference.startswith('-'):
        raise ValueError('A nonempty Git base reference is required')
    return git(root, 'rev-parse', '--verify', reference + '^{commit}').strip()


def historical_sites(root, commit):
    rows = []
    for path in git(root, 'ls-tree', '-r', '--name-only', commit, '--', SOURCE_ROOT).splitlines():
        if eligible(path):
            rows.extend(raw_colour_sites(path, git(root, 'show', commit + ':' + path)))
    return sorted(rows, key=lambda row: (row['path'], row['source']))


def audit_raw_colours(root, base_ref='HEAD'):
    baseline_path = root / BASELINE_PATH
    if baseline_path.is_symlink():
        raise ValueError('Baseline must be a regular file, not a symlink')
    baseline = parse_baseline(json.loads(baseline_path.read_text()))
    current = scan_raw_colours(root)
    differences = compare_sites(current, baseline['sites'])
    if differences['added'] or differences['stale']:
        raise ValueError('Raw-colour drift: use theme roles and remove obsolete exceptions.\n'
                         + json.dumps(differences, indent=2))
    commit = resolved_commit(root, base_ref)
    previous_file = git(root, 'ls-tree', '--name-only', commit, '--', BASELINE_PATH).strip()
    if previous_file:
        previous = json.loads(git(root, 'show', commit + ':' + BASELINE_PATH))
        assert_baseline_shrinks(baseline, previous)
        comparison = 'only shrinks from ' + commit
    else:
        # Initial adoption is explicit: every exception must already exist in the
        # pinned historical source, which must be an ancestor of this checkout.
        anchor = resolved_commit(root, baseline['sourceCommit'])
        git(root, 'merge-base', '--is-ancestor', anchor, 'HEAD')
        try:
            git(root, 'merge-base', '--is-ancestor', anchor, commit)
        except subprocess.CalledProcessError as error:
            raise ValueError('Initial source anchor must precede the actual comparison base') from error
        if compare_sites(baseline['sites'], historical_sites(root, anchor))['added']:
            raise ValueError('Initial exceptions exceed the pinned historical source inventory')
        comparison = 'initial adoption from exact historical inventory ' + anchor
    return {'files': len({site['path'] for site in current}), 'sites': len(current),
            'occurrences': sum(site['count'] for site in current), 'baseCommit': commit,
            'baselineComparison': comparison}


def ci_base_reference(environment):
    explicit = environment.get('FW_COLOUR_BASE_REF', '')
    if explicit and explicit != '0' * 40:
        return explicit
    if environment.get('CHANGE_TARGET'):
        return 'refs/remotes/origin/' + environment['CHANGE_TARGET']
    previous = environment.get('GIT_PREVIOUS_SUCCESSFUL_COMMIT', '')
    if previous and previous != '0' * 40:
        return previous
    raise ValueError('CI requires FW_COLOUR_BASE_REF, a fetched CHANGE_TARGET, '
                     'or GIT_PREVIOUS_SUCCESSFUL_COMMIT; no source-only fallback')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--base-ref')
    parser.add_argument('--ci', action='store_true', help='Require an explicit CI comparison base')
    arguments = parser.parse_args()
    try:
        base = arguments.base_ref
        if base is None:
            base = ci_base_reference(os.environ) if arguments.ci else os.environ.get('FW_COLOUR_BASE_REF', 'HEAD')
        print(json.dumps(audit_raw_colours(arguments.root.resolve(), base), indent=2))
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
