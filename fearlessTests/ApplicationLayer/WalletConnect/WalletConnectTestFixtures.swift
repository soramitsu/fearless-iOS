import BigInt
import FearlessWalletConnect
import Foundation
import IrohaCrypto
import SoraKeystore
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import Web3
import XCTest
@testable import fearless

/// Wallets with real keys, chains and sessions for the WalletConnect request tests.
enum WalletConnectTestFixtures {
    static let westendGenesis = "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
    static let polkadotGenesis = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"

    struct EthereumWallet {
        let wallet: fearless.MetaAccountModel
        let privateKey: EthereumPrivateKey

        var address: Data { Data(privateKey.address.rawAddress) }
        var addressHex: String { address.toHex(includePrefix: true) }
    }

    struct SubstrateWallet {
        let wallet: fearless.MetaAccountModel
        let keypair: SNKeypairProtocol

        var accountId: Data { keypair.publicKey().rawData() }
    }

    // MARK: - Wallets

    static func ethereumWallet(seed: UInt8, keystore: KeystoreProtocol) throws -> EthereumWallet {
        let privateKey = try EthereumPrivateKey(privateKey: Array(repeating: seed, count: 32))
        let wallet = metaAccount(
            name: "EVM wallet \(seed)",
            substrateAccountId: nil,
            substratePublicKey: nil,
            ethereumAddress: Data(privateKey.address.rawAddress),
            ethereumPublicKey: Data(privateKey.publicKey.rawPublicKey)
        )
        try keystore.addKey(
            Data(privateKey.rawPrivateKey),
            with: fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: nil)
        )
        return EthereumWallet(wallet: wallet, privateKey: privateKey)
    }

    static func substrateWallet(seed: UInt8, keystore: KeystoreProtocol) throws -> SubstrateWallet {
        let keypair = try SNKeyFactory().createKeypair(fromSeed: Data(repeating: seed, count: 32))
        let publicKey = keypair.publicKey().rawData()
        let wallet = metaAccount(
            name: "Substrate wallet \(seed)",
            substrateAccountId: publicKey,
            substratePublicKey: publicKey,
            ethereumAddress: nil,
            ethereumPublicKey: nil
        )
        try keystore.addKey(
            keypair.privateKey().rawData(),
            with: fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: nil)
        )
        return SubstrateWallet(wallet: wallet, keypair: keypair)
    }

    private static func metaAccount(
        name: String,
        substrateAccountId: Data?,
        substratePublicKey: Data?,
        ethereumAddress: Data?,
        ethereumPublicKey: Data?
    ) -> fearless.MetaAccountModel {
        fearless.MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: CryptoType.sr25519.rawValue,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    // MARK: - Chains

    static func ethereumChain(chainId: String = "1", name: String = "Ethereum", tokens: [AssetModel] = []) -> ChainModel {
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: [.ethereum],
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        chain.assets = Set([asset(id: "eth", symbol: "ETH", precision: 18, isUtility: true)] + tokens)
        return chain
    }

    static func westend() -> ChainModel {
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: westendGenesis,
            parentId: nil,
            paraId: nil,
            name: "Westend",
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        chain.assets = [asset(id: "wnd", symbol: "WND", precision: 12, isUtility: true)]
        return chain
    }

    static func polkadot() -> ChainModel {
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: polkadotGenesis,
            parentId: nil,
            paraId: nil,
            name: "Polkadot",
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        chain.assets = [asset(id: "dot", symbol: "DOT", precision: 10, isUtility: true)]
        return chain
    }

    static func asset(id: String, symbol: String, precision: UInt16, isUtility: Bool = false) -> AssetModel {
        AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: precision,
            icon: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: isUtility,
            isNative: isUtility,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: isUtility ? .normal : .erc20,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
    }

    static func ethereumBlockchain(_ chainId: String = "1") throws -> Blockchain {
        try XCTUnwrap(Blockchain("eip155:\(chainId)"))
    }

    static func westendBlockchain() throws -> Blockchain {
        try XCTUnwrap(Blockchain("polkadot:\(westendGenesis.prefix(32))"))
    }

    static func polkadotBlockchain() throws -> Blockchain {
        try XCTUnwrap(Blockchain("polkadot:\(polkadotGenesis.prefix(32))"))
    }

    // MARK: - Sessions and requests

    static func session(
        topic: String = "wc-topic",
        approving accounts: [(Blockchain, String)],
        peerURL: String = "https://app.example.org"
    ) throws -> Session {
        var namespaces: [String: SessionNamespace] = [:]
        for (blockchain, address) in accounts {
            let account = try XCTUnwrap(Account(blockchain: blockchain, address: address))
            var namespace = namespaces[blockchain.namespace] ?? SessionNamespace(
                chains: [],
                accounts: [],
                methods: Set(WalletConnectMethod.allCases.map(\.rawValue)),
                events: []
            )
            namespace.accounts.append(account)
            namespace.chains = (namespace.chains ?? []) + [blockchain]
            namespaces[blockchain.namespace] = namespace
        }

        return Session(
            topic: topic,
            pairingTopic: "wc-pairing",
            peer: AppMetadata(
                name: "Example dApp",
                description: "",
                url: peerURL,
                icons: [],
                redirect: try AppMetadata.Redirect(native: "example://", universal: nil)
            ),
            requiredNamespaces: [:],
            optionalNamespaces: nil,
            namespaces: namespaces,
            sessionProperties: nil,
            expiryDate: Date(timeIntervalSinceNow: 3600)
        )
    }

    /// Request params decoded from JSON, as the SDK delivers them.
    static func request(
        topic: String = "wc-topic",
        method: WalletConnectMethod,
        params json: String,
        chain blockchain: Blockchain
    ) throws -> Request {
        let params = try JSONDecoder().decode(AnyCodable.self, from: Data(json.utf8))
        return try Request(topic: topic, method: method.rawValue, params: params, chainId: blockchain)
    }

    /// The Polkadot 9370 runtime the app bundles, with its V14 type schema.
    static func polkadotCoderFactory(specVersion: UInt32 = 9370, txVersion: UInt32 = 20) throws -> RuntimeCoderFactoryProtocol {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "polkadot-9370metadata", withExtension: nil))
        let hex = try String(contentsOf: url).components(separatedBy: .whitespacesAndNewlines).joined()
        let metadata = try RuntimeMetadata(scaleDecoder: ScaleDecoder(data: Data(hexStringSSF: hex)))
        let catalog = try RuntimeHelper.createTypeRegistryCatalog(
            from: "runtime-default",
            networkName: "runtime-polkadot",
            runtimeMetadata: metadata
        )
        return TestRuntimeCoderFactory(catalog: catalog, specVersion: specVersion, txVersion: txVersion, metadata: metadata)
    }
}

