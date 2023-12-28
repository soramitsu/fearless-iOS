import UIKit
import SSFUtils
import RobinHood
import SoraKeystore
import SSFModels

final class PolkaswapAdjustmentInteractor: RuntimeConstantFetching {
    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    // MARK: - Private properties

    private weak var output: PolkaswapAdjustmentInteractorOutput?
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let operationFactory: PolkaswapOperationFactoryProtocol
    private let subscriptionService: PolkaswapRemoteSubscriptionServiceProtocol
    private let settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>
    private let operationManager: OperationManagerProtocol
    private let xorChainAsset: ChainAsset
    private let extrinsicService: ExtrinsicServiceProtocol
    private let userDefaultsStorage: SettingsManagerProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var dexIds: [UInt32] = []
    private var swapValues: [SwapValues] = []
    private var swapValueErrors: [Error] = []
    private var listeningSubscription: [String] = []
    private var dexInfos: [PolkaswapDexInfo] = []

    init(
        xorChainAsset: ChainAsset,
        subscriptionService: PolkaswapRemoteSubscriptionServiceProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>,
        extrinsicService: ExtrinsicServiceProtocol,
        operationFactory: PolkaswapOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.xorChainAsset = xorChainAsset
        self.subscriptionService = subscriptionService
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.feeProxy = feeProxy
        self.settingsRepository = settingsRepository
        self.extrinsicService = extrinsicService
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.userDefaultsStorage = userDefaultsStorage
        self.callFactory = callFactory
    }

    // MARK: - Private methods

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func subscribeToPrices(for chainAssets: [ChainAsset]) {
        guard chainAssets.isNotEmpty else {
            output?.didReceivePricesData(result: .success([]))
            return
        }
        pricesProvider = subscribeToPrices(for: chainAssets)
    }

    private func fetchIsPairAvailableAndMarkets(
        for dexIds: [UInt32],
        _ fromAssetId: String,
        _ toAssetId: String
    ) {
        let group = DispatchGroup()
        var allOperations: [Operation] = []

        dexIds.forEach { dexId in
            group.enter()
            let operation = operationFactory
                .createIsPathAvalableAndMarketCompoundOperation(
                    dexId: dexId,
                    from: fromAssetId,
                    to: toAssetId
                )

            operation.targetOperation.completionBlock = { [weak self, dexId, group] in
                guard let result = operation.targetOperation.result else {
                    return
                }

                switch result {
                case let .success((isAvalable, markets)):
                    let info = PolkaswapDexInfo(
                        dexId: dexId,
                        pathIsAvailable: isAvalable,
                        markets: markets
                    )
                    self?.dexInfos.append(info)
                case let .failure(error):
                    self?.output?.didReceive(error: error)
                }
                group.leave()
            }

            allOperations += operation.allOperations
        }

        operationManager.enqueue(
            operations: allOperations,
            in: .blockAfter
        )

        let workItem = DispatchWorkItem {
            self.output?.didReceiveDex(infos: self.dexInfos, fromAssetId: fromAssetId, toAssetId: toAssetId)
        }
        group.notify(queue: .global(), work: workItem)
    }

    private func unsubscribePool() {
        subscriptionService.unsubscribe()
    }

    private func fetchPolkaswapSettings() {
        let operation = settingsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            do {
                guard let settings = try operation.extractNoCancellableResultData().first else {
                    return
                }
                self?.output?.didReceiveSettings(settings: settings)
                self?.dexIds = settings.availableDexIds.map { $0.code }
            } catch {
                self?.output?.didReceive(error: error)
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}

// MARK: - PolkaswapAdjustmentInteractorInput

extension PolkaswapAdjustmentInteractor: PolkaswapAdjustmentInteractorInput {
    func setup(with output: PolkaswapAdjustmentInteractorOutput) {
        self.output = output
        feeProxy.delegate = self
        fetchPolkaswapSettings()
        fetchDisclaimerVisible()
    }

    func didReceive(_ fromChainAsset: ChainAsset?, _ toChainAsset: ChainAsset?) {
        let chainAssets = [xorChainAsset, fromChainAsset, toChainAsset].compactMap { $0 }
        subscribeToPrices(for: chainAssets)
        subscribeToAccountInfo(for: chainAssets)

        guard let fromAssetId = fromChainAsset?.asset.currencyId,
              let toAssetId = toChainAsset?.asset.currencyId
        else {
            return
        }
        fetchIsPairAvailableAndMarkets(
            for: dexIds,
            fromAssetId,
            toAssetId
        )
    }

    func fetchQuotes(with params: PolkaswapQuoteParams) {
        swapValues.removeAll()
        swapValueErrors.removeAll()
        dexInfos.removeAll()
        var allOperations: [Operation] = []
        let group = DispatchGroup()

        dexIds.forEach { dexId in
            group.enter()
            let quotesOperation = operationFactory
                .createPolkaswapQuoteOperation(dexId: dexId, params: params)

            quotesOperation.completionBlock = { [weak self, dexId, group] in
                guard let strongSelf = self else { return }
                DispatchQueue.global().sync(flags: .barrier) {
                    do {
                        var result = try quotesOperation.extractNoCancellableResultData()
                        result.dexId = dexId
                        strongSelf.swapValues.append(result)
                    } catch {
                        strongSelf.swapValueErrors.append(error)
                    }
                    group.leave()
                }
            }
            allOperations.append(quotesOperation)
        }
        operationManager.enqueue(operations: allOperations, in: .blockAfter)

        let workItem = DispatchWorkItem(flags: .barrier) {
            self.output?.didReceiveSwapValues(
                self.swapValues,
                params: params,
                errors: self.swapValueErrors
            )
        }
        group.notify(queue: .main, work: workItem)
    }

    func subscribeOnBlocks() {
        listeningSubscription.removeAll()
        unsubscribePool()

        subscriptionService.subscribeToBlocks { [weak self] update in
            guard let strongSelf = self else {
                return
            }
            let subscription = update.params.subscription
            if strongSelf.listeningSubscription.contains(subscription) {
                strongSelf.output?.updateQuotes()
            }
            strongSelf.listeningSubscription.append(subscription)
        }
    }

    func estimateFee(
        dexId: String,
        fromAssetId: String,
        toAssetId: String,
        swapVariant: SwapVariant,
        swapAmount: SwapAmount,
        filter: PolkaswapLiquidityFilterMode,
        liquiditySourceType: LiquiditySourceType
    ) {
        let amountCall = [swapVariant: swapAmount]
        let swap = callFactory.swap(
            dexId: dexId,
            from: fromAssetId,
            to: toAssetId,
            amountCall: amountCall,
            type: liquiditySourceType.code,
            filter: liquiditySourceType.filterMode.rawValue
        )

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: swap)
        }

        let reuseIdentifier = [
            dexId,
            fromAssetId,
            toAssetId,
            swapVariant.rawValue,
            "\(filter.rawValue)",
            liquiditySourceType.rawValue
        ].joined()

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure
        )
    }

    func fetchDisclaimerVisible() {
        let isRead = userDefaultsStorage.bool(
            for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead2.rawValue
        ) ?? false
        output?.didReceiveDisclaimer(isRead: isRead)
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension PolkaswapAdjustmentInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

// MARK: - PriceLocalStorageSubscriber

extension PolkaswapAdjustmentInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        output?.didReceivePricesData(result: result)
    }
}

// MARK: - ExtrinsicFeeProxyDelegate

extension PolkaswapAdjustmentInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
