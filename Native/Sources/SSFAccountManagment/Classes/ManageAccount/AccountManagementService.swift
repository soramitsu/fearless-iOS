import Foundation
import RobinHood
import SSFModels
import SSFUtils

public enum AccountManagerServiceError: Error {
    case unexpected
    case logoutNotCompleted
}

// sourcery: AutoMockable
public protocol AccountManageble {
    func getCurrentAccount() -> MetaAccountModel?
    func setCurrentAccount(
        account: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    )
    func update(visible: Bool, for chainAsset: ChainAsset, completion: @escaping () -> Void) throws
    func logout() async throws
}

public final class AccountManagementService {
    private let operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    private let selectedWallet: PersistentValueSettings<MetaAccountModel>
    private let accountManagementWorker: AccountManagementWorkerProtocol

    public init(
        accountManagementWorker: AccountManagementWorkerProtocol,
        selectedWallet: PersistentValueSettings<MetaAccountModel>
    ) {
        self.selectedWallet = selectedWallet
        self.selectedWallet.setup()
        self.accountManagementWorker = accountManagementWorker
    }
}

extension AccountManagementService: AccountManageble {
    public func getCurrentAccount() -> MetaAccountModel? {
        selectedWallet.value
    }

    public func setCurrentAccount(
        account: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        selectedWallet.performSave(value: account, completionClosure: completionClosure)
    }

    public func update(
        visible: Bool,
        for chainAsset: ChainAsset,
        completion: @escaping () -> Void
    ) throws {
        let accountRequest = chainAsset.chain.accountRequest()

        guard let wallet = selectedWallet.value,
              let accountId = wallet.fetch(for: accountRequest)?.accountId else
        {
            throw AccountManagerServiceError.unexpected
        }

        let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)

        var assetsVisibility = wallet.assetsVisibility.filter { $0.assetId != chainAssetKey }

        let assetVisibility = AssetVisibility(assetId: chainAssetKey, hidden: !visible)
        assetsVisibility.append(assetVisibility)

        let updatedAccount = wallet.replacingAssetsVisibility(assetsVisibility)
        let managedAccount = ManagedMetaAccountModel(info: updatedAccount)

        accountManagementWorker.save(account: managedAccount, completion: completion)
    }

    public func logout() async throws {
        await accountManagementWorker.deleteAll(completion: {})
    }
}
