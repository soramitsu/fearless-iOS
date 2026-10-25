// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import IrohaCrypto
@testable import SSFKeyPair
@testable import SSFModels
@testable import SSFCrypto

public class CommonCryptoMock: CommonCrypto {
public init() {}

    //MARK: - getQuery

    public var getQuerySeedDerivationPathCryptoTypeEthereumBasedThrowableError: Error?
    public var getQuerySeedDerivationPathCryptoTypeEthereumBasedCallsCount = 0
    public var getQuerySeedDerivationPathCryptoTypeEthereumBasedCalled: Bool {
        return getQuerySeedDerivationPathCryptoTypeEthereumBasedCallsCount > 0
    }
    public var getQuerySeedDerivationPathCryptoTypeEthereumBasedReceivedArguments: (seed: Data, derivationPath: String, cryptoType: CryptoType, ethereumBased: Bool)?
    public var getQuerySeedDerivationPathCryptoTypeEthereumBasedReceivedInvocations: [(seed: Data, derivationPath: String, cryptoType: CryptoType, ethereumBased: Bool)] = []
    public var getQuerySeedDerivationPathCryptoTypeEthereumBasedReturnValue: AccountQuery!
    public var getQuerySeedDerivationPathCryptoTypeEthereumBasedClosure: ((Data, String, CryptoType, Bool) throws -> AccountQuery)?

    public func getQuery(seed: Data, derivationPath: String, cryptoType: CryptoType, ethereumBased: Bool) throws -> AccountQuery {
        if let error = getQuerySeedDerivationPathCryptoTypeEthereumBasedThrowableError {
            throw error
        }
        getQuerySeedDerivationPathCryptoTypeEthereumBasedCallsCount += 1
        getQuerySeedDerivationPathCryptoTypeEthereumBasedReceivedArguments = (seed: seed, derivationPath: derivationPath, cryptoType: cryptoType, ethereumBased: ethereumBased)
        getQuerySeedDerivationPathCryptoTypeEthereumBasedReceivedInvocations.append((seed: seed, derivationPath: derivationPath, cryptoType: cryptoType, ethereumBased: ethereumBased))
        return try getQuerySeedDerivationPathCryptoTypeEthereumBasedClosure.map({ try $0(seed, derivationPath, cryptoType, ethereumBased) }) ?? getQuerySeedDerivationPathCryptoTypeEthereumBasedReturnValue
    }

    //MARK: - getJunctionResult

    public var getJunctionResultFromEthereumBasedThrowableError: Error?
    public var getJunctionResultFromEthereumBasedCallsCount = 0
    public var getJunctionResultFromEthereumBasedCalled: Bool {
        return getJunctionResultFromEthereumBasedCallsCount > 0
    }
    public var getJunctionResultFromEthereumBasedReceivedArguments: (derivationPath: String, ethereumBased: Bool)?
    public var getJunctionResultFromEthereumBasedReceivedInvocations: [(derivationPath: String, ethereumBased: Bool)] = []
    public var getJunctionResultFromEthereumBasedReturnValue: JunctionResult?
    public var getJunctionResultFromEthereumBasedClosure: ((String, Bool) throws -> JunctionResult?)?

    public func getJunctionResult(from derivationPath: String, ethereumBased: Bool) throws -> JunctionResult? {
        if let error = getJunctionResultFromEthereumBasedThrowableError {
            throw error
        }
        getJunctionResultFromEthereumBasedCallsCount += 1
        getJunctionResultFromEthereumBasedReceivedArguments = (derivationPath: derivationPath, ethereumBased: ethereumBased)
        getJunctionResultFromEthereumBasedReceivedInvocations.append((derivationPath: derivationPath, ethereumBased: ethereumBased))
        return try getJunctionResultFromEthereumBasedClosure.map({ try $0(derivationPath, ethereumBased) }) ?? getJunctionResultFromEthereumBasedReturnValue
    }

    //MARK: - generateKeypair

    public var generateKeypairFromChaincodesCryptoTypeIsEthereumThrowableError: Error?
    public var generateKeypairFromChaincodesCryptoTypeIsEthereumCallsCount = 0
    public var generateKeypairFromChaincodesCryptoTypeIsEthereumCalled: Bool {
        return generateKeypairFromChaincodesCryptoTypeIsEthereumCallsCount > 0
    }
    public var generateKeypairFromChaincodesCryptoTypeIsEthereumReceivedArguments: (seed: Data, chaincodes: [Chaincode], cryptoType: CryptoType, isEthereum: Bool)?
    public var generateKeypairFromChaincodesCryptoTypeIsEthereumReceivedInvocations: [(seed: Data, chaincodes: [Chaincode], cryptoType: CryptoType, isEthereum: Bool)] = []
    public var generateKeypairFromChaincodesCryptoTypeIsEthereumReturnValue: (publicKey: Data, secretKey: Data)!
    public var generateKeypairFromChaincodesCryptoTypeIsEthereumClosure: ((Data, [Chaincode], CryptoType, Bool) throws -> (publicKey: Data, secretKey: Data))?

    public func generateKeypair(from seed: Data, chaincodes: [Chaincode], cryptoType: CryptoType, isEthereum: Bool) throws -> (publicKey: Data, secretKey: Data) {
        if let error = generateKeypairFromChaincodesCryptoTypeIsEthereumThrowableError {
            throw error
        }
        generateKeypairFromChaincodesCryptoTypeIsEthereumCallsCount += 1
        generateKeypairFromChaincodesCryptoTypeIsEthereumReceivedArguments = (seed: seed, chaincodes: chaincodes, cryptoType: cryptoType, isEthereum: isEthereum)
        generateKeypairFromChaincodesCryptoTypeIsEthereumReceivedInvocations.append((seed: seed, chaincodes: chaincodes, cryptoType: cryptoType, isEthereum: isEthereum))
        return try generateKeypairFromChaincodesCryptoTypeIsEthereumClosure.map({ try $0(seed, chaincodes, cryptoType, isEthereum) }) ?? generateKeypairFromChaincodesCryptoTypeIsEthereumReturnValue
    }

    //MARK: - createKeypairFactory

    public var createKeypairFactoryIsEthereumBasedCallsCount = 0
    public var createKeypairFactoryIsEthereumBasedCalled: Bool {
        return createKeypairFactoryIsEthereumBasedCallsCount > 0
    }
    public var createKeypairFactoryIsEthereumBasedReceivedArguments: (cryptoType: CryptoType, isEthereumBased: Bool)?
    public var createKeypairFactoryIsEthereumBasedReceivedInvocations: [(cryptoType: CryptoType, isEthereumBased: Bool)] = []
    public var createKeypairFactoryIsEthereumBasedReturnValue: KeypairFactoryProtocol!
    public var createKeypairFactoryIsEthereumBasedClosure: ((CryptoType, Bool) -> KeypairFactoryProtocol)?

    public func createKeypairFactory(_ cryptoType: CryptoType, isEthereumBased: Bool) -> KeypairFactoryProtocol {
        createKeypairFactoryIsEthereumBasedCallsCount += 1
        createKeypairFactoryIsEthereumBasedReceivedArguments = (cryptoType: cryptoType, isEthereumBased: isEthereumBased)
        createKeypairFactoryIsEthereumBasedReceivedInvocations.append((cryptoType: cryptoType, isEthereumBased: isEthereumBased))
        return createKeypairFactoryIsEthereumBasedClosure.map({ $0(cryptoType, isEthereumBased) }) ?? createKeypairFactoryIsEthereumBasedReturnValue
    }

}
