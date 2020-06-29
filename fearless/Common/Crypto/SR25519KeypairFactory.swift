import Foundation
import IrohaCrypto

typealias SR25519KeypairResult = (keypair: SNKeypairProtocol, mnemonic: IRMnemonicProtocol)

protocol SR25519KeypairFactoryProtocol: class {
    func createKeypair(from password: String, strength: IRMnemonicStrength) throws -> SR25519KeypairResult
    func deriveKeypair(from mnemonicWords: String, password: String) throws -> SR25519KeypairResult
}

extension SR25519KeypairFactoryProtocol {
    func createKeypair() throws -> SR25519KeypairResult {
        return try createKeypair(from: "", strength: .entropy128)
    }

    func deriveKeypair(from mnemonic: String) throws -> SR25519KeypairResult {
        return try deriveKeypair(from: mnemonic, password: "")
    }
}

final class SR25519KeypairFactory: SR25519KeypairFactoryProtocol {
    private static let seedLength: Int = 32

    private lazy var seedFactory: SNBIP39SeedCreatorProtocol = SNBIP39SeedCreator()
    private lazy var keyFactory: SNKeyFactoryProtocol = SNKeyFactory()
    private lazy var mnemonicCreator = IRMnemonicCreator(language: .english)

    func createKeypair(from password: String, strength: IRMnemonicStrength) throws -> SR25519KeypairResult {
        let mnemonic = try mnemonicCreator.randomMnemonic(strength)
        let seed = try seedFactory.deriveSeed(from: mnemonic.entropy(), passphrase: password)
        let keypair = try keyFactory.createKeypair(fromSeed: seed.prefix(Self.seedLength))

        return SR25519KeypairResult(keypair: keypair, mnemonic: mnemonic)
    }

    func deriveKeypair(from mnemonicWords: String, password: String) throws -> SR25519KeypairResult {
        let mnemonic = try mnemonicCreator.mnemonic(fromList: mnemonicWords)
        let seed = try seedFactory.deriveSeed(from: mnemonic.entropy(), passphrase: password)
        let keypair = try keyFactory.createKeypair(fromSeed: seed.prefix(Self.seedLength))

        return SR25519KeypairResult(keypair: keypair, mnemonic: mnemonic)
    }
}