/// Gas quotes for EVM requests; counts calls so tests can show what was fetched when.
final class WalletConnectQuotingStub: WalletConnectEthereumQuoting {
    var nonce = BigUInt(7)
    var price = BigUInt(20_000_000_000)
    var eip1559 = false
    var estimate = BigUInt(21000)
    var failure: Error?
    private(set) var calls: [String] = []

    func pendingNonce(of _: Data) async throws -> BigUInt {
        calls.append("nonce")
        if let failure = failure { throw failure }
        return nonce
    }

    func gasPrice() async throws -> BigUInt {
        calls.append("gasPrice")
        if let failure = failure { throw failure }
        return price
    }

    func supportsEip1559() async -> Bool {
        calls.append("eip1559")
        return eip1559
    }

    func estimateGas(from _: Data, to _: Data, value _: BigUInt, data _: Data) async throws -> BigUInt {
        calls.append("estimateGas")
        if let failure = failure { throw failure }
        return estimate
    }
}

final class WalletConnectRuntimeStub: WalletConnectPolkadotRuntimeProviding {
    var coderFactory: RuntimeCoderFactoryProtocol?
    var fee = BigUInt(15_000_000_000)
    private(set) var feeQueries: [Data] = []

    func coderFactory(for _: ChainModel) async throws -> RuntimeCoderFactoryProtocol {
        guard let coderFactory = coderFactory else {
            throw fearless.RuntimeProviderError.providerUnavailable
        }
        return coderFactory
    }

    func inclusionFee(of extrinsic: Data, chain _: ChainModel) async throws -> BigUInt {
        feeQueries.append(extrinsic)
        return fee
    }
}
