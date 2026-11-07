#!/usr/bin/env python3
"""Render the app's ignored service configuration without logging credentials."""

import os
from pathlib import Path
import re
import sys
import tempfile
import urllib.parse


# These are the existing CI environment names used by CIKeys.stencil. Keep the
# mapping explicit: a new template argument must be reviewed instead of silently
# becoming an empty setting in a signed build.
ARGUMENT_ENVIRONMENT = {
    "moonPaySecretKey": "MOONPAY_PRODUCTION_SECRET",
    "moonPayTestSecretKey": "MOONPAY_TEST_SECRET",
    "moonPayPublicKey": "MOONPAY_PUBLIC_KEY",
    "subscanAPIKey": "SUBSCAN_API_KEY",
    "ethereumApiKey": "FL_BLAST_API_ETHEREUM_KEY",
    "bscApiKey": "FL_BLAST_API_BSC_KEY",
    "sepoliaApiKey": "FL_BLAST_API_SEPOLIA_KEY",
    "goerliApiKey": "FL_BLAST_API_GOERLI_KEY",
    "polygonApiKey": "FL_BLAST_API_POLYGON_KEY",
    "walletConnectProjectId": "FL_WALLET_CONNECT_PROJECT_ID",
    "webClientIdRelease": "WEB_CLIENT_ID_RELEASE",
    "fearlessGoogleUrlSchemeRelease": "FEARLESS_GOOGLE_URL_SCHEME_RELEASE",
    "webClientIdDebug": "WEB_CLIENT_ID_DEBUG",
    "fearlessGoogleUrlSchemeDebug": "FEARLESS_GOOGLE_URL_SCHEME_DEBUG",
    "etherscanApiKey": "FL_IOS_ETHERSCAN_API_KEY",
    "kaiaScanApiKey": "FL_IOS_KAIASCAN_API_KEY",
    "bscscanApiKey": "FL_IOS_BSCSCAN_API_KEY",
    "polygonscanApiKey": "FL_IOS_POLYGONSCAN_API_KEY",
    "alchemyApiKey": "FL_IOS_ALCHEMY_API_ETHEREUM_KEY",
    "oklinkApiKey": "FL_OKLINK_API_KEY",
    "opMainnetApiKey": "FL_IOS_OPTIMISTIC_ETHERSCAN_API_KEY",
    "dwellirApiKey": "FL_DWELLIR_API_KEY",
    "coinbaseAppId": "COINBASE_APP_ID",
    "tonApiKey": "FL_TON_API_KEY",
    "tonApiKeyDebug": "FL_TON_API_KEY_DEBUG",
    # Optional: a Solana mainnet JSON-RPC provider asked before the public nodes.
    "solanaRpcProviderURL": "FL_SOLANA_RPC_URL",
}
PLACEHOLDER = re.compile(r'"\{\{\s*argument\.(\w+)\s*\}\}"')
ENVIRONMENT_ALIASES = {"FL_TON_API_KEY": ("FL_IOS_TON_API_KEY",)}


class UnusableSolanaProviderURL(ValueError):
    """FL_SOLANA_RPC_URL is set to something the app would ignore."""


SOLANA_PROVIDER_GUIDANCE = (
    "FL_SOLANA_RPC_URL must be an https URL with a host, its key in the path, and no query "
    "string or credentials; leave it unset to use the public Solana nodes"
)


def validate_solana_provider_url(value):
    """Mirror SolanaRpcEndpoints.providerURL: an unusable value would silently fall back to
    the public nodes at runtime, so refuse to generate such a build. Never echo the value."""
    text = value.strip()
    if not text:
        return
    if not text.isascii() or any(c.isspace() or c in "\"'<>\\{}|^`" or ord(c) < 32 or ord(c) == 127 for c in text):
        raise UnusableSolanaProviderURL()
    parts = urllib.parse.urlsplit(text)
    try:
        parts.port
    except ValueError:
        raise UnusableSolanaProviderURL() from None
    if (
        parts.scheme.lower() != "https"
        or not parts.hostname
        or "?" in text
        or parts.username is not None
        or parts.password is not None
    ):
        raise UnusableSolanaProviderURL()


def environment_value(name, environment):
    """Accept the deployed Jenkins name without silently choosing conflicting keys."""
    values = {environment[key] for key in (name, *ENVIRONMENT_ALIASES.get(name, ())) if environment.get(key)}
    if len(values) > 1:
        raise ValueError("conflicting service environment aliases")
    return next(iter(values), "")


def swift_literal(value):
    """Encode a Swift string without allowing interpolation or source injection."""
    escapes = {"\\": "\\\\", '"': '\\"', "\n": "\\n", "\r": "\\r", "\t": "\\t"}
    return '"' + "".join(
        escapes.get(char, "\\u{%x}" % ord(char) if ord(char) < 32 or ord(char) == 127 else char)
        for char in value
    ) + '"'


def render(template, environment):
    arguments = set(PLACEHOLDER.findall(template))
    if arguments != set(ARGUMENT_ENVIRONMENT):
        raise ValueError("service template arguments differ from the reviewed environment mapping")
    validate_solana_provider_url(environment_value("FL_SOLANA_RPC_URL", environment))
    # Inspect the template before replacing values, which may themselves contain
    # braces or comma/equal characters that are valid credentials.
    skeleton = PLACEHOLDER.sub('""', template)
    if "{{" in skeleton or "{%" in skeleton or "}}" in skeleton or "%}" in skeleton:
        raise ValueError("service template contains unsupported syntax")
    rendered = PLACEHOLDER.sub(
        lambda match: swift_literal(environment_value(ARGUMENT_ENVIRONMENT[match.group(1)], environment)),
        template,
    )
    return "// Generated from CIKeys.stencil. Do not edit or commit this file.\n\n" + rendered


def generate(root, environment):
    template = (root / "fearless" / "CIKeys.stencil").read_text(encoding="utf-8")
    result = render(template, environment)
    output = root / "CIKeys.generated.swift"
    if output.is_symlink():
        raise ValueError("generated service configuration must not be a symlink")
    if output.is_file() and output.read_bytes() == result.encode("utf-8"):
        # Preserve the input timestamp so a retry does not recompile the entire
        # optimized app when its private configuration is already identical.
        if output.stat().st_mode & 0o777 != 0o600:
            output.chmod(0o600)
        return
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=root, prefix=".CIKeys.", delete=False) as stream:
            temporary = Path(stream.name)
            os.fchmod(stream.fileno(), 0o600)
            stream.write(result)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, output)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    root = Path(os.environ.get("PROJECT_DIR", Path(__file__).resolve().parents[2]))
    try:
        generate(root, os.environ)
    except UnusableSolanaProviderURL:
        print("[ios-service-configuration] ERROR: " + SOLANA_PROVIDER_GUIDANCE, file=sys.stderr)
        return 1
    except (OSError, UnicodeError, ValueError):
        # Never include exception text: a template or environment value could
        # otherwise leak through diagnostics during a failed release build.
        print("[ios-service-configuration] ERROR: unable to safely generate service configuration", file=sys.stderr)
        return 1
    print("[ios-service-configuration] Generated private service configuration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
