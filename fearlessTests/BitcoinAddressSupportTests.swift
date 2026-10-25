import XCTest
@testable import fearless

/// IOSUX-3 B4: which Bitcoin addresses the wallet pays, and the exact output script for each.
/// Supported recipients: legacy `1…` (P2PKH), script `3…` (P2SH), native SegWit `bc1q…`
/// (P2WPKH and P2WSH) and Taproot `bc1p…` (P2TR). Vectors are from BIP173, BIP350 and the
/// well-known Bitcoin wiki base58 examples; every one was checked against the BIP350
/// reference decoder before it was written down here.
final class BitcoinAddressSupportTests: XCTestCase {
    func testBip173AndBip350ValidAddressesPayTheExactScript() {
        let vectors: [(String, BitcoinKeyDerivation.Network, BitcoinAddressSupport.Kind, String)] = [
            ("BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4", .mainnet, .p2wpkh, "0014751e76e8199196d454941c45d1b3a323f1433bd6"),
            (
                "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7",
                .testnet,
                .p2wsh,
                "00201863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262"
            ),
            (
                "tb1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesrxh6hy",
                .testnet,
                .p2wsh,
                "0020000000c4a5cad46221b2a187905e5266362b99d5e91c6ce24d165dab93e86433"
            ),
            (
                "tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c",
                .testnet,
                .p2tr,
                "5120000000c4a5cad46221b2a187905e5266362b99d5e91c6ce24d165dab93e86433"
            ),
            (
                "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0",
                .mainnet,
                .p2tr,
                "512079be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
            ),
            ("1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2", .mainnet, .p2pkh, "76a91477bff20c60e522dfaa3350c39b030a5d004e839a88ac"),
            ("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy", .mainnet, .p2sh, "a914b472a266d0bd89c13706a4132ccfb16f7c3b9fcb87"),
            ("mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn", .testnet, .p2pkh, "76a914243f1394f44554f4ce3fd68649c19adc483ce92488ac"),
            ("2MzQwSSnBHWHqSAqtTVQ6v47XtaisrJa1Vc", .testnet, .p2sh, "a9144e9f39ca4688ff102128ea4ccda34105324305b087")
        ]

        for (address, network, kind, script) in vectors {
            guard case let .supported(recipient) = BitcoinAddressSupport.classify(address, network: network) else {
                XCTFail("\(address) should be payable")
                continue
            }
            XCTAssertEqual(recipient.kind, kind, address)
            XCTAssertEqual(recipient.scriptPubKey.toHex(), script, address)
        }
    }

    func testBech32IsStoredLowercaseAndBase58Unchanged() {
        XCTAssertEqual(
            BitcoinAddressSupport.recipient("BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4", network: .mainnet)?.address,
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
        )
        XCTAssertEqual(
            BitcoinAddressSupport.recipient(" 3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy\n", network: .mainnet)?.address,
            "3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy"
        )
    }

    /// Valid addresses for witness programs Bitcoin has not defined yet: paying them could lock
    /// the coins forever, so the wallet refuses them as a distinct case.
    func testUndefinedWitnessProgramsAreUnsupportedNotPayable() {
        let undefined = [
            "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kt5nd6y", // v1, 40 bytes
            "BC1SW50QGDZ25J", // v16
            "bc1zw508d6qejxtdg4y5r3zarvaryvaxxpcs" // v2
        ]

        for address in undefined {
            XCTAssertEqual(BitcoinAddressSupport.classify(address, network: .mainnet), .unsupported, address)
            XCTAssertNil(BitcoinAddressSupport.recipient(address, network: .mainnet), address)
        }
    }

    func testBip350InvalidAddressesAreRejected() {
        let invalid = [
            "tc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq5zuyut", // unknown prefix
            "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqh2y7hd", // bech32 checksum on v1
            "tb1z0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqglt7rf", // bech32 checksum on v2
            "BC1S0XLXVLHEMJA6C4DQV22UAPCTQUPFHLXM9H8Z3K2E72Q4K9HCZ7VQ54WELL", // bech32 checksum on v16
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kemeawh", // bech32m checksum on v0
            "tb1q0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq24jc47", // bech32m checksum on v0
            "bc1p38j9r5y49hruaue7wxjce0updqjuyyx0kh56v8s25huc6995vvpql3jow4", // invalid character
            "BC130XLXVLHEMJA6C4DQV22UAPCTQUPFHLXM9H8Z3K2E72Q4K9HCZ7VQ7ZWS8R", // witness version 17
            "bc1pw5dgrnzv", // program of one byte
            "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7v8n0nx0muaewav253zgeav", // 41 bytes
            "BC1QR508D6QEJXTDG4Y5R3ZARVARYV98GJ9P", // 16-byte v0 program
            "tb1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vq47Zagq", // mixed case
            "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7v07qwwzcrf", // more than 4 padding bits
            "tb1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vpggkg4j", // non-zero padding
            "bc1gmk9yu", // empty data
            "1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN3", // base58 checksum
            "0x8ba1f109551bD432803012645Ac136ddd64DBA72", // Ethereum
            "15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S2zD7bJvaHw2zz", // Polkadot SS58
            ""
        ]

        for address in invalid {
            XCTAssertEqual(BitcoinAddressSupport.classify(address, network: .mainnet), .invalid, address)
            XCTAssertEqual(BitcoinAddressSupport.classify(address, network: .testnet), .invalid, address)
        }
    }

