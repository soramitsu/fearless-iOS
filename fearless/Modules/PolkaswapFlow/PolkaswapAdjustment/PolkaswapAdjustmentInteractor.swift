import UIKit
import SSFUtils
import RobinHood
import SoraKeystore
import SSFModels

final class PolkaswapOperationBatch<Value> {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var values: [Value] = []
    private var errors: [Error] = []

    init(expectedCount: Int) {
        precondition(expectedCount >= 0)
        (0 ..< expectedCount).forEach { _ in group.enter() }
    }

    func complete(_ result: Result<Value, Error>?) {
        defer { group.leave() }
        let resolvedResult = result ?? .failure(BaseOperationError.parentOperationCancelled)

        lock.lock()
        defer { lock.unlock() }

        switch resolvedResult {
        case let .success(value):
            values.append(value)
        case let .failure(error):
            errors.append(error)
        }
    }

    func notify(
        on queue: DispatchQueue,
        completion: @escaping ([Value], [Error]) -> Void
    ) {
        group.notify(queue: queue) { [self] in
            lock.lock()
            let valuesSnapshot = values
            let errorsSnapshot = errors
            lock.unlock()

            completion(valuesSnapshot, errorsSnapshot)
        }
    }
}

final class PolkaswapAdjustmentInteractor: RuntimeConstantFetching {
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
    private let eventCenter: EventCenterProtocol
    private let fallbackSettings: PolkaswapRemoteSettings?

    private var dexIds: [UInt32] = []
    private var listeningSubscription: [String] = []

    init(
        xorChainAsset: ChainAsset,
        subscriptionService: PolkaswapRemoteSubscriptionServiceProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        settingsRepository: AnyDataProviderRepository<PolkaswapRemoteSettings>,
        extrinsicService: ExtrinsicServiceProtocol,
        operationFactory: PolkaswapOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        fallbackSettings: PolkaswapRemoteSettings? = PolkaswapSettingsFactory.bundledSettings()
    ) {
        self.xorChainAsset = xorChainAsset
        self.subscriptionService = subscriptionService
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.feeProxy = feeProxy
        self.settingsRepository = settingsRepository
        self.extrinsicService = extrinsicService
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.userDefaultsStorage = userDefaultsStorage
        self.callFactory = callFactory
        self.eventCenter = eventCenter
        self.fallbackSettings = fallbackSettings
    }

    deinit {
        eventCenter.remove(observer: self)
    }

    // MARK: - Private methods

    private func subscribeToAccountInfo(for chainAssets: [ChainAsset]) {
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func fetchIsPairAvailableAndMarkets(
        for dexIds: [UInt32],
        _ fromAssetId: String,
        _ toAssetId: String
    ) {
        let batch = PolkaswapOperationBatch<PolkaswapDexInfo>(expectedCount: dexIds.count)
        var allOperations: [Operation] = []

        dexIds.forEach { dexId in
            let operation = operationFactory
                .createIsPathAvalableAndMarketCompoundOperation(
                    dexId: dexId,
                    from: fromAssetId,
                    to: toAssetId
                )

            operation.targetOperation.completionBlock = { [dexId] in
                guard let result = operation.targetOperation.result else {
                    batch.complete(nil)
                    return
                }

                switch result {
                case let .success((isAvalable, markets)):
                    let info = PolkaswapDexInfo(
                        dexId: dexId,
                        pathIsAvailable: isAvalable,
                        markets: markets
                    )
                    batch.complete(.success(info))
                case let .failure(error):
                    batch.complete(.failure(error))
                }
            }

            allOperations += operation.allOperations
        }

        operationManager.enqueue(
            operations: allOperations,
            in: .transient
        )

        batch.notify(on: .main) { [weak self] infos, errors in
            errors.forEach { self?.output?.didReceive(error: $0) }
            self?.output?.didReceiveDex(
                infos: infos,
                fromAssetId: fromAssetId,
                toAssetId: toAssetId
            )
        }
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
                DispatchQueue.main.async {
                    self?.apply(settings: settings)
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, self.fallbackSettings == nil else {
                        return
                    }
                    self.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    private func apply(settings: PolkaswapRemoteSettings) {
        dexIds = settings.availableDexIds.map(\.code)
        output?.didReceiveSettings(settings: settings)
    }
}

// MARK: - PolkaswapAdjustmentInteractorInput

extension PolkaswapAdjustmentInteractor: PolkaswapAdjustmentInteractorInput {
    func setup(with output: PolkaswapAdjustmentInteractorOutput) {
        self.output = output
        feeProxy.delegate = self
        if let fallbackSettings {
            apply(settings: fallbackSettings)
        }
        eventCenter.add(observer: self, dispatchIn: .main)
        fetchPolkaswapSettings()
        fetchDisclaimerVisible()
    }

    func didReceive(_ fromChainAsset: ChainAsset?, _ toChainAsset: ChainAsset?) {
        let chainAssets = [xorChainAsset, fromChainAsset, toChainAsset].compactMap { $0 }
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
        var allOperations: [Operation] = []
        let batch = PolkaswapOperationBatch<SwapValues>(expectedCount: dexIds.count)

        dexIds.forEach { dexId in
            let quotesOperation = operationFactory
                .createPolkaswapQuoteOperation(dexId: dexId, params: params)

            quotesOperation.completionBlock = { [dexId] in
                do {
                    var result = try quotesOperation.extractNoCancellableResultData()
                    result.dexId = dexId
                    batch.complete(.success(result))
                } catch {
                    batch.complete(.failure(error))
                }
            }
            allOperations.append(quotesOperation)
        }
        operationManager.enqueue(operations: allOperations, in: .transient)

        batch.notify(on: .main) { [weak self] values, errors in
            self?.output?.didReceiveSwapValues(
                values,
                params: params,
                errors: errors
            )
        }
    }

    func subscribeOnBlocks() {
        listeningSubscription.removeAll()
        unsubscribePool()

        subscriptionService.subscribeToBlocks { [weak self] update in
            let subscription = update.params.subscription
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                if self.listeningSubscription.contains(subscription) {
                    self.output?.updateQuotes()
                }
                self.listeningSubscription.append(subscription)
            }
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
        output?.didReceiveDisclaimer(
            isRead: PolkaswapDisclaimerPolicy.isAccepted(in: userDefaultsStorage)
        )
    }
}

extension PolkaswapAdjustmentInteractor: EventVisitorProtocol {
    func processPolkaswapSettingsDidUpdate(event: PolkaswapSettingsDidUpdate) {
        apply(settings: event.settings)
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

// MARK: - ExtrinsicFeeProxyDelegate

extension PolkaswapAdjustmentInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
