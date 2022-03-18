import UIKit
import SoraKeystore
import RobinHood
import BigInt
import FearlessUtils
import IrohaCrypto

final class StakingRebondConfirmationInteractor: RuntimeConstantFetching, AccountFetching {
    weak var presenter: StakingRebondConfirmationInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chain: ChainModel
    let asset: AssetModel
    let keystore: KeystoreProtocol
    let selectedAccount: MetaAccountModel
    let connection: JSONRPCEngine
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
        keystore: KeystoreProtocol,
        connection: JSONRPCEngine,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.asset = asset
        self.chain = chain
        self.keystore = keystore
        self.connection = connection
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
}

extension StakingRebondConfirmationInteractor: StakingRebondConfirmationInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        activeEraProvider = subscribeActiveEra(for: chain.chainId)

        feeProxy.delegate = self
    }

    func submit(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let signingWrapper = signingWrapper,
              let amountValue = amount.toSubstrateAmount(
                  precision: Int16(asset.precision)
              ) else {
            presenter.didSubmitRebonding(result: .failure(CommonError.undefined))
            return
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        extrinsicService.submit(
            { builder in
                try builder.adding(call: rebondCall)
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter.didSubmitRebonding(result: result)
            }
        )
    }

    func estimateFee(for amount: Decimal) {
        guard let extrinsicService = extrinsicService,
              let amountValue = amount.toSubstrateAmount(
                  precision: Int16(asset.precision)
              ) else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        let rebondCall = callFactory.rebond(amount: amountValue)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: rebondCall.callName) { builder in
            try builder.adding(call: rebondCall)
        }
    }
}

extension StakingRebondConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRebondConfirmationInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRebondConfirmationInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveActiveEra(result: result)
    }

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

                accountInfoSubscriptionAdapter.subscribe(chain: chain, accountId: accountId, handler: self)

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
}

extension StakingRebondConfirmationInteractor: AnyProviderAutoCleaning {}

extension StakingRebondConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
