import Foundation
import WalletCore

/// A wallet as the preview keeps it: the public model plus the made-up
/// account data the fake services answer from.
struct StoredWallet: Sendable {
    var wallet: Wallet
    /// 32 bytes standing in for the Substrate account id.
    var substrateAccount: [UInt8]?
    /// Known address strings per SS58 prefix (the public development accounts).
    var substrateAddresses: [UInt16: String]
    var evmAddress: String?
    var phrase: [String]?
    /// Derivation choices the wallet was made with (returned with the phrase).
    var options: DerivationOptions = .standard

    func address(on chain: Chain) -> String? {
        switch chain.ecosystem {
        case .evm:
            return evmAddress
        case .substrate:
            guard let substrateAccount else { return nil }
            let prefix = chain.ss58Prefix ?? 42
            if let known = substrateAddresses[prefix] { return known }
            return PreviewAddressCodec.base58Encode([UInt8(truncatingIfNeeded: prefix)] + substrateAccount + [0x50, 0x56])
        }
    }
}

struct PreviewBalance: Sendable {
    var total: TokenAmount
    var locked: TokenAmount

    var transferable: TokenAmount { total.subtractingClamped(locked) }
}

/// Sample wallets, balances, prices and history. Every account here is a
/// public development account (Substrate's Alice, Bob and Charlie; the
/// first accounts of the Hardhat test mnemonic). None of it is secret and
/// none of it may hold funds.
public enum PreviewSampleData {
    public static let mainWalletID = WalletID(UUID(uuidString: "00000000-0000-4000-8000-000000000001") ?? UUID())
    public static let savingsWalletID = WalletID(UUID(uuidString: "00000000-0000-4000-8000-000000000002") ?? UUID())
    public static let watchWalletID = WalletID(UUID(uuidString: "00000000-0000-4000-8000-000000000003") ?? UUID())

    /// Substrate development accounts: public key and address per SS58 prefix.
    struct DevAccount: Sendable {
        let publicKeyHex: String
        let polkadot: String
        let kusama: String
        let generic: String

        var addresses: [UInt16: String] { [0: polkadot, 2: kusama, 42: generic] }
        var publicKey: [UInt8] { PreviewBIP39.bytes(fromHex: publicKeyHex) }
    }

    static let alice = DevAccount(
        publicKeyHex: "d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d",
        polkadot: "15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5",
        kusama: "HNZata7iMYWmk5RvZRTiAsSDhV8366zq2YGb3tLH5Upf74F",
        generic: "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
    )
    static let bob = DevAccount(
        publicKeyHex: "8eaf04151687736326c9fea17e25fc5287613693c912909cb226aa4794f26a48",
        polkadot: "14E5nqKAp3oAJcmzgZhUD2RcptBeUBScxKHgJKU4HPNcKVf3",
        kusama: "FoQJpPyadYccjavVdTWxpxU7rUEaYhfLCPwXgkfD6Zat9QP",
        generic: "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
    )
    static let charlie = DevAccount(
        publicKeyHex: "90b5ab205c6974c9ea841be688864633dc9ca8a357843eeacf2314649965fe22",
        polkadot: "14Gjs1TD93gnwEBfDMHoCgsuf1s2TVKUP6Z1qKmAZnZ8cW5q",
        kusama: "Fr4NzY1udSFFLzb2R3qxVQkwz9cZraWkyfH4h3mVVk7BK7P",
        generic: "5FLSigC9HGRKVhB9FiEo4Y3koPsNmBmLJbpXg2mp1hXcS59Y"
    )

    /// The first three accounts of the public Hardhat test mnemonic.
    static let evmAccount0 = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    static let evmAccount1 = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    static let evmAccount2 = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

    /// A valid recipient on Polkadot that is not one of the sample wallets.
    public static let sampleRecipientPolkadot = charlie.polkadot
    /// A Kusama address, for wrong-network examples.
    public static let sampleRecipientKusama = charlie.kusama
    public static let sampleRecipientEVM = evmAccount2

    private static func evmBytes(_ address: String) -> Data {
        Data(PreviewBIP39.bytes(fromHex: String(address.dropFirst(2))))
    }

