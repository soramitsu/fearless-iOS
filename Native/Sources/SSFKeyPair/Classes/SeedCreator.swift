import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels
import SSFUtils

public typealias SeedCreatorResult = (seed: Data, mnemonic: IRMnemonicProtocol)

// sourcery: AutoMockable
public protocol SeedCreator {
    func createSeed(
        derivationPath: String,
        strength: IRMnemonicStrength,
        ethereumBased: Bool,
        cryptoType: CryptoType
    ) throws -> SeedCreatorResult

    func deriveSeed(
        mnemonicWords: String,
        derivationPath: String,
        ethereumBased: Bool,
        cryptoType: CryptoType
    ) throws -> SeedCreatorResult
}

public final class SeedCreatorImpl: SeedCreator {
    private lazy var mnemonicCreator: IRMnemonicCreatorProtocol = IRMnemonicCreator()

    private lazy var seedCreator: SNBIP39SeedCreatorProtocol = SNBIP39SeedCreator()

    private lazy var commonCrypto: CommonCrypto = CommonCryptoImpl()

    public init() {}

    convenience init(commonCrypto: CommonCrypto) {
        self.init()
        self.commonCrypto = commonCrypto
    }

    // MARK: - Public methods

    public func createSeed(
        derivationPath: String,
        strength: IRMnemonicStrength,
        ethereumBased: Bool,
        cryptoType: CryptoType
    ) throws -> SeedCreatorResult {
        let junctionResult = try commonCrypto.getJunctionResult(
            from: derivationPath,
            ethereumBased: ethereumBased
        )

        let password = junctionResult?.password ?? ""

        return ethereumBased
            ? try createSeedWithNormalizedPassphras(
                from: password,
                strength: strength,
                derivationPath: derivationPath,
                cryptoType: .ecdsa
            )
            : try createSeed(from: password, strength: strength)
    }

    public func deriveSeed(
        mnemonicWords: String,
        derivationPath: String,
        ethereumBased: Bool,
        cryptoType: CryptoType
    ) throws -> SeedCreatorResult {
        let junctionResult = try commonCrypto.getJunctionResult(
            from: derivationPath,
            ethereumBased: ethereumBased
        )

        let password = junctionResult?.password ?? ""

        return ethereumBased
            ? try deriveSeedWithNormalizedPassphras(
                from: mnemonicWords,
                password: password,
                derivationPath: derivationPath,
                cryptoType: .ecdsa
            )
            : try deriveSeed(from: mnemonicWords, password: password)
    }

    // MARK: - Private methods

    private func createSeed(
        from password: String,
        strength: IRMnemonicStrength
    ) throws -> SeedCreatorResult {
        let mnemonic = try mnemonicCreator.randomMnemonic(strength)
        let seed = try seedCreator.deriveSeed(from: mnemonic.entropy(), passphrase: password)

        return SeedCreatorResult(seed: seed.miniSeed, mnemonic: mnemonic)
    }

    private func deriveSeed(
        from mnemonicWords: String,
        password: String
    ) throws -> SeedCreatorResult {
        let mnemonic = try mnemonicCreator.mnemonic(fromList: mnemonicWords)
        let seed = try seedCreator.deriveSeed(from: mnemonic.entropy(), passphrase: password)

        return SeedCreatorResult(seed: seed.miniSeed, mnemonic: mnemonic)
    }

    private func createSeedWithNormalizedPassphras(
        from password: String,
        strength: IRMnemonicStrength,
        derivationPath: String,
        cryptoType: CryptoType
    ) throws -> SeedCreatorResult {
        let mnemonic = try mnemonicCreator.randomMnemonic(strength)
        let normalizedPassphrase = createNormalizedPassphraseFrom(mnemonic)
        let seed = try seedCreator.deriveSeed(from: normalizedPassphrase, passphrase: password)

        let query = try commonCrypto.getQuery(
            seed: seed,
            derivationPath: derivationPath,
            cryptoType: cryptoType,
            ethereumBased: true
        )

        return SeedCreatorResult(seed: query.privateKey, mnemonic: mnemonic)
    }

    private func deriveSeedWithNormalizedPassphras(
        from mnemonicWords: String,
        password: String,
        derivationPath: String,
        cryptoType: CryptoType
    ) throws -> SeedCreatorResult {
        let mnemonic = try mnemonicCreator.mnemonic(fromList: mnemonicWords)
        let normalizedPassphrase = createNormalizedPassphraseFrom(mnemonic)
        let seed = try seedCreator.deriveSeed(from: normalizedPassphrase, passphrase: password)

        let query = try commonCrypto.getQuery(
            seed: seed,
            derivationPath: derivationPath,
            cryptoType: cryptoType,
            ethereumBased: true
        )

        return SeedCreatorResult(seed: query.privateKey, mnemonic: mnemonic)
    }

    private func createNormalizedPassphraseFrom(_ mnemonic: IRMnemonicProtocol) -> Data {
        Data(
            mnemonic
                .toString()
                .decomposedStringWithCompatibilityMapping
                .utf8
        )
    }
}
