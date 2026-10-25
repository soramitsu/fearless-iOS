// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFAccountManagment
@testable import SSFModels
@testable import SSFUtils
@testable import RobinHood

public class MetaAccountOperationFactoryProtocolMock: MetaAccountOperationFactoryProtocol {
public init() {}

    //MARK: - newMetaAccountOperation

    public var newMetaAccountOperationMnemonicRequestIsBackupedCallsCount = 0
    public var newMetaAccountOperationMnemonicRequestIsBackupedCalled: Bool {
        return newMetaAccountOperationMnemonicRequestIsBackupedCallsCount > 0
    }
    public var newMetaAccountOperationMnemonicRequestIsBackupedReceivedArguments: (mnemonicRequest: MetaAccountImportMnemonicRequest, isBackuped: Bool)?
    public var newMetaAccountOperationMnemonicRequestIsBackupedReceivedInvocations: [(mnemonicRequest: MetaAccountImportMnemonicRequest, isBackuped: Bool)] = []
    public var newMetaAccountOperationMnemonicRequestIsBackupedReturnValue: BaseOperation<MetaAccountModel>!
    public var newMetaAccountOperationMnemonicRequestIsBackupedClosure: ((MetaAccountImportMnemonicRequest, Bool) -> BaseOperation<MetaAccountModel>)?

