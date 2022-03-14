import Foundation
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils
import IrohaCrypto

final class StakingUnbondConfirmInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingUnbondConfirmInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let connection: JSONRPCEngine
    let keystore: KeystoreProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var minBondedProvider: AnyDataProvider<DecodedBigUInt>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.asset = asset
        self.chain = chain
        self.connection = connection
        self.keystore = keystore
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
    }

    private func handleController(accountItem: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: accountItem.chainFormat(),
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: selectedAccount.metaId,
            accountResponse: accountItem
        )
    }

    private func setupExtrinsicBuiler(
        _ builder: ExtrinsicBuilderProtocol,
        amount: Decimal,
        resettingRewardDestination: Bool,
        chilling: Bool
    ) throws -> ExtrinsicBuilderProtocol {
        guard let amountValue = amount.toSubstrateAmount(precision: Int16(asset.precision)) else {
            throw CommonError.undefined
        }

        var resultBuilder = builder

        if chilling {
            resultBuilder = try builder.adding(call: callFactory.chill())
        }

        resultBuilder = try resultBuilder.adding(call: callFactory.unbond(amount: amountValue))

        if resettingRewardDestination {
            resultBuilder = try resultBuilder.adding(call: callFactory.setPayee(for: .stash))
        }

        return resultBuilder
    }
}

extension StakingUnbondConfirmInteractor: StakingUnbondConfirmInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        minBondedProvider = subscribeToMinNominatorBond(for: chain.chainId)

        if chain.isOrml {
            presenter?.didReceiveExistentialDeposit(result: .success(BigUInt.zero))
        } else {
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<BigUInt, Error>) in
                self?.presenter?.didReceiveExistentialDeposit(result: result)
            }
        }

        feeProxy.delegate = self
    }

    func estimateFee(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let reuseIdentifier = amount.description + resettingRewardDestination.description

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier
        ) { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: amount,
                resettingRewardDestination: resettingRewardDestination,
                chilling: chilling
            )
        }
    }

    func submit(for amount: Decimal, resettingRewardDestination: Bool, chilling: Bool) {
        guard
            let extrinsicService = extrinsicService,
            let signingWrapper = signingWrapper else {
            presenter.didSubmitUnbonding(result: .failure(CommonError.undefined))
            return
        }

        let builderClosure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                throw CommonError.undefined
            }

            return try strongSelf.setupExtrinsicBuiler(
                builder,
                amount: amount,
                resettingRewardDestination: resettingRewardDestination,
                chilling: chilling
            )
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitUnbonding(result: result)
            }
        )
    }
}

extension StakingUnbondConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingUnbondConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingUnbondConfirmInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceivePayee(result: result)
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMinBonded(result: result)
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveNomination(result: result)
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            let maybeStashItem = try result.get()

            clear(dataProvider: &accountInfoProvider)
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &nominationProvider)

            presenter.didReceiveStashItem(result: result)

            let addressFactory = SS58AddressFactory()

            if let stashItem = maybeStashItem,
               let accountId = try? addressFactory.accountId(fromAddress: stashItem.controller, type: chain.addressPrefix) {
                ledgerProvider = subscribeLedgerInfo(
                    for: accountId,
                    chainId: chain.chainId
                )

                accountInfoSubscriptionAdapter.subscribe(chain: chain, accountId: accountId, handler: self)

                payeeProvider = subscribePayee(for: accountId, chainId: chain.chainId)

                nominationProvider = subscribeNomination(for: accountId, chainId: chain.chainId)

                fetchChainAccount(chain: chain, address: stashItem.controller, from: accountRepository, operationManager: operationManager) { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    if case let .success(account) = result, let account = account {
                        self.handleController(accountItem: account)
                    }

                    self.presenter.didReceiveController(result: result)
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
                presenter.didReceivePayee(result: .success(nil))
                presenter.didReceiveNomination(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
            presenter.didReceivePayee(result: .failure(error))
            presenter.didReceiveNomination(result: .failure(error))
        }
    }
}

extension StakingUnbondConfirmInteractor: AnyProviderAutoCleaning {}

extension StakingUnbondConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
