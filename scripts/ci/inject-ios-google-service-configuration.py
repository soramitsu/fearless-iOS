#!/usr/bin/env python3
"""Inject Google identity into the built product only; never edit app sources."""
import importlib.util
import os
from pathlib import Path
import plistlib
import stat
import sys
import tempfile

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('service_audit', Path(__file__).with_name('audit-ios-release-service-configuration.py'))
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def inject(environment):
    client = (environment.get('GOOGLE_CLIENT_ID') or environment.get('FEARLESS_GOOGLE_TOKEN')
              or environment.get('google_client_id') or '')
    scheme = (environment.get('GOOGLE_URL_SCHEME') or environment.get('FEARLESS_GOOGLE_URL_SCHEME')
              or environment.get('google_url_scheme') or '')
    is_release_archive = environment.get('CONFIGURATION') == 'Release' and environment.get('ACTION') == 'install'
    if not client and not scheme and not is_release_archive:
        return False
    audit.validate_google_identity(client, scheme)
    # Archives install the app under TARGET_BUILD_DIR. BUILT_PRODUCTS_DIR can
    # contain only an app symlink pointing outside that directory.
    built = Path(environment.get('TARGET_BUILD_DIR') or environment['BUILT_PRODUCTS_DIR']).resolve(strict=True)
    relative = Path(environment['INFOPLIST_PATH'])
    if relative.is_absolute() or '..' in relative.parts:
        raise audit.AuditFailure('built Info.plist path must be inside the built products directory')
    path = built / relative
    if not path.resolve(strict=True).is_relative_to(built):
        raise audit.AuditFailure('built Info.plist resolves outside the built products directory')
    data = audit.read_file(path, 'built Info.plist')
    info = plistlib.loads(data)
    entries = info.get('CFBundleURLTypes', [])
    for entry in entries:
        entry['CFBundleURLSchemes'] = [item for item in entry.get('CFBundleURLSchemes', [])
                                      if not item.startswith('com.googleusercontent.apps.')]
    entries = [entry for entry in entries if entry.get('CFBundleURLSchemes')]
    entries.append({'CFBundleTypeRole': 'Editor', 'CFBundleURLName': 'Google Sign-In', 'CFBundleURLSchemes': [scheme]})
    info['CFBundleURLTypes'] = entries
    info['GIDClientID'] = client
    updated = plistlib.dumps(info, fmt=plistlib.FMT_BINARY if data.startswith(b'bplist') else plistlib.FMT_XML)
    audit.validate_built_plist(updated, scheme)
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
            temp_path = Path(stream.name)
            os.chmod(temp_path, stat.S_IMODE(path.stat().st_mode))
            stream.write(updated)
        os.replace(temp_path, path)
        temp_path = None
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)
    return True


def main():
    try:
        changed = inject(os.environ)
        print('[ios-google-configuration] ' + ('Injected validated Google identity into the built app' if changed else 'No Google settings supplied for this non-Release build'))
        return 0
    except (audit.AuditFailure, OSError, ValueError, TypeError, KeyError, AttributeError, plistlib.InvalidFileException):
        print('[ios-google-configuration] FAIL: missing or invalid Google configuration/built plist; no setting values logged', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
