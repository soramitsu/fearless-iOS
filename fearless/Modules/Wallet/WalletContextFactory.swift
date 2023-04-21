import Foundation
import CommonWallet
import SoraKeystore
import RobinHood
import IrohaCrypto
import SoraFoundation
import SSFUtils

enum WalletContextFactoryError: Error {
    case missingAccount
}

protocol WalletContextFactoryProtocol {
    func createContext() throws -> CommonWalletContextProtocol
}

final class WalletContextFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }
}

extension WalletContextFactory: WalletContextFactoryProtocol {
    func createContext() throws -> CommonWalletContextProtocol {
        guard let selectedAccount = SelectedWalletSettings.shared.value else {
            throw WalletContextFactoryError.missingAccount
        }

        logger.info("Start wallet for: \(selectedAccount.metaId)")

        return try createDummyContext(for: selectedAccount)
    }

    private func createDummyContext(for account: MetaAccountModel) throws -> CommonWalletContextProtocol {
        let accountSettings = WalletAccountSettings(
            accountId: account.metaId,
            assets: []
        )

        let context = try CommonWalletBuilder.builder(
            with: accountSettings,
            networkOperationFactory: DummyWalletNetworkOperationFactory()
        ).build()

        return context
    }
}

final class DummyWalletNetworkOperationFactory: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func fetchTransactionHistoryOperation(
        _: WalletHistoryRequest,
        pagination _: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func transferMetadataOperation(_: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func transferOperation(_: TransferInfo) -> CompoundOperationWrapper<Data> {
        CompoundOperationWrapper.createWithResult(Data(repeating: 0, count: 32))
    }

    func searchOperation(_: String) -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func withdrawalMetadataOperation(_: WithdrawMetadataInfo) -> CompoundOperationWrapper<WithdrawMetaData?> {
        CompoundOperationWrapper.createWithResult(nil)
    }

    func withdrawOperation(_: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        CompoundOperationWrapper.createWithResult(Data(repeating: 0, count: 32))
    }
}
