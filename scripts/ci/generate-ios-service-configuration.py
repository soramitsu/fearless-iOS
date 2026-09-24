#!/usr/bin/env python3
"""Render the app's ignored service configuration without logging credentials."""

import os
from pathlib import Path
import re
import sys
import tempfile


# These are the existing CI environment names used by CIKeys.stencil. Keep the
# mapping explicit: a new template argument must be reviewed instead of silently
# becoming an empty setting in a signed build.
ARGUMENT_ENVIRONMENT = {
    "moonPaySecretKey": "MOONPAY_PRODUCTION_SECRET",
    "moonPayTestSecretKey": "MOONPAY_TEST_SECRET",
    "moonPayPublicKey": "MOONPAY_PUBLIC_KEY",
    "subscanAPIKey": "SUBSCAN_API_KEY",
    "soraCardAPIKey": "SORA_CARD_API_KEY",
    "soraCardDomain": "SORA_CARD_DOMAIN",
    "soraCardKycEndpoint": "SORA_CARD_KYC_ENDPOINT_URL",
    "soraCardKycUsername": "SORA_CARD_KYC_USERNAME",
    "soraCardKycPassword": "SORA_CARD_KYC_PASSWORD",
    "paywingsRepositoryUrl": "PAY_WINGS_REPOSITORY_URL",
    "paywingsUsername": "PAY_WINGS_USERNAME",
    "paywingsPassword": "PAY_WINGS_PASSWORD",
    "x1EndpointUrlRelease": "X1_ENDPOINT_URL_RELEASE",
    "x1WidgetIdRelease": "X1_WIDGET_ID_RELEASE",
    "x1EndpointUrlDebug": "X1_ENDPOINT_URL_DEBUG",
    "x1WidgetIdDebug": "X1_WIDGET_ID_DEBUG",
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
}
PLACEHOLDER = re.compile(r'"\{\{\s*argument\.(\w+)\s*\}\}"')
ENVIRONMENT_ALIASES = {"FL_TON_API_KEY": ("FL_IOS_TON_API_KEY",)}


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
    except (OSError, UnicodeError, ValueError):
        # Never include exception text: a template or environment value could
        # otherwise leak through diagnostics during a failed release build.
        print("[ios-service-configuration] ERROR: unable to safely generate service configuration", file=sys.stderr)
        return 1
    print("[ios-service-configuration] Generated private service configuration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