    public func newMetaAccountOperation(mnemonicRequest: MetaAccountImportMnemonicRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel> {
        newMetaAccountOperationMnemonicRequestIsBackupedCallsCount += 1
        newMetaAccountOperationMnemonicRequestIsBackupedReceivedArguments = (mnemonicRequest: mnemonicRequest, isBackuped: isBackuped)
        newMetaAccountOperationMnemonicRequestIsBackupedReceivedInvocations.append((mnemonicRequest: mnemonicRequest, isBackuped: isBackuped))
        return newMetaAccountOperationMnemonicRequestIsBackupedClosure.map({ $0(mnemonicRequest, isBackuped) }) ?? newMetaAccountOperationMnemonicRequestIsBackupedReturnValue
    }

    //MARK: - newMetaAccountOperation

    public var newMetaAccountOperationSeedRequestIsBackupedCallsCount = 0
    public var newMetaAccountOperationSeedRequestIsBackupedCalled: Bool {
        return newMetaAccountOperationSeedRequestIsBackupedCallsCount > 0
    }
    public var newMetaAccountOperationSeedRequestIsBackupedReceivedArguments: (seedRequest: MetaAccountImportSeedRequest, isBackuped: Bool)?
    public var newMetaAccountOperationSeedRequestIsBackupedReceivedInvocations: [(seedRequest: MetaAccountImportSeedRequest, isBackuped: Bool)] = []
    public var newMetaAccountOperationSeedRequestIsBackupedReturnValue: BaseOperation<MetaAccountModel>!
    public var newMetaAccountOperationSeedRequestIsBackupedClosure: ((MetaAccountImportSeedRequest, Bool) -> BaseOperation<MetaAccountModel>)?

    public func newMetaAccountOperation(seedRequest: MetaAccountImportSeedRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel> {
        newMetaAccountOperationSeedRequestIsBackupedCallsCount += 1
        newMetaAccountOperationSeedRequestIsBackupedReceivedArguments = (seedRequest: seedRequest, isBackuped: isBackuped)
        newMetaAccountOperationSeedRequestIsBackupedReceivedInvocations.append((seedRequest: seedRequest, isBackuped: isBackuped))
        return newMetaAccountOperationSeedRequestIsBackupedClosure.map({ $0(seedRequest, isBackuped) }) ?? newMetaAccountOperationSeedRequestIsBackupedReturnValue
    }

    //MARK: - newMetaAccountOperation

    public var newMetaAccountOperationKeystoreRequestIsBackupedCallsCount = 0
    public var newMetaAccountOperationKeystoreRequestIsBackupedCalled: Bool {
        return newMetaAccountOperationKeystoreRequestIsBackupedCallsCount > 0
    }
    public var newMetaAccountOperationKeystoreRequestIsBackupedReceivedArguments: (keystoreRequest: MetaAccountImportKeystoreRequest, isBackuped: Bool)?
    public var newMetaAccountOperationKeystoreRequestIsBackupedReceivedInvocations: [(keystoreRequest: MetaAccountImportKeystoreRequest, isBackuped: Bool)] = []
    public var newMetaAccountOperationKeystoreRequestIsBackupedReturnValue: BaseOperation<MetaAccountModel>!
    public var newMetaAccountOperationKeystoreRequestIsBackupedClosure: ((MetaAccountImportKeystoreRequest, Bool) -> BaseOperation<MetaAccountModel>)?

    public func newMetaAccountOperation(keystoreRequest: MetaAccountImportKeystoreRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel> {
        newMetaAccountOperationKeystoreRequestIsBackupedCallsCount += 1
        newMetaAccountOperationKeystoreRequestIsBackupedReceivedArguments = (keystoreRequest: keystoreRequest, isBackuped: isBackuped)
        newMetaAccountOperationKeystoreRequestIsBackupedReceivedInvocations.append((keystoreRequest: keystoreRequest, isBackuped: isBackuped))
        return newMetaAccountOperationKeystoreRequestIsBackupedClosure.map({ $0(keystoreRequest, isBackuped) }) ?? newMetaAccountOperationKeystoreRequestIsBackupedReturnValue
    }

    //MARK: - importChainAccountOperation

    public var importChainAccountOperationMnemonicRequestCallsCount = 0
    public var importChainAccountOperationMnemonicRequestCalled: Bool {
        return importChainAccountOperationMnemonicRequestCallsCount > 0
    }
    public var importChainAccountOperationMnemonicRequestReceivedMnemonicRequest: ChainAccountImportMnemonicRequest?
    public var importChainAccountOperationMnemonicRequestReceivedInvocations: [ChainAccountImportMnemonicRequest] = []
    public var importChainAccountOperationMnemonicRequestReturnValue: BaseOperation<MetaAccountModel>!
    public var importChainAccountOperationMnemonicRequestClosure: ((ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel>)?

    public func importChainAccountOperation(mnemonicRequest: ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel> {
        importChainAccountOperationMnemonicRequestCallsCount += 1
        importChainAccountOperationMnemonicRequestReceivedMnemonicRequest = mnemonicRequest
        importChainAccountOperationMnemonicRequestReceivedInvocations.append(mnemonicRequest)
        return importChainAccountOperationMnemonicRequestClosure.map({ $0(mnemonicRequest) }) ?? importChainAccountOperationMnemonicRequestReturnValue
    }

    //MARK: - importChainAccountOperation

    public var importChainAccountOperationSeedRequestCallsCount = 0
    public var importChainAccountOperationSeedRequestCalled: Bool {
        return importChainAccountOperationSeedRequestCallsCount > 0
    }
    public var importChainAccountOperationSeedRequestReceivedSeedRequest: ChainAccountImportSeedRequest?
    public var importChainAccountOperationSeedRequestReceivedInvocations: [ChainAccountImportSeedRequest] = []
    public var importChainAccountOperationSeedRequestReturnValue: BaseOperation<MetaAccountModel>!
    public var importChainAccountOperationSeedRequestClosure: ((ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel>)?

    public func importChainAccountOperation(seedRequest: ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        importChainAccountOperationSeedRequestCallsCount += 1
        importChainAccountOperationSeedRequestReceivedSeedRequest = seedRequest
        importChainAccountOperationSeedRequestReceivedInvocations.append(seedRequest)
        return importChainAccountOperationSeedRequestClosure.map({ $0(seedRequest) }) ?? importChainAccountOperationSeedRequestReturnValue
    }

    //MARK: - importChainAccountOperation

    public var importChainAccountOperationKeystoreRequestCallsCount = 0
    public var importChainAccountOperationKeystoreRequestCalled: Bool {
        return importChainAccountOperationKeystoreRequestCallsCount > 0
    }
    public var importChainAccountOperationKeystoreRequestReceivedKeystoreRequest: ChainAccountImportKeystoreRequest?
    public var importChainAccountOperationKeystoreRequestReceivedInvocations: [ChainAccountImportKeystoreRequest] = []
    public var importChainAccountOperationKeystoreRequestReturnValue: BaseOperation<MetaAccountModel>!
    public var importChainAccountOperationKeystoreRequestClosure: ((ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel>)?

    public func importChainAccountOperation(keystoreRequest: ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        importChainAccountOperationKeystoreRequestCallsCount += 1
        importChainAccountOperationKeystoreRequestReceivedKeystoreRequest = keystoreRequest
        importChainAccountOperationKeystoreRequestReceivedInvocations.append(keystoreRequest)
        return importChainAccountOperationKeystoreRequestClosure.map({ $0(keystoreRequest) }) ?? importChainAccountOperationKeystoreRequestReturnValue
    }

}
