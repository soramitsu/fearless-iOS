import UIKit
import RobinHood
import BigInt

final class SendInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: SendInteractorOutput?

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let wallet: MetaAccountModel
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let scamServiceOperationFactory: ScamServiceOperationFactoryProtocol
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let chainModelRepository: AnyDataProviderRepository<ChainModel>
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?

    let dependencyContainer: SendDepencyContainer

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var utilityPriceProvider: AnySingleValueProvider<PriceData>?

    private(set) lazy var callFactory = SubstrateCallFactory()

    init(
        wallet: MetaAccountModel,
        feeProxy: ExtrinsicFeeProxyProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        scamServiceOperationFactory: ScamServiceOperationFactoryProtocol,
        chainAssetFetching: ChainAssetFetchingProtocol,
        dependencyContainer: SendDepencyContainer,
        chainModelRepository: AnyDataProviderRepository<ChainModel>
    ) {
        self.wallet = wallet
        self.feeProxy = feeProxy
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationManager = operationManager
        self.scamServiceOperationFactory = scamServiceOperationFactory
        self.chainAssetFetching = chainAssetFetching
        self.dependencyContainer = dependencyContainer
        self.chainModelRepository = chainModelRepository
    }

    // MARK: - Private methods

    private func provideConstants(for chainAsset: ChainAsset) {
        guard let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset) else {
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
                runtimeCodingService: dependencies.runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<BigUInt, Error>) in
                self?.output?.didReceiveTip(result: result)
            }
        }
        if chainAsset.chain.isEquilibrium {
            equilibriumTotalBalanceService = dependencies.equilibruimTotalBalanceService
        }
    }

    private func subscribeToAccountInfo(for chainAsset: ChainAsset, utilityAsset: ChainAsset? = nil) {
        let chainAssets: [ChainAsset] = [chainAsset, utilityAsset].compactMap { $0 }
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainAssets,
            handler: self
        )
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

//    private func fetchEquilibriumTotalBalance(chainAsset: ChainAsset) {
//        if chainAsset.chain.isEquilibrium {
//            let service = dependencyContainer
//                .prepareDepencies(chainAsset: chainAsset)?
//                .equilibruimTotalBalanceService
//            equilibriumTotalBalanceService = service
//
//            equilibriumTotalBalanceService?
//                .fetchTotalBalance(completion: { [weak self] totalBalance in
//                    self?.output?.didReceive(eqTotalBalance: totalBalance)
//                })
//        }
//    }
}

extension SendInteractor: SendInteractorInput {
    func setup(with output: SendInteractorOutput) {
        self.output = output
        feeProxy.delegate = self
    }

    func updateSubscriptions(for chainAsset: ChainAsset) {
        subscribeToPrice(for: chainAsset)
        if chainAsset.chain.isUtilityFeePayment, !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
            subscribeToAccountInfo(for: chainAsset, utilityAsset: utilityAsset)
            provideConstants(for: utilityAsset)
        } else {
            subscribeToAccountInfo(for: chainAsset)
            provideConstants(for: chainAsset)
        }
//        fetchEquilibriumTotalBalance(chainAsset: chainAsset)
    }

    func defineAvailableChains(
        for asset: AssetModel,
        completionBlock: @escaping ([ChainModel]?) -> Void
    ) {
        chainAssetFetching.fetch(filters: [], sortDescriptors: []) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(chainAssets):
                    let chains = chainAssets.filter { $0.asset.name == asset.name }.map { $0.chain }
                    completionBlock(chains)
                default:
                    completionBlock(nil)
                }
            }
        }
    }

    func estimateFee(for amount: BigUInt, tip: BigUInt?, for address: String?, chainAsset: ChainAsset) {
        func accountId(from address: String?, chain: ChainModel) -> AccountId {
            guard let address = address,
                  let accountId = try? AddressFactory.accountId(from: address, chain: chain)
            else {
                return AddressFactory.randomAccountId(for: chain)
            }

            return accountId
        }

        guard
            let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset)
        else { return }

        let accountId = accountId(from: address, chain: chainAsset.chain)
        let call = callFactory.transfer(to: accountId, amount: amount, chainAsset: chainAsset)
        var identifier = String(amount)
        if let tip = tip {
            identifier += "_\(String(tip))"
        }

        feeProxy.estimateFee(using: dependencies.extrinsicService, reuseIdentifier: identifier) { builder in
            var nextBuilder = try builder.adding(call: call)
            if let tip = tip {
                nextBuilder = builder.with(tip: tip)
            }
            return nextBuilder
        }
    }

    func validate(address: String, for chain: ChainModel) -> Bool {
        ((try? AddressFactory.accountId(from: address, chain: chain)) != nil)
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
        if chainAsset.chain.isUtilityFeePayment, !chainAsset.isUtility,
           let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }
        return chainAsset
    }

    func getPossibleChains(for address: String) {
        let fetchOperation = chainModelRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = {
            let chains = try? fetchOperation.extractNoCancellableResultData()
            let posssibleChains = chains?.filter { [weak self] chain in
                guard let strongSelf = self else { return false }
                return strongSelf.validate(address: address, for: chain)
            }
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceive(possibleChains: posssibleChains)
            }
        }
        operationManager.enqueue(operations: [fetchOperation], in: .transient)
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
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension SendInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result, for: priceId)
    }
}

extension SendInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
