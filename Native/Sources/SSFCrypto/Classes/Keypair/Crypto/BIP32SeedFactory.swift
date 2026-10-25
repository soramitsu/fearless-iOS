import Foundation
import IrohaCrypto

public struct BIP32SeedFactory: SeedFactoryProtocol {
    private let seedFactory: SNBIP39SeedCreatorProtocol = SNBIP39SeedCreator()
    private let mnemonicCreator: IRMnemonicCreatorProtocol

    public init(mnemonicLanguage: IRMnemonicLanguage = .english) {
        mnemonicCreator = IRMnemonicCreator(language: mnemonicLanguage)
    }

    public func createSeed(
        from password: String,
        strength: IRMnemonicStrength
    ) throws -> SeedFactoryResult {
        let mnemonic = try mnemonicCreator.randomMnemonic(strength)
        let normalizedPassphrase = createNormalizedPassphraseFrom(mnemonic)
        let seed = try seedFactory.deriveSeed(from: normalizedPassphrase, passphrase: password)

        return SeedFactoryResult(seed: seed, mnemonic: mnemonic)
    }

    public func deriveSeed(
        from mnemonicWords: String,
        password: String
    ) throws -> SeedFactoryResult {
        let mnemonic = try mnemonicCreator.mnemonic(fromList: mnemonicWords)
        let normalizedPassphrase = createNormalizedPassphraseFrom(mnemonic)
        let seed = try seedFactory.deriveSeed(from: normalizedPassphrase, passphrase: password)

        return SeedFactoryResult(seed: seed, mnemonic: mnemonic)
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
