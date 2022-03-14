import UIKit
import RobinHood
import BigInt
import IrohaCrypto

final class WalletSendInteractor: RuntimeConstantFetching {
    weak var presenter: WalletSendInteractorOutputProtocol?

    let selectedMetaAccount: MetaAccountModel
    let chain: ChainModel
    let asset: AssetModel
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationManager: OperationManagerProtocol
    let receiverAddress: String

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private(set) lazy var callFactory = SubstrateCallFactory()

    init(
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        receiverAddress: String,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chain = chain
        self.asset = asset
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.receiverAddress = receiverAddress
        self.operationManager = operationManager
    }

    private func provideConstants() {
        fetchConstant(
            for: .babeBlockTime,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            self?.presenter?.didReceiveBlockDuration(result: result)
        }

        if chain.isOrml {
            presenter?.didReceiveMinimumBalance(result: .success(BigUInt.zero))
        } else {
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<BigUInt, Error>) in
                self?.presenter?.didReceiveMinimumBalance(result: result)
            }
        }
    }

    private func subscribeToAccountInfo() {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            presenter?.didReceiveAccountInfo(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        accountInfoSubscriptionAdapter.subscribe(chain: chain, accountId: accountId, handler: self)
    }

    private func subscribeToPrice() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter?.didReceivePriceData(result: .success(nil))
        }
    }

    func setup() {
        feeProxy.delegate = self

        subscribeToPrice()
        subscribeToAccountInfo()

        provideConstants()
    }
}

extension WalletSendInteractor: WalletSendInteractorInputProtocol {
    func estimateFee(for amount: BigUInt) {
        guard let accountId = try? AddressFactory.accountId(from: receiverAddress, chain: chain) else { return }

        let call = callFactory.transfer(to: accountId, amount: amount, currencyId: chain.currencyId, chain: chain)
        let identifier = String(amount)

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            let nextBuilder = try builder.adding(call: call)
            return nextBuilder
        }
    }
}

extension WalletSendInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter?.didReceiveAccountInfo(result: result)
    }
}

extension WalletSendInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result)
    }
}

extension WalletSendInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter?.didReceiveFee(result: result)
    }
}
