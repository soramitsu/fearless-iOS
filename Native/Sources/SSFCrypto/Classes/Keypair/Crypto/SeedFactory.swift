import Foundation
import IrohaCrypto

public typealias SeedFactoryResult = (seed: Data, mnemonic: IRMnemonicProtocol)

public protocol SeedFactoryProtocol {
    func createSeed(from password: String, strength: IRMnemonicStrength) throws -> SeedFactoryResult
    func deriveSeed(from mnemonicWords: String, password: String) throws -> SeedFactoryResult
}

public struct SeedFactory: SeedFactoryProtocol {
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
        let seed = try seedFactory.deriveSeed(from: mnemonic.entropy(), passphrase: password)

        return SeedFactoryResult(seed: seed, mnemonic: mnemonic)
    }

    public func deriveSeed(
        from mnemonicWords: String,
        password: String
    ) throws -> SeedFactoryResult {
        let mnemonic = try mnemonicCreator.mnemonic(fromList: mnemonicWords)
        let seed = try seedFactory.deriveSeed(from: mnemonic.entropy(), passphrase: password)

        return SeedFactoryResult(seed: seed, mnemonic: mnemonic)
    }
}
