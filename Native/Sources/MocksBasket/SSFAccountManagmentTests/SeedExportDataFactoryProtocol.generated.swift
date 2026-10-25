// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFAccountManagment
@testable import SSFModels
@testable import SSFUtils
@testable import RobinHood

public class SeedExportDataFactoryProtocolMock: SeedExportDataFactoryProtocol {
public init() {}

    //MARK: - createSeedExportData

    public var createSeedExportDataMetaIdAccountIdCryptoTypeChainThrowableError: Error?
    public var createSeedExportDataMetaIdAccountIdCryptoTypeChainCallsCount = 0
    public var createSeedExportDataMetaIdAccountIdCryptoTypeChainCalled: Bool {
        return createSeedExportDataMetaIdAccountIdCryptoTypeChainCallsCount > 0
    }
    public var createSeedExportDataMetaIdAccountIdCryptoTypeChainReceivedArguments: (metaId: MetaAccountId, accountId: AccountId?, cryptoType: CryptoType, chain: ChainModel)?
    public var createSeedExportDataMetaIdAccountIdCryptoTypeChainReceivedInvocations: [(metaId: MetaAccountId, accountId: AccountId?, cryptoType: CryptoType, chain: ChainModel)] = []
    public var createSeedExportDataMetaIdAccountIdCryptoTypeChainReturnValue: SeedExportData!
    public var createSeedExportDataMetaIdAccountIdCryptoTypeChainClosure: ((MetaAccountId, AccountId?, CryptoType, ChainModel) throws -> SeedExportData)?

    public func createSeedExportData(metaId: MetaAccountId, accountId: AccountId?, cryptoType: CryptoType, chain: ChainModel) throws -> SeedExportData {
        if let error = createSeedExportDataMetaIdAccountIdCryptoTypeChainThrowableError {
            throw error
        }
        createSeedExportDataMetaIdAccountIdCryptoTypeChainCallsCount += 1
        createSeedExportDataMetaIdAccountIdCryptoTypeChainReceivedArguments = (metaId: metaId, accountId: accountId, cryptoType: cryptoType, chain: chain)
        createSeedExportDataMetaIdAccountIdCryptoTypeChainReceivedInvocations.append((metaId: metaId, accountId: accountId, cryptoType: cryptoType, chain: chain))
        return try createSeedExportDataMetaIdAccountIdCryptoTypeChainClosure.map({ try $0(metaId, accountId, cryptoType, chain) }) ?? createSeedExportDataMetaIdAccountIdCryptoTypeChainReturnValue
    }

}