    static func standardWallets(now: Date) -> [StoredWallet] {
        let day: TimeInterval = 86_400
        return [
            StoredWallet(
                wallet: Wallet(
                    id: mainWalletID, name: "Main Wallet", origin: .mnemonic,
                    accounts: [
                        WalletAccount(ecosystem: .substrate, cryptoType: .sr25519, publicKey: Data(alice.publicKey), derivationPath: "//polkadot"),
                        WalletAccount(ecosystem: .evm, cryptoType: .ecdsa, publicKey: evmBytes(evmAccount0), derivationPath: "m/44'/60'/0'/0/1")
                    ],
                    createdAt: now.addingTimeInterval(-210 * day), isBackedUp: true
                ),
                substrateAccount: alice.publicKey, substrateAddresses: alice.addresses, evmAddress: evmAccount0,
                phrase: PreviewBIP39.mnemonic(fromEntropy: PreviewBIP39.testEntropy(for: .words12)),
                // Imported with its own paths, so a backup must show them too.
                options: DerivationOptions(substrateCryptoType: .sr25519, substrateDerivationPath: "//polkadot///preview-only", evmDerivationPath: "m/44'/60'/0'/0/1")
            ),
            StoredWallet(
                wallet: Wallet(
                    id: savingsWalletID, name: "Savings", origin: .created,
                    accounts: [
                        WalletAccount(ecosystem: .substrate, cryptoType: .sr25519, publicKey: Data(bob.publicKey), derivationPath: nil),
                        WalletAccount(ecosystem: .evm, cryptoType: .ecdsa, publicKey: evmBytes(evmAccount1), derivationPath: DerivationOptions.defaultEVMPath)
                    ],
                    createdAt: now.addingTimeInterval(-12 * day), isBackedUp: false
                ),
                substrateAccount: bob.publicKey, substrateAddresses: bob.addresses, evmAddress: evmAccount1,
                phrase: PreviewBIP39.mnemonic(fromEntropy: PreviewBIP39.testEntropy(for: .words24))
            ),
            StoredWallet(
                wallet: Wallet(
                    id: watchWalletID, name: "Treasury (watch)", origin: .watchOnly,
                    accounts: [
                        WalletAccount(ecosystem: .substrate, cryptoType: .sr25519, publicKey: Data(charlie.publicKey), derivationPath: nil)
                    ],
                    createdAt: now.addingTimeInterval(-40 * day), isBackedUp: true
                ),
                substrateAccount: charlie.publicKey, substrateAddresses: charlie.addresses, evmAddress: nil, phrase: nil
            )
        ]
    }

    private static func balance(_ asset: Asset, _ total: String, locked: String = "0") -> (AssetID, PreviewBalance) {
        (asset.id, PreviewBalance(total: PreviewCatalog.amount(total, asset.decimals), locked: PreviewCatalog.amount(locked, asset.decimals)))
    }

    static func standardBalances() -> [WalletID: [AssetID: PreviewBalance]] {
        let c = PreviewCatalog.self
        return [
            mainWalletID: Dictionary(uniqueKeysWithValues: [
                balance(c.dot, "1250.5", locked: "500"),
                balance(c.dotAssetHub, "320.75"),
                balance(c.usdtAssetHub, "2500"),
                balance(c.usdcAssetHub, "1200.5"),
                balance(c.ksm, "42.125", locked: "10"),
                balance(c.ksmAssetHub, "3.5"),
                balance(c.wnd, "100"),
                balance(c.eth, "1.2345"),
                balance(c.usdtEthereum, "850.25"),
                balance(c.usdcEthereum, "0"),
                balance(c.bnb, "2.5"),
                balance(c.pol, "1500"),
                balance(c.sepoliaETH, "0.5")
            ]),
            savingsWalletID: Dictionary(uniqueKeysWithValues: [
                balance(c.dot, "8200", locked: "8000"),
                balance(c.dotAssetHub, "12.4"),
                balance(c.usdtAssetHub, "0"),
                balance(c.usdcAssetHub, "15000"),
                balance(c.ksm, "0"),
                balance(c.ksmAssetHub, "0"),
                balance(c.wnd, "0"),
                balance(c.eth, "4.02"),
                balance(c.usdtEthereum, "0"),
                balance(c.usdcEthereum, "2500"),
                balance(c.bnb, "0"),
                balance(c.pol, "0"),
                balance(c.sepoliaETH, "0")
            ]),
            watchWalletID: Dictionary(uniqueKeysWithValues: [
                balance(c.dot, "154000.25", locked: "150000"),
                balance(c.dotAssetHub, "2500"),
                balance(c.usdtAssetHub, "480000"),
                balance(c.usdcAssetHub, "125000"),
                balance(c.ksm, "9100", locked: "9000"),
                balance(c.ksmAssetHub, "45.5"),
                balance(c.wnd, "0")
            ])
        ]
    }

    /// Sample prices in US dollars with their 24-hour change in percent.
    static let usdPrices: [String: (price: Decimal, change: Decimal)] = [
        "polkadot": (Decimal(string: "4.12") ?? 0, Decimal(string: "2.34") ?? 0),
        "kusama": (Decimal(string: "14.85") ?? 0, Decimal(string: "-1.12") ?? 0),
        "ethereum": (Decimal(string: "3412.55") ?? 0, Decimal(string: "0.84") ?? 0),
        "binancecoin": (Decimal(string: "612.4") ?? 0, Decimal(string: "-0.35") ?? 0),
        "polygon-ecosystem-token": (Decimal(string: "0.2145") ?? 0, Decimal(string: "4.02") ?? 0),
        "tether": (Decimal(string: "1.0003") ?? 0, Decimal(string: "0.01") ?? 0),
        "usd-coin": (Decimal(string: "0.9999") ?? 0, Decimal(string: "-0.01") ?? 0)
    ]

