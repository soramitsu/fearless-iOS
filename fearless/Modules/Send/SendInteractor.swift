import UIKit
import RobinHood
import Web3
import SSFModels
import Web3PromiseKit

final class SendInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: SendInteractorOutput?

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let scamServiceOperationFactory: ScamServiceOperationFactoryProtocol
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let addressChainDefiner: AddressChainDefiner
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    private let runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>
    private let operationQueue: OperationQueue

    let dependencyContainer: SendDepencyContainer

    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var utilityPriceProvider: AnySingleValueProvider<[PriceData]>?

    private var subscriptionId: UInt16?
    private var dependencies: SendDependencies?
    private var runtimeItemByChainId: [ChainModel.Id: RuntimeMetadataItem] = [:]

    init(
        feeProxy: ExtrinsicFeeProxyProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        operationManager: OperationManagerProtocol,
        scamServiceOperationFactory: ScamServiceOperationFactoryProtocol,
        chainAssetFetching: ChainAssetFetchingProtocol,
        dependencyContainer: SendDepencyContainer,
        addressChainDefiner: AddressChainDefiner,
        runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>,
        operationQueue: OperationQueue
    ) {
        self.feeProxy = feeProxy
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriber = priceLocalSubscriber
        self.operationManager = operationManager
        self.scamServiceOperationFactory = scamServiceOperationFactory
        self.chainAssetFetching = chainAssetFetching
        self.dependencyContainer = dependencyContainer
        self.addressChainDefiner = addressChainDefiner
        self.runtimeItemRepository = runtimeItemRepository
        self.operationQueue = operationQueue
    }

    // MARK: - Private methods

    private func subscribeToAccountInfo(for chainAsset: ChainAsset, utilityAsset: ChainAsset? = nil) {
        guard let dependencies = dependencies else {
            return
        }

        if let accountId = dependencies.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            dependencies.accountInfoFetching.fetch(for: chainAsset, accountId: accountId) { [weak self] chainAsset, accountInfo in

                DispatchQueue.main.async {
                    self?.output?.didReceiveAccountInfo(result: .success(accountInfo), for: chainAsset)
                }

                let chainAssets: [ChainAsset] = [chainAsset, utilityAsset].compactMap { $0 }
                self?.accountInfoSubscriptionAdapter.subscribe(
                    chainsAssets: chainAssets,
                    handler: self
                )
            }
        }
    }

    private func subscribeToPrice(for chainAsset: ChainAsset) {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
        if let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
            utilityPriceProvider = priceLocalSubscriber.subscribeToPrice(for: utilityAsset, listener: self)
        }
    }

    private func fetchCurrentRuntimeItem(currentChainAsset: ChainAsset) async throws -> RuntimeMetadataItem? {
        if let item = runtimeItemByChainId[currentChainAsset.chain.chainId] {
            return item
        }

        let currentChainId = currentChainAsset.chain.chainId

        return try await withUnsafeThrowingContinuation { continuation in
            let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())

            runtimeItemsOperation.completionBlock = { [weak self] in
                do {
                    let items = try runtimeItemsOperation.extractNoCancellableResultData()
                    self?.cache(runtimeItems: items)

                    let currentRuntimeItem = items.first(where: { $0.chain == currentChainId })
                    continuation.resume(returning: currentRuntimeItem)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            operationQueue.addOperation(runtimeItemsOperation)
        }
    }

    private func cache(runtimeItems: [RuntimeMetadataItem]) {
        runtimeItemByChainId = runtimeItems.reduce([ChainModel.Id: RuntimeMetadataItem]()) { partialResult, currentItem in
            var result = partialResult
            result[currentItem.chain] = currentItem
            return result
        }
    }

    private func updateDependencies(for chainAsset: ChainAsset) {
        Task {
            let runtimeItem = try await fetchCurrentRuntimeItem(currentChainAsset: chainAsset)
            let dependencies = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset, runtimeItem: runtimeItem)
            self.dependencies = dependencies

            getTokensStatus(for: chainAsset)

            if chainAsset.chain.isUtilityFeePayment, !chainAsset.isUtility,
               let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
                subscribeToAccountInfo(for: chainAsset, utilityAsset: utilityAsset)
                provideConstants(for: utilityAsset)
            } else {
                subscribeToAccountInfo(for: chainAsset)
                provideConstants(for: chainAsset)
            }

            output?.didReceiveDependencies(for: chainAsset)
        }
    }

    private func getTokensStatus(for chainAsset: ChainAsset) {
        guard
            let currencyId = chainAsset.currencyId,
            let accountId = dependencies?.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
        else {
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceiveAssetAccountInfo(assetAccountInfo: nil)
            }
            return
        }

        Task {
            do {
                let accountIdVariant = try AccountIdVariant.build(raw: accountId, chain: chainAsset.chain)
                let request = AssetsAccountRequest(accountId: accountIdVariant, currencyId: currencyId)
                let assetAccountInfo: AssetAccountInfo? = try await dependencies?.storageRequestPerformer?.performSingle(request)

                await MainActor.run {
                    output?.didReceiveAssetAccountInfo(assetAccountInfo: assetAccountInfo)
                }
            } catch {
                await MainActor.run {
                    output?.didReceiveAssetAccountInfoError(error: error)
                }
            }
        }
    }
}

