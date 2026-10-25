// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import IrohaCrypto
@testable import SSFKeyPair
@testable import SSFModels
@testable import SSFCrypto

public class SeedCreatorMock: SeedCreator {
public init() {}

    //MARK: - createSeed

    public var createSeedDerivationPathStrengthEthereumBasedCryptoTypeThrowableError: Error?
    public var createSeedDerivationPathStrengthEthereumBasedCryptoTypeCallsCount = 0
    public var createSeedDerivationPathStrengthEthereumBasedCryptoTypeCalled: Bool {
        return createSeedDerivationPathStrengthEthereumBasedCryptoTypeCallsCount > 0
    }
    public var createSeedDerivationPathStrengthEthereumBasedCryptoTypeReceivedArguments: (derivationPath: String, strength: IRMnemonicStrength, ethereumBased: Bool, cryptoType: CryptoType)?
    public var createSeedDerivationPathStrengthEthereumBasedCryptoTypeReceivedInvocations: [(derivationPath: String, strength: IRMnemonicStrength, ethereumBased: Bool, cryptoType: CryptoType)] = []
    public var createSeedDerivationPathStrengthEthereumBasedCryptoTypeReturnValue: SeedCreatorResult!
    public var createSeedDerivationPathStrengthEthereumBasedCryptoTypeClosure: ((String, IRMnemonicStrength, Bool, CryptoType) throws -> SeedCreatorResult)?

    public func createSeed(derivationPath: String, strength: IRMnemonicStrength, ethereumBased: Bool, cryptoType: CryptoType) throws -> SeedCreatorResult {
        if let error = createSeedDerivationPathStrengthEthereumBasedCryptoTypeThrowableError {
            throw error
        }
        createSeedDerivationPathStrengthEthereumBasedCryptoTypeCallsCount += 1
        createSeedDerivationPathStrengthEthereumBasedCryptoTypeReceivedArguments = (derivationPath: derivationPath, strength: strength, ethereumBased: ethereumBased, cryptoType: cryptoType)
        createSeedDerivationPathStrengthEthereumBasedCryptoTypeReceivedInvocations.append((derivationPath: derivationPath, strength: strength, ethereumBased: ethereumBased, cryptoType: cryptoType))
        return try createSeedDerivationPathStrengthEthereumBasedCryptoTypeClosure.map({ try $0(derivationPath, strength, ethereumBased, cryptoType) }) ?? createSeedDerivationPathStrengthEthereumBasedCryptoTypeReturnValue
    }

    //MARK: - deriveSeed

    public var deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeThrowableError: Error?
    public var deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeCallsCount = 0
    public var deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeCalled: Bool {
        return deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeCallsCount > 0
    }
    public var deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeReceivedArguments: (mnemonicWords: String, derivationPath: String, ethereumBased: Bool, cryptoType: CryptoType)?
    public var deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeReceivedInvocations: [(mnemonicWords: String, derivationPath: String, ethereumBased: Bool, cryptoType: CryptoType)] = []
    public var deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeReturnValue: SeedCreatorResult!
    public var deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeClosure: ((String, String, Bool, CryptoType) throws -> SeedCreatorResult)?

    public func deriveSeed(mnemonicWords: String, derivationPath: String, ethereumBased: Bool, cryptoType: CryptoType) throws -> SeedCreatorResult {
        if let error = deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeThrowableError {
            throw error
        }
        deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeCallsCount += 1
        deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeReceivedArguments = (mnemonicWords: mnemonicWords, derivationPath: derivationPath, ethereumBased: ethereumBased, cryptoType: cryptoType)
        deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeReceivedInvocations.append((mnemonicWords: mnemonicWords, derivationPath: derivationPath, ethereumBased: ethereumBased, cryptoType: cryptoType))
        return try deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeClosure.map({ try $0(mnemonicWords, derivationPath, ethereumBased, cryptoType) }) ?? deriveSeedMnemonicWordsDerivationPathEthereumBasedCryptoTypeReturnValue
    }

}
