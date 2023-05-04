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
    func didReceiveOrigin(chainAssets: [ChainAsset])
    func didSetup()
    func didReceiveExistentialDeposit(result: Result<BigUInt, Error>)
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
    private let addressChainDefiner: AddressChainDefiner
    private let existentialDepositService: ExistentialDepositServiceProtocol

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
        wallet: MetaAccountModel,
        addressChainDefiner: AddressChainDefiner,
        existentialDepositService: ExistentialDepositServiceProtocol
    ) {
        self.chainAssetFetching = chainAssetFetching
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.depsContainer = depsContainer
        self.runtimeItemRepository = runtimeItemRepository
        self.operationQueue = operationQueue
        self.logger = logger
        self.wallet = wallet
        self.addressChainDefiner = addressChainDefiner
        self.existentialDepositService = existentialDepositService
    }

    // MARK: - Private methods

    private func fetchRuntimeItems() {
        let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())

        runtimeItemsOperation.completionBlock = { [weak self] in
            do {
                let items = try runtimeItemsOperation.extractNoCancellableResultData()
                self?.runtimeItems = items
                self?.output?.didSetup()
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
                originalRuntimeMetadataItem: originalRuntimeMetadataItem
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

    private func getAvailableDestChainAssets(for chainAsset: ChainAsset, destChainModel: ChainModel?) {
        Task {
            do {
                let deps = prepareDeps(originalChainAsset: chainAsset)
                let availableChainIds = try await deps?.xcmServices
                    .availableDestionationFetching
                    .getAvailableDestinationChains(
                        originalChainId: chainAsset.chain.chainId,
                        assetSymbol: chainAsset.asset.symbol
                    ) ?? []

                let availableOriginAsset = try await deps?.xcmServices
                    .availableDestionationFetching
                    .getAvailableAssets(
                        originalChainId: chainAsset.chain.chainId,
                        destinationChainId: destChainModel?.chainId
                    )

                let availableChainAssets = chainAsset.chain
                    .chainAssets
                    .filter { chainAsset in
                        availableOriginAsset?.contains(chainAsset.asset.name) == true
                    }

                chainAssetFetching.fetch(
                    filters: [.chainIds(availableChainIds)],
                    sortDescriptors: []
                ) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case let .success(availableChainAssets):
                            self.output?.didReceiveAvailableDestChainAssets(availableChainAssets)
                        default:
                            self.output?.didReceiveAvailableDestChainAssets([])
                        }
                        self.output?.didReceiveOrigin(chainAssets: availableChainAssets)
                    }
                }
            } catch {
                logger.customError(error)
            }
        }
    }

    private func getExistentialDeposit(for chainAsset: ChainAsset) {
        existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            self?.output?.didReceiveExistentialDeposit(result: result)
        }
    }
}

// MARK: - CrossChainInteractorInput

extension CrossChainInteractor: CrossChainInteractorInput {
    func estimateFee(originChainAsset: ChainAsset, destinationChainModel: ChainModel, amount: Decimal?) {
        let inputAmount = amount ?? 1
        let substrateAmout = inputAmount.toSubstrateAmount(precision: Int16(originChainAsset.asset.precision)) ?? BigUInt.zero

        let deps = prepareDeps(originalChainAsset: originChainAsset)
        xcmServices = deps?.xcmServices

        guard let destAccountId = wallet.fetch(for: destinationChainModel.accountRequest())?.accountId else {
            return
        }
        Task {
            guard let originalFee = await deps?.xcmServices.extrinsic.estimateOriginalFee(
                fromChainId: originChainAsset.chain.chainId,
                assetSymbol: originChainAsset.asset.name,
                destChainId: destinationChainModel.chainId,
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
                    originChainId: originChainAsset.chain.chainId,
                    destinationChainId: destinationChainModel.chainId
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

    func didReceive(originChainAsset: ChainAsset?, destChainModel: ChainModel?) {
        let originalUtilityChainAsset = originChainAsset?.chain.utilityChainAssets().first
        let chainAssets: [ChainAsset] = [originalUtilityChainAsset, originChainAsset].compactMap { $0 }
        fetchPrices(for: chainAssets)
        subscribeToAccountInfo(for: chainAssets)
        guard let originChainAsset = originChainAsset else {
            return
        }
        getAvailableDestChainAssets(for: originChainAsset, destChainModel: destChainModel)
        getExistentialDeposit(for: originChainAsset)
    }

    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        addressChainDefiner.validate(address: address, for: chain)
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
