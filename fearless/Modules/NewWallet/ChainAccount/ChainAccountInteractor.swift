import UIKit
import RobinHood
import BigInt

final class ChainAccountInteractor {
    weak var presenter: ChainAccountInteractorOutputProtocol?
    private let selectedMetaAccount: MetaAccountModel
    private let chain: ChainModel
    private let asset: AssetModel
    private let operationQueue: OperationQueue
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    init(
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chain = chain
        self.asset = asset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
    }

    private func subscribeToAccountInfo() {
        if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
            _ = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
        } else {
            presenter?.didReceiveAccountInfo(
                result: .failure(ChainAccountFetchingError.accountNotExists),
                for: chain.chainId
            )
        }
    }
}

extension ChainAccountInteractor: ChainAccountInteractorInputProtocol {
    func setup() {
        subscribeToAccountInfo()
        fetchMinimalBalance()

        if let priceId = asset.priceId {
            _ = subscribeToPrice(for: priceId)
        }
    }
}

extension ChainAccountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result, for: priceId)
    }
}

extension ChainAccountInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainId)
    }
}

extension ChainAccountInteractor: RuntimeConstantFetching {
    func fetchMinimalBalance() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }
    }
}
