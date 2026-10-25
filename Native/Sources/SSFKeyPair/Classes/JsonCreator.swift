import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels
import SSFUtils

public typealias JsonCreatorResult = (json: Data, mnemonic: IRMnemonicProtocol)

public protocol JsonCreator {
    func createJson(
        strength: IRMnemonicStrength,
        walletName: String,
        password: String,
        cryptoType: CryptoType,
        derivationPath: String,
        isEthereumBased: Bool
    ) throws -> JsonCreatorResult

    func deriveJson(
        mnemonicWords: String,
        walletName: String,
        password: String,
        cryptoType: CryptoType,
        derivationPath: String,
        isEthereumBased: Bool
    ) throws -> JsonCreatorResult
}

public final class JsonCreatorImpl: JsonCreator {
    private lazy var mnemonicCreator: MnemonicCreator = MnemonicCreatorImpl()

    private lazy var seedCreator: SeedCreator = SeedCreatorImpl()

    private lazy var commonCrypto: CommonCrypto = CommonCryptoImpl()

    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    public init() {}

    // MARK: - Public methods

    public func createJson(
        strength: IRMnemonicStrength,
        walletName: String,
        password: String,
        cryptoType: CryptoType,
        derivationPath: String,
        isEthereumBased: Bool
    ) throws -> JsonCreatorResult {
        let mnemonic = try mnemonicCreator.randomMnemonic(strength: strength)

        let jsonResult = try deriveJson(
            mnemonicWords: mnemonic.toString(),
            walletName: walletName,
            password: password,
            cryptoType: cryptoType,
            derivationPath: derivationPath,
            isEthereumBased: isEthereumBased
        )

        return JsonCreatorResult(json: jsonResult.json, mnemonic: mnemonic)
    }

    public func deriveJson(
        mnemonicWords: String,
        walletName: String,
        password: String,
        cryptoType: CryptoType,
        derivationPath: String,
        isEthereumBased: Bool
    ) throws -> JsonCreatorResult {
        let seedResult = try seedCreator.deriveSeed(
            mnemonicWords: mnemonicWords,
            derivationPath: derivationPath,
            ethereumBased: isEthereumBased,
            cryptoType: cryptoType
        )

        let query = try commonCrypto.getQuery(
            seed: seedResult.seed,
            derivationPath: derivationPath,
            cryptoType: cryptoType,
            ethereumBased: isEthereumBased
        )

        let builder = KeystoreBuilder().with(name: walletName)

        let keystoreData = KeystoreData(
            address: query.address.toHex(includePrefix: isEthereumBased),
            secretKeyData: query.privateKey,
            publicKeyData: query.publicKey,
            cryptoType: cryptoType
        )

        let definition = try builder.build(
            from: keystoreData,
            password: password,
            isEthereum: isEthereumBased
        )

        let json = try jsonEncoder.encode(definition)
        let mnemonic = seedResult.mnemonic

        return JsonCreatorResult(json: json, mnemonic: mnemonic)
    }
}
