import UIKit
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils
import IrohaCrypto

final class StakingRedeemInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRedeemInteractorOutputProtocol!

    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let slashesOperationFactory: SlashesOperationFactoryProtocol
    let engine: JSONRPCEngine
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let keystore: KeystoreProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        walletLocalSubscriptionHandler: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        slashesOperationFactory: SlashesOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        keystore: KeystoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        walletLocalSubscriptionFactory = walletLocalSubscriptionHandler
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.slashesOperationFactory = slashesOperationFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.engine = engine
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.keystore = keystore
        self.accountRepository = accountRepository
    }

    private func handleController(accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: accountItem.chainFormat(),
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: engine,
            operationManager: operationManager
        )

        signingWrapper = SigningWrapper(keystore: keystore, metaId: selectedAccount.metaId, accountResponse: accountItem)
    }

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        numberOfSlashingSpans: UInt32
    ) throws -> ExtrinsicBuilderProtocol {
        try builder.adding(call: callFactory.withdrawUnbonded(for: numberOfSlashingSpans))
    }

    private func fetchSlashingSpansForStash(
        _ stash: AccountAddress,
        completionClosure: @escaping (Result<SlashingSpans?, Error>) -> Void
    ) {
        let wrapper = slashesOperationFactory.createSlashingSpansOperationForStash(
            stash,
            engine: engine,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = wrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        operationManager.enqueue(
            operations: wrapper.allOperations,
            in: .transient
        )
    }

    private func estimateFee(with numberOfSlasingSpans: UInt32) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let reuseIdentifier = numberOfSlasingSpans.description

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier
        ) { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                numberOfSlashingSpans: numberOfSlasingSpans
            )
        }
    }

    private func submit(with numberOfSlasingSpans: UInt32) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper else {
            presenter.didSubmitRedeeming(result: .failure(CommonError.undefined))
            return
        }

        extrinsicService.submit(
            { [weak self] builder in
                guard let strongSelf = self else {
                    throw CommonError.undefined
                }

                return try strongSelf.setupExtrinsicBuiler(
                    builder,
                    numberOfSlashingSpans: numberOfSlasingSpans
                )
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitRedeeming(result: result)
            }
        )
    }
}

extension StakingRedeemInteractor: StakingRedeemInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        activeEraProvider = subscribeActiveEra(for: chain.chainId)

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter.didReceiveExistentialDeposit(result: result)
        }

        feeProxy.delegate = self
    }

    func estimateFeeForStash(_ stashAddress: AccountAddress) {
        fetchSlashingSpansForStash(stashAddress) { [weak self] result in
            switch result {
            case let .success(slashingSpans):
                let numberOfSlashes = slashingSpans.map { $0.prior.count + 1 } ?? 0
                self?.estimateFee(with: UInt32(numberOfSlashes))
            case let .failure(error):
                self?.presenter.didSubmitRedeeming(result: .failure(error))
            }
        }
    }

    func submitForStash(_ stashAddress: AccountAddress) {
        fetchSlashingSpansForStash(stashAddress) { [weak self] result in
            switch result {
            case let .success(slashingSpans):
                let numberOfSlashes = slashingSpans.map { $0.prior.count + 1 } ?? 0
                self?.submit(with: UInt32(numberOfSlashes))
            case let .failure(error):
                self?.presenter.didSubmitRedeeming(result: .failure(error))
            }
        }
    }
}

extension StakingRedeemInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRedeemInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRedeemInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)

            presenter.didReceiveStashItem(result: result)

            let addressFactory = SS58AddressFactory()

            if let stashItem = maybeStashItem,
               let accountId = try? addressFactory.accountId(fromAddress: stashItem.controller, type: chain.addressPrefix) {
                ledgerProvider = subscribeLedgerInfo(for: accountId, chainId: chain.chainId)

                accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)

                fetchChainAccount(
                    chain: chain,
                    address: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeController) = result, let controller = maybeController {
                        self?.handleController(accountItem: controller)
                    }

                    self?.presenter.didReceiveController(result: result)
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveActiveEra(result: result)
    }
}

extension StakingRedeemInteractor: AnyProviderAutoCleaning {}

extension StakingRedeemInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
