import UIKit
import SSFXCM
import RobinHood
import BigInt
import SSFExtrinsicKit

protocol CrossChainInteractorOutput: AnyObject {
    func didReceiveAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    )
    func didReceivePricesData(
        result: Result<[PriceData], Error>
    )
    func didReceiveAvailableDestChainAssets(_ chainAssets: [ChainAsset])
    func didReceiveDestinationFee(result: Result<XcmFee, Error>)
    func didReceiveOriginFee(result: SSFExtrinsicKit.FeeExtrinsicResult)
}

final class CrossChainInteractor {
    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private weak var output: CrossChainInteractorOutput?

    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let depsContainer: CrossChainDepsContainer
    private let runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let wallet: MetaAccountModel

    private var runtimeItems: [RuntimeMetadataItem] = []

    var xcmServices: XcmExtrinsicServices?

    init(
        chainAssetFetching: ChainAssetFetchingProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        depsContainer: CrossChainDepsContainer,
        runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        wallet: MetaAccountModel
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.depsContainer = depsContainer
        self.runtimeItemRepository = runtimeItemRepository
        self.operationQueue = operationQueue
        self.logger = logger
        self.wallet = wallet
    }

    // MARK: - Private methods

    private func fetchRuntimeItems() {
        let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())

        runtimeItemsOperation.completionBlock = { [weak self] in
            do {
                let items = try runtimeItemsOperation.extractNoCancellableResultData()
                self?.runtimeItems = items
            } catch {
                self?.logger.error(error.localizedDescription)
            }
        }

        operationQueue.addOperation(runtimeItemsOperation)
    }

    private func prepareDeps(
        originalChainAsset: ChainAsset
    ) -> CrossChainDepsContainer.CrossChainConfirmationDeps? {
        do {
            guard let originalRuntimeMetadataItem = runtimeItems.first(where: { $0.chain == originalChainAsset.chain.chainId }) else {
                throw ConvenienceError(error: "missing runtime item")
            }

            return try depsContainer.prepareDepsFor(
                originalChainAsset: originalChainAsset,
                originalRuntimeMetadataItem: nil
            )
        } catch {
            return nil
        }
    }

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func fetchPrices(for chainAssets: [ChainAsset]) {
        let pricesIds = chainAssets.compactMap(\.asset.priceId).uniq(predicate: { $0 })
        guard pricesIds.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    private func getAvailableDestChainAssets(for _: ChainAsset) {
        chainAssetFetching.fetch(
            filters: [ /* .assetName(chainAsset.asset.name) */ ],
            sortDescriptors: []
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .success(availableChainAssets):
                    self?.output?.didReceiveAvailableDestChainAssets(availableChainAssets)
                default:
                    self?.output?.didReceiveAvailableDestChainAssets([])
                }
            }
        }

//        Task {
//            let chainsFetcher = depsContainer.createRemoteChainsFetcher()
//            let availableDestChains = await chainsFetcher.getAvailableDestinationChains(
//                originalChain: chainAsset.chain,
//                assetSymbol: nil
//            )
//        }
    }
}

// MARK: - CrossChainInteractorInput

extension CrossChainInteractor: CrossChainInteractorInput {
    func estimateFee(originalChainAsset: ChainAsset, destinationChainAsset: ChainAsset, amount: Decimal?) {
        let inputAmount = amount ?? .zero
        let substrateAmout = inputAmount.toSubstrateAmount(precision: Int16(originalChainAsset.asset.precision)) ?? BigUInt.zero

        let deps = prepareDeps(originalChainAsset: originalChainAsset)
        xcmServices = deps?.xcmServices

        guard let destAccountId = wallet.fetch(for: destinationChainAsset.chain.accountRequest())?.accountId else {
            return
        }
        Task {
            guard let originalFee = await deps?.xcmServices.extrinsic.estimateOriginalFee(
                fromChainId: originalChainAsset.chain.chainId,
                assetSymbol: originalChainAsset.asset.name,
                destChainId: destinationChainAsset.chain.chainId,
                destAccountId: destAccountId,
                amount: substrateAmout
            ) else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceiveOriginFee(result: originalFee)
            }

            guard let destinationFee = await deps?
                .xcmServices
                .destinationFeeFetcher
                .estimateFee(
                    originChainId: originalChainAsset.chain.chainId,
                    destinationChainId: destinationChainAsset.chain.chainId
                )
            else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceiveDestinationFee(result: destinationFee)
            }
        }
    }

    func setup(with output: CrossChainInteractorOutput) {
        self.output = output
        fetchRuntimeItems()
    }

    func didReceive(originalChainAsset: ChainAsset?, destChainAsset: ChainAsset?) {
        let chainAssets: [ChainAsset] = [originalChainAsset, destChainAsset].compactMap { $0 }
        fetchPrices(for: chainAssets)
        subscribeToAccountInfo(for: chainAssets)
        guard let originalChainAsset = originalChainAsset else {
            return
        }
        getAvailableDestChainAssets(for: originalChainAsset)
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension CrossChainInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(
            result: result,
            accountId: accountId,
            chainAsset: chainAsset
        )
    }
}

// MARK: - PriceLocalStorageSubscriber

extension CrossChainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}
