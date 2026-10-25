// Generated using Sourcery 2.1.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable all

import UIKit
@testable import SSFAccountManagment
@testable import SSFModels
@testable import SSFUtils
@testable import RobinHood

public class MnemonicExportServiceProtocolMock: MnemonicExportServiceProtocol {
public init() {}

    //MARK: - fetchExportDataFor

    public var fetchExportDataForWalletAccountsCallsCount = 0
    public var fetchExportDataForWalletAccountsCalled: Bool {
        return fetchExportDataForWalletAccountsCallsCount > 0
    }
    public var fetchExportDataForWalletAccountsReceivedArguments: (wallet: MetaAccountModel, accounts: [ChainAccountInfo])?
    public var fetchExportDataForWalletAccountsReceivedInvocations: [(wallet: MetaAccountModel, accounts: [ChainAccountInfo])] = []
    public var fetchExportDataForWalletAccountsReturnValue: [MnemonicExportData]!
    public var fetchExportDataForWalletAccountsClosure: ((MetaAccountModel, [ChainAccountInfo]) -> [MnemonicExportData])?

    public func fetchExportDataFor(wallet: MetaAccountModel, accounts: [ChainAccountInfo]) -> [MnemonicExportData] {
        fetchExportDataForWalletAccountsCallsCount += 1
        fetchExportDataForWalletAccountsReceivedArguments = (wallet: wallet, accounts: accounts)
        fetchExportDataForWalletAccountsReceivedInvocations.append((wallet: wallet, accounts: accounts))
        return fetchExportDataForWalletAccountsClosure.map({ $0(wallet, accounts) }) ?? fetchExportDataForWalletAccountsReturnValue
    }

    //MARK: - fetchExportDataFor

    public var fetchExportDataForAddressChainWalletThrowableError: Error?
    public var fetchExportDataForAddressChainWalletCallsCount = 0
    public var fetchExportDataForAddressChainWalletCalled: Bool {
        return fetchExportDataForAddressChainWalletCallsCount > 0
    }
    public var fetchExportDataForAddressChainWalletReceivedArguments: (address: String, chain: ChainModel, wallet: MetaAccountModel)?
    public var fetchExportDataForAddressChainWalletReceivedInvocations: [(address: String, chain: ChainModel, wallet: MetaAccountModel)] = []
    public var fetchExportDataForAddressChainWalletReturnValue: MnemonicExportData!
    public var fetchExportDataForAddressChainWalletClosure: ((String, ChainModel, MetaAccountModel) throws -> MnemonicExportData)?

    public func fetchExportDataFor(address: String, chain: ChainModel, wallet: MetaAccountModel) throws -> MnemonicExportData {
        if let error = fetchExportDataForAddressChainWalletThrowableError {
            throw error
        }
        fetchExportDataForAddressChainWalletCallsCount += 1
        fetchExportDataForAddressChainWalletReceivedArguments = (address: address, chain: chain, wallet: wallet)
        fetchExportDataForAddressChainWalletReceivedInvocations.append((address: address, chain: chain, wallet: wallet))
        return try fetchExportDataForAddressChainWalletClosure.map({ try $0(address, chain, wallet) }) ?? fetchExportDataForAddressChainWalletReturnValue
    }

}