extension SendInteractor: SendInteractorInput {
    func setup(with output: SendInteractorOutput) {
        self.output = output
        feeProxy.delegate = self
    }

    func updateSubscriptions(for chainAsset: ChainAsset) {
        subscribeToPrice(for: chainAsset)
        updateDependencies(for: chainAsset)
    }

    func defineAvailableChains(
        for asset: AssetModel,
        completionBlock: @escaping ([ChainModel]?) -> Void
    ) {
        chainAssetFetching.fetch(shouldUseCache: true, filters: [], sortDescriptors: []) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(chainAssets):
                    let chains = chainAssets.filter { $0.asset.symbolUppercased == asset.symbolUppercased }.map { $0.chain }
                    completionBlock(chains)
                default:
                    completionBlock(nil)
                }
            }
        }
    }

    func estimateFee(for amount: BigUInt, tip: BigUInt?, for address: String?, chainAsset: ChainAsset) {
        guard let dependencies = dependencies else {
            return
        }

        Task {
            do {
                let address = try (address ?? AddressFactory.randomAccountId(for: chainAsset.chain).toAddress(using: chainAsset.chain.chainFormat))

                let transfer = Transfer(
                    chainAsset: chainAsset,
                    amount: amount,
                    receiver: address,
                    tip: tip
                )

                let fee = try await dependencies.transferService.estimateFee(for: transfer)

                await MainActor.run(body: {
                    output?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
                })

                dependencies.transferService.subscribeForFee(transfer: transfer, listener: self)
            } catch {
                await MainActor.run(body: {
                    output?.didReceiveFee(result: .failure(error))
                })
            }
        }
    }

    func fetchScamInfo(for address: String) {
        let allOperation = scamServiceOperationFactory.fetchScamInfoOperation(for: address)

        allOperation.completionBlock = { [weak self] in
            guard let result = allOperation.result else {
                return
            }

            switch result {
            case let .success(scamInfo):
                DispatchQueue.main.async {
                    self?.output?.didReceive(scamInfo: scamInfo)
                }
            case .failure:
                break
            }
        }
        operationManager.enqueue(operations: [allOperation], in: .transient)
    }

    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }
        return chainAsset
    }

    func getPossibleChains(for address: String) async -> [ChainModel]? {
        await addressChainDefiner.getPossibleChains(for: address)
    }

    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        addressChainDefiner.validate(address: address, for: chain)
    }

    func calculateEquilibriumBalance(chainAsset: ChainAsset, amount: Decimal) {
        if chainAsset.chain.isEquilibrium {
            let totalBalanceAfterTransfer = equilibriumTotalBalanceService?
                .totalBalanceAfterTransfer(chainAsset: chainAsset, amount: amount) ?? .zero
            output?.didReceive(eqTotalBalance: totalBalanceAfterTransfer)
        }
    }

    func didReceive(xorlessTransfer: XorlessTransfer) {
        guard let dependencies = dependencies else {
            return
        }

        Task {
            do {
                let fee = try await dependencies.transferService.estimateFee(for: xorlessTransfer)
                await MainActor.run(body: {
                    output?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
                })
            } catch {
                await MainActor.run(body: {
                    output?.didReceiveFee(result: .failure(error))
                })
            }
        }
    }

    func convert(chainAsset: ChainAsset, toChainAsset: ChainAsset, amount: BigUInt) async throws -> SwapValues? {
        guard let polkaswapService = dependencies?.polkaswapService else {
            throw ConvenienceError(error: "Dependencies not ready")
        }
        return try await polkaswapService.fetchQuotes(amount: amount, fromChainAsset: chainAsset, toChainAsset: toChainAsset)
    }

    func provideConstants(for chainAsset: ChainAsset) {
        guard let dependencies = dependencies else {
            return
        }

        guard let runtimeService = dependencies.runtimeService else {
            return
        }

        dependencies.existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.output?.didReceiveMinimumBalance(result: result)
            }
        }

        if chainAsset.chain.isTipRequired {
            fetchConstant(
                for: .defaultTip,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Swift.Result<BigUInt, Error>) in
                DispatchQueue.main.async {
                    self?.output?.didReceiveTip(result: result)
                }
            }
        }
        if chainAsset.chain.isEquilibrium {
            equilibriumTotalBalanceService = dependencies.equilibruimTotalBalanceService
        }
    }
}

extension SendInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Swift.Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension SendInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        output?.didReceivePriceData(result: result)
    }
}

extension SendInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Swift.Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}

extension SendInteractor: TransferFeeEstimationListener {
    func didReceiveFee(fee: BigUInt) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
        }
    }

    func didReceiveFeeError(feeError: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceiveFee(result: .failure(feeError))
        }
    }
}
