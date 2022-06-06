import UIKit
import RobinHood
import BigInt
import IrohaCrypto

final class WalletSendConfirmInteractor: RuntimeConstantFetching {
    weak var presenter: WalletSendConfirmInteractorOutputProtocol?

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let selectedMetaAccount: MetaAccountModel
    private let runtimeService: RuntimeCodingServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let receiverAddress: String
    private let signingWrapper: SigningWrapperProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol

    private let chainAsset: ChainAsset

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?

    private(set) lazy var callFactory = SubstrateCallFactory()

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        receiverAddress: String,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signingWrapper: SigningWrapperProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.receiverAddress = receiverAddress
        self.operationManager = operationManager
        self.signingWrapper = signingWrapper
        self.existentialDepositService = existentialDepositService
    }

    private func provideConstants() {
        fetchConstant(
            for: .babeBlockTime,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            self?.presenter?.didReceiveBlockDuration(result: result)
        }

        existentialDepositService.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }
    }

    private func subscribeToAccountInfo() {
        guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            presenter?.didReceiveAccountInfo(result: .failure(ChainAccountFetchingError.accountNotExists))
            return
        }

        accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
    }

    private func subscribeToPrice() {
        if let priceId = chainAsset.asset.priceId {
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

extension WalletSendConfirmInteractor: WalletSendConfirmInteractorInputProtocol {
    func estimateFee(for amount: BigUInt, tip: BigUInt?) {
        guard let accountId = try? AddressFactory.accountId(
            from: receiverAddress,
            chain: chainAsset.chain
        ) else { return }

        let call = callFactory.transfer(to: accountId, amount: amount, chainAsset: chainAsset)
        var identifier = String(amount)
        if let tip = tip {
            identifier += "_\(String(tip))"
        }

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
            var nextBuilder = try builder.adding(call: call)
            if let tip = tip {
                nextBuilder = builder.with(tip: tip)
            }
            return nextBuilder
        }
    }

    func submitExtrinsic(for transferAmount: BigUInt, tip: BigUInt?, receiverAddress: String) {
        guard let accountId = try? AddressFactory.accountId(
            from: receiverAddress,
            chain: chainAsset.chain
        ) else { return }

        let call = callFactory.transfer(
            to: accountId,
            amount: transferAmount,
            chainAsset: chainAsset
        )

        let builderClosure: ExtrinsicBuilderClosure = { builder in
            var nextBuilder = try builder.adding(call: call)
            if let tip = tip {
                nextBuilder = builder.with(tip: tip)
            }
            return nextBuilder
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter?.didTransfer(result: result)
            }
        )
    }
}

extension WalletSendConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result)
    }
}

extension WalletSendConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result)
    }
}

extension WalletSendConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter?.didReceiveFee(result: result)
    }
}
