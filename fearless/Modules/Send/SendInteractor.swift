import UIKit
import RobinHood
import Web3
import SSFModels
import Web3PromiseKit

final class SendInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: SendInteractorOutput?

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let scamServiceOperationFactory: ScamServiceOperationFactoryProtocol
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let addressChainDefiner: AddressChainDefiner
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?

    let dependencyContainer: SendDepencyContainer

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var utilityPriceProvider: AnySingleValueProvider<PriceData>?

    private var subscriptionId: UInt16?
    private var dependencies: SendDependencies?
    private var remark: Data?

    init(
        feeProxy: ExtrinsicFeeProxyProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        scamServiceOperationFactory: ScamServiceOperationFactoryProtocol,
        chainAssetFetching: ChainAssetFetchingProtocol,
        dependencyContainer: SendDepencyContainer,
        addressChainDefiner: AddressChainDefiner
    ) {
        self.feeProxy = feeProxy
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationManager = operationManager
        self.scamServiceOperationFactory = scamServiceOperationFactory
        self.chainAssetFetching = chainAssetFetching
        self.dependencyContainer = dependencyContainer
        self.addressChainDefiner = addressChainDefiner
    }

    // MARK: - Private methods

    private func provideConstants(for chainAsset: ChainAsset) {
        guard let dependencies = dependencies else {
            return
        }

        Task {
            guard let runtimeService = dependencies.runtimeService else {
                return
            }

            dependencies.existentialDepositService.fetchExistentialDeposit(
                chainAsset: chainAsset
            ) { [weak self] result in
                self?.output?.didReceiveMinimumBalance(result: result)
            }

            if chainAsset.chain.isTipRequired {
                fetchConstant(
                    for: .defaultTip,
                    runtimeCodingService: runtimeService,
                    operationManager: operationManager
                ) { [weak self] (result: Swift.Result<BigUInt, Error>) in
                    self?.output?.didReceiveTip(result: result)
                }
            }
            if chainAsset.chain.isEquilibrium {
                equilibriumTotalBalanceService = dependencies.equilibruimTotalBalanceService
            }
        }
    }

    private func subscribeToAccountInfo(for chainAsset: ChainAsset, utilityAsset: ChainAsset? = nil) {
        guard let dependencies = dependencies else {
            return
        }

        Task {
            if let accountId = dependencies.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
                dependencies.accountInfoFetching.fetch(for: chainAsset, accountId: accountId) { [weak self] chainAsset, accountInfo in

                    self?.output?.didReceiveAccountInfo(result: .success(accountInfo), for: chainAsset)

                    let chainAssets: [ChainAsset] = [chainAsset, utilityAsset].compactMap { $0 }
                    self?.accountInfoSubscriptionAdapter.subscribe(
                        chainsAssets: chainAssets,
                        handler: self
                    )
                }
            }
        }
    }

    private func subscribeToPrice(for chainAsset: ChainAsset) {
        priceProvider?.removeObserver(self)
        utilityPriceProvider?.removeObserver(self)
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            output?.didReceivePriceData(result: .success(nil), for: nil)
        }
        if chainAsset.chain.isSora, !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset),
           let priceId = utilityAsset.asset.priceId {
            utilityPriceProvider = subscribeToPrice(for: priceId)
        }
    }

    private func updateDependencies(for chainAsset: ChainAsset) {
        Task {
            let dependencies = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset)
            self.dependencies = dependencies

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
}

extension SendInteractor: SendInteractorInput {
    func addRemark(remark: Data) {
        self.remark = remark
    }

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
        chainAssetFetching.fetch(shouldUseCashe: true, filters: [], sortDescriptors: []) { result in
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

                let fee = try await dependencies.transferService.estimateFee(for: transfer, remark: remark)

                await MainActor.run(body: {
                    output?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
                })

                dependencies.transferService.subscribeForFee(transfer: transfer, remark: remark, listener: self)
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

extension SendInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result, for: priceId)
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
