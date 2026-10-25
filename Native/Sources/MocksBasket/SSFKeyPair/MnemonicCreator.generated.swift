// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import IrohaCrypto
@testable import SSFKeyPair
@testable import SSFModels
@testable import SSFCrypto

public class MnemonicCreatorMock: MnemonicCreator {
public init() {}

    //MARK: - randomMnemonic

    public var randomMnemonicStrengthThrowableError: Error?
    public var randomMnemonicStrengthCallsCount = 0
    public var randomMnemonicStrengthCalled: Bool {
        return randomMnemonicStrengthCallsCount > 0
    }
    public var randomMnemonicStrengthReceivedStrength: IRMnemonicStrength?
    public var randomMnemonicStrengthReceivedInvocations: [IRMnemonicStrength] = []
    public var randomMnemonicStrengthReturnValue: IRMnemonicProtocol!
    public var randomMnemonicStrengthClosure: ((IRMnemonicStrength) throws -> IRMnemonicProtocol)?

    public func randomMnemonic(strength: IRMnemonicStrength) throws -> IRMnemonicProtocol {
        if let error = randomMnemonicStrengthThrowableError {
            throw error
        }
        randomMnemonicStrengthCallsCount += 1
        randomMnemonicStrengthReceivedStrength = strength
        randomMnemonicStrengthReceivedInvocations.append(strength)
        return try randomMnemonicStrengthClosure.map({ try $0(strength) }) ?? randomMnemonicStrengthReturnValue
    }

    //MARK: - mnemonic

    public var mnemonicFromListThrowableError: Error?
    public var mnemonicFromListCallsCount = 0
    public var mnemonicFromListCalled: Bool {
        return mnemonicFromListCallsCount > 0
    }
    public var mnemonicFromListReceivedMnemonicPhrase: String?
    public var mnemonicFromListReceivedInvocations: [String] = []
    public var mnemonicFromListReturnValue: IRMnemonicProtocol!
    public var mnemonicFromListClosure: ((String) throws -> IRMnemonicProtocol)?

    public func mnemonic(fromList mnemonicPhrase: String) throws -> IRMnemonicProtocol {
        if let error = mnemonicFromListThrowableError {
            throw error
        }
        mnemonicFromListCallsCount += 1
        mnemonicFromListReceivedMnemonicPhrase = mnemonicPhrase
        mnemonicFromListReceivedInvocations.append(mnemonicPhrase)
        return try mnemonicFromListClosure.map({ try $0(mnemonicPhrase) }) ?? mnemonicFromListReturnValue
    }

    //MARK: - mnemonic

    public var mnemonicFromEntropyThrowableError: Error?
    public var mnemonicFromEntropyCallsCount = 0
    public var mnemonicFromEntropyCalled: Bool {
        return mnemonicFromEntropyCallsCount > 0
    }
    public var mnemonicFromEntropyReceivedEntropy: Data?
    public var mnemonicFromEntropyReceivedInvocations: [Data] = []
    public var mnemonicFromEntropyReturnValue: IRMnemonicProtocol!
    public var mnemonicFromEntropyClosure: ((Data) throws -> IRMnemonicProtocol)?

    public func mnemonic(fromEntropy entropy: Data) throws -> IRMnemonicProtocol {
        if let error = mnemonicFromEntropyThrowableError {
            throw error
        }
        mnemonicFromEntropyCallsCount += 1
        mnemonicFromEntropyReceivedEntropy = entropy
        mnemonicFromEntropyReceivedInvocations.append(entropy)
        return try mnemonicFromEntropyClosure.map({ try $0(entropy) }) ?? mnemonicFromEntropyReturnValue
    }

}
