### Fearless Wallet iOS
[![Apple Store](https://img.shields.io/badge/Apple%20Store-iOS-Silver?logo=apple)](https://apps.apple.com/us/app/fearless-wallet/id1537251089)

![logo](/docs/fearlesswallet_promo.png)

## About
Fearless Wallet is a mobile wallet designed for the decentralized future on the Kusama and Polkadot network, with support on iOS and Android platforms. The best user experience, fast performance, and secure storage for your accounts. Development of Fearless Wallet is supported by Kusama Treasury grant.

[![](https://img.shields.io/twitter/follow/FearlessWallet?label=Follow&style=social)](https://twitter.com/FearlessWallet)

## Roadmap
Fearless Wallet roadmap is available for everyone: [roadmap link](https://soramitsucoltd.aha.io/shared/97bc3006ee3c1baa0598863615cf8d14)

For repository-specific details, see `ROADMAP.md`.

## Agents Guide
Guidelines for automation and agent contributions: see `AGENTS.md`.

SPM/SSF stability notes and scripts: see `docs/SSFStability.md`.

## Dev Status
Track features development: [board link](https://soramitsucoltd.aha.io/shared/343e5db57d53398e3f26d0048158c4a2)

## Testing
- Run tests locally for both configurations:
  - `bash scripts/test-matrix.sh` (uses iPhone 15 simulator by default)

## Configuration
Partner and release identifiers are supplied by environment variables or CI key
generation, not committed source. For public local builds, unset values resolve
to empty strings and the affected buy-provider flows are unavailable.

Moonpay:
- `MOONPAY_PRODUCTION_SECRET`
- `MOONPAY_TEST_SECRET`
- `MOONPAY_PUBLIC_KEY`

## License

Fearless Wallet iOS is available under the Apache 2.0 license. See the LICENSE file for more info.
