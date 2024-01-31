import UIKit
import RobinHood
import SSFModels

final class PoolRolesConfirmInteractor: AccountFetching {
    // MARK: - Private properties

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private weak var output: PoolRolesConfirmInteractorOutput?
    private let chainAsset: ChainAsset
    private let extrinsicService: ExtrinsicServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let poolId: String
    private let roles: StakingPoolRoles
    private let signingWrapper: SigningWrapperProtocol
    private let callFactory: SubstrateCallFactoryProtocol
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationManager: OperationManagerProtocol

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        poolId: String,
        roles: StakingPoolRoles,
        signingWrapper: SigningWrapperProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.poolId = poolId
        self.roles = roles
        self.chainAsset = chainAsset
        self.priceLocalSubscriber = priceLocalSubscriber
        self.signingWrapper = signingWrapper
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.callFactory = callFactory
    }

    private func builderClosure() -> ExtrinsicBuilderClosure {
        let poolUpdateRolesCall = callFactory.nominationPoolUpdateRoles(poolId: poolId, roles: roles)
        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: poolUpdateRolesCall)
        }

        return builderClosure
    }

    private func fetchAllAccounts() {
        fetchAllMetaAccounts(from: accountRepository, operationManager: operationManager) { [weak self] result in
            switch result {
            case let .success(accounts):
                self?.output?.didReceive(accounts: accounts)
            case let .failure(error):
                self?.output?.didReceive(error: error)
            }
        }
    }
}

// MARK: - PoolRolesConfirmInteractorInput

extension PoolRolesConfirmInteractor: PoolRolesConfirmInteractorInput {
    func setup(with output: PoolRolesConfirmInteractorOutput) {
        self.output = output

        feeProxy.delegate = self

        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        fetchAllAccounts()
    }

    func estimateFee() {
        let reuseIdentifier = CallCodingPath.nominationPoolUpdateRoles.callName
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: builderClosure()
        )
    }

    func submit() {
        extrinsicService.submit(
            builderClosure(),
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.output?.didReceive(extrinsicResult: result)
        }
    }
}

extension PoolRolesConfirmInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        output?.didReceivePriceData(result: result)
    }
}

extension PoolRolesConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        output?.didReceiveFee(result: result)
    }
}