    /// Sample exchange rates from the US dollar.
    static let usdRates: [String: Decimal] = [
        "usd": 1,
        "eur": Decimal(string: "0.92") ?? 1,
        "jpy": Decimal(string: "151.3") ?? 1,
        "gbp": Decimal(string: "0.79") ?? 1,
        "chf": Decimal(string: "0.88") ?? 1,
        "krw": Decimal(string: "1375") ?? 1,
        "cny": Decimal(string: "7.24") ?? 1,
        "inr": Decimal(string: "83.4") ?? 1,
        "rub": Decimal(string: "96.5") ?? 1,
        "brl": Decimal(string: "5.42") ?? 1
    ]

    /// A made-up transaction hash; the repeated pattern makes it obviously fake.
    static func fakeHash(_ seed: Int) -> String {
        let pattern = String(format: "%04x", (seed &* 0x9E37 &+ 0x1F2E) & 0xFFFF)
        return "0x" + String(repeating: pattern, count: 16)
    }

    static func standardActivity(now: Date) -> [ActivityItem] {
        let c = PreviewCatalog.self
        let minute: TimeInterval = 60
        let hour: TimeInterval = 3_600
        let day: TimeInterval = 86_400
        var seed = 0

        func item(
            _ wallet: WalletID, _ asset: Asset, _ direction: ActivityDirection, _ amount: String, counterparty: String?,
            fee: (Asset, String)? = nil, ago: TimeInterval, status: ActivityStatus = .success, title: String? = nil
        ) -> ActivityItem {
            seed += 1
            let hash = fakeHash(seed)
            let chain = c.chain(asset.chainID)
            return ActivityItem(
                id: "preview-\(seed)", walletID: wallet, assetID: asset.id, direction: direction, counterparty: counterparty,
                amount: c.amount(amount, asset.decimals),
                fee: fee.map { c.amount($0.1, $0.0.decimals) },
                timestamp: now.addingTimeInterval(-ago), status: status, hash: hash,
                explorerURL: chain?.explorer?.transactionURL(hash: hash), title: title
            )
        }

        let main = mainWalletID
        let savings = savingsWalletID
        let watch = watchWalletID
        return [
            item(main, c.dot, .outgoing, "25", counterparty: bob.polkadot, fee: (c.dot, "0.0157"), ago: 2 * minute, status: .pending),
            item(main, c.usdcAssetHub, .incoming, "1200.5", counterparty: charlie.polkadot, ago: 3 * hour),
            item(main, c.eth, .outgoing, "0.25", counterparty: evmAccount1, fee: (c.eth, "0.00042"), ago: 26 * hour),
            item(main, c.dot, .other, "2.3145", counterparty: nil, ago: 30 * hour, title: "Staking reward"),
            item(main, c.usdtEthereum, .incoming, "500", counterparty: evmAccount2, ago: 2 * day),
            item(main, c.dot, .other, "2.2981", counterparty: nil, ago: 2 * day + 6 * hour, title: "Staking reward"),
            item(main, c.ksm, .outgoing, "5", counterparty: bob.kusama, fee: (c.ksm, "0.000533"), ago: 3 * day, status: .failed),
            item(main, c.usdtAssetHub, .outgoing, "100", counterparty: bob.polkadot, fee: (c.dotAssetHub, "0.0021"), ago: 4 * day),
            item(main, c.bnb, .incoming, "1.5", counterparty: evmAccount1, ago: 6 * day),
            item(main, c.dotAssetHub, .selfTransfer, "10", counterparty: alice.polkadot, fee: (c.dotAssetHub, "0.0021"), ago: 8 * day),
            item(main, c.pol, .incoming, "1000", counterparty: evmAccount2, ago: 12 * day),
            item(main, c.pol, .outgoing, "350", counterparty: evmAccount1, fee: (c.pol, "0.0042"), ago: 15 * day),
            item(main, c.wnd, .incoming, "100", counterparty: bob.generic, ago: 20 * day),
            item(main, c.sepoliaETH, .incoming, "0.5", counterparty: evmAccount2, ago: 21 * day),
            item(savings, c.usdcAssetHub, .incoming, "15000", counterparty: alice.polkadot, ago: 5 * day),
            item(savings, c.dot, .incoming, "8200", counterparty: alice.polkadot, ago: 11 * day),
            item(savings, c.eth, .incoming, "4.02", counterparty: evmAccount0, ago: 11 * day + hour),
            item(watch, c.dot, .other, "311.02", counterparty: nil, ago: 20 * hour, title: "Staking reward"),
            item(watch, c.usdtAssetHub, .outgoing, "20000", counterparty: alice.polkadot, fee: (c.dotAssetHub, "0.0021"), ago: 9 * day)
        ]
    }
}