    func testAddressesOfTheOtherBitcoinNetworkAreWrongNetwork() {
        let pairs: [(String, BitcoinKeyDerivation.Network)] = [
            ("bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m", .testnet),
            ("bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0", .testnet),
            ("1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2", .testnet),
            ("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy", .testnet),
            ("tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7", .mainnet),
            ("mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn", .mainnet),
            ("2MzQwSSnBHWHqSAqtTVQ6v47XtaisrJa1Vc", .mainnet)
        ]

        for (address, network) in pairs {
            XCTAssertEqual(BitcoinAddressSupport.classify(address, network: network), .wrongNetwork, address)
        }
    }

    /// Each output type carries its own size and dust limit, so the fee and the minimum amount
    /// are right for the address actually paid.
    func testOutputSizesAndDustLimitsFollowTheScript() {
        let expectations: [(BitcoinAddressSupport.Kind, Int, Int64)] = [
            (.p2pkh, 34, 546),
            (.p2sh, 32, 540),
            (.p2wpkh, 31, 330),
            (.p2wsh, 43, 330),
            (.p2tr, 43, 330)
        ]

        for (kind, vbytes, dust) in expectations {
            XCTAssertEqual(kind.outputVbytes, vbytes, "\(kind)")
            XCTAssertEqual(kind.dustSats, dust, "\(kind)")
        }
    }

    func testSendRecipientValidationAcceptsEveryPayableTypeOnItsNetworkOnly() {
        let wallet = AccountGenerator.generateMetaAccount()
        let mainnet = BitcoinTestWallet.chain

        for address in [
            "1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2",
            "3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy",
            "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m",
            "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0"
        ] {
            XCTAssertEqual(
                AddressChainDefiner.validateUniversalAddress(address, for: mainnet, wallet: wallet),
                .valid(address),
                address
            )
        }
        XCTAssertEqual(
            AddressChainDefiner.validateUniversalAddress(
                "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7",
                for: mainnet,
                wallet: wallet
            ),
            .invalid("tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7")
        )
    }

    /// The builder writes the classified script into the signed transaction, so a payment to
    /// each type lands on exactly the script the address encodes.
    func testSignedTransactionPaysTheScriptOfEveryAddressType() throws {
        let recipients = [
            "1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2",
            "3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy",
            "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m",
            "bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3",
            "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0"
        ].compactMap { BitcoinAddressSupport.recipient($0, network: .mainnet) }
        XCTAssertEqual(recipients.map(\.kind), [.p2pkh, .p2sh, .p2wpkh, .p2wsh, .p2tr])

        for recipient in recipients {
            let transaction = try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: BitcoinTestWallet.mnemonic,
                inputs: [
                    BitcoinSpendableUtxo(
                        address: BitcoinTestWallet.address,
                        txid: String(repeating: "11", count: 32),
                        valueSats: 100_000,
                        vout: 0
                    )
                ],
                outputs: [BitcoinPaymentOutput(address: recipient.address, valueSats: 50000)],
                changeAddress: BitcoinTestWallet.address,
                feeSats: 500
            )
            let parsed = try ParsedBitcoinTransaction(hex: transaction.txHex)

            XCTAssertEqual(parsed.txid, transaction.txid)
            XCTAssertEqual(parsed.outputs.first, .init(valueSats: 50000, script: recipient.scriptPubKey), recipient.address)
            XCTAssertEqual(parsed.outputs.last?.valueSats, 49500, "Change returns to the wallet")
            XCTAssertEqual(
                parsed.outputs.last?.script,
                BitcoinAddressSupport.recipient(BitcoinTestWallet.address, network: .mainnet)?.scriptPubKey
            )
        }
    }

    /// A legacy recipient needs more than the SegWit dust floor; the builder refuses an amount
    /// nodes would not relay instead of producing a stuck transaction.
    func testAmountBelowTheRecipientsOwnDustLimitIsRefused() {
        XCTAssertThrowsError(
            try BitcoinTransactionBuilder.buildP2wpkhTransaction(
                mnemonic: BitcoinTestWallet.mnemonic,
                inputs: [
                    BitcoinSpendableUtxo(
                        address: BitcoinTestWallet.address,
                        txid: String(repeating: "11", count: 32),
                        valueSats: 100_000,
                        vout: 0
                    )
                ],
                outputs: [BitcoinPaymentOutput(address: "1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2", valueSats: 400)],
                changeAddress: BitcoinTestWallet.address,
                feeSats: 500
            )
        ) { error in
            XCTAssertEqual(error as? BitcoinTransactionError, .invalidOutputValue)
        }
    }
}
