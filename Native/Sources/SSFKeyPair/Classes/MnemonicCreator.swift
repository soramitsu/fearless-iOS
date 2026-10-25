import Foundation
import IrohaCrypto

// sourcery: AutoMockable
public protocol MnemonicCreator {
    func randomMnemonic(strength: IRMnemonicStrength) throws -> IRMnemonicProtocol
    func mnemonic(fromList mnemonicPhrase: String) throws -> IRMnemonicProtocol
    func mnemonic(fromEntropy entropy: Data) throws -> IRMnemonicProtocol
}

public final class MnemonicCreatorImpl: MnemonicCreator {
    private lazy var mnemonicCreator: IRMnemonicCreatorProtocol = IRMnemonicCreator()

    public func randomMnemonic(strength: IRMnemonicStrength) throws -> IRMnemonicProtocol {
        try mnemonicCreator.randomMnemonic(strength)
    }

    public func mnemonic(fromList mnemonicPhrase: String) throws -> IRMnemonicProtocol {
        try mnemonicCreator.mnemonic(fromList: mnemonicPhrase)
    }

    public func mnemonic(fromEntropy entropy: Data) throws -> IRMnemonicProtocol {
        try mnemonicCreator.mnemonic(fromEntropy: entropy)
    }

    public init() {}
}
