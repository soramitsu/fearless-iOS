import UIKit
import RobinHood
import BigInt
import IrohaCrypto
import SSFModels

final class WalletSendConfirmInteractor: RuntimeConstantFetching {
    weak var presenter: WalletSendConfirmInteractorOutputProtocol?

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let selectedMetaAccount: MetaAccountModel
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let receiverAddress: String
    private let signingWrapper: SigningWrapperProtocol
    private let chainAsset: ChainAsset
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?

    let dependencyContainer: SendDepencyContainer

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var utilityPriceProvider: AnySingleValueProvider<PriceData>?

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        receiverAddress: String,
        feeProxy: ExtrinsicFeeProxyProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signingWrapper: SigningWrapperProtocol,
        dependencyContainer: SendDepencyContainer
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.feeProxy = feeProxy
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.receiverAddress = receiverAddress
        self.operationManager = operationManager
        self.signingWrapper = signingWrapper
        self.dependencyContainer = dependencyContainer
    }

    private func provideConstants() {
        guard let utilityAsset = getFeePaymentChainAsset(for: chainAsset),
              let dependencies = dependencyContainer.prepareDepencies(chainAsset: utilityAsset) else {
            return
        }

        dependencies.existentialDepositService.fetchExistentialDeposit(
            chainAsset: utilityAsset
        ) { [weak self] result in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }
    }

    private func subscribeToAccountInfo() {
        var chainsAssets = [chainAsset]
        if chainAsset.chain.isUtilityFeePayment, !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
            chainsAssets.append(utilityAsset)
        }
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainsAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func subscribeToPrice() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter?.didReceivePriceData(result: .success(nil), for: nil)
        }
        if chainAsset.chain.isSora, !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset),
           let priceId = utilityAsset.asset.priceId {
            utilityPriceProvider = subscribeToPrice(for: priceId)
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
        ),
            let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset) else { return }

        let call = dependencies.callFactory.transfer(to: accountId, amount: amount, chainAsset: chainAsset)
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

    func submitExtrinsic(for transferAmount: BigUInt, tip: BigUInt?, receiverAddress: String) {
        guard let accountId = try? AddressFactory.accountId(
            from: receiverAddress,
            chain: chainAsset.chain
        ),
            let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset) else { return }

        let call = dependencies.callFactory.transfer(
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

        dependencies.extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                self?.presenter?.didTransfer(result: result)
            }
        )
    }

    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if let utilityAsset = chainAsset.chain.utilityAssets().first {
            return ChainAsset(chain: chainAsset.chain, asset: utilityAsset)
        }
        return chainAsset
    }

    func fetchEquilibriumTotalBalance(chainAsset: ChainAsset, amount: Decimal) {
        if chainAsset.chain.isEquilibrium {
            let service = dependencyContainer
                .prepareDepencies(chainAsset: chainAsset)?
                .equilibruimTotalBalanceService
            equilibriumTotalBalanceService = service

            let totalBalanceAfterTransfer = equilibriumTotalBalanceService?
                .totalBalanceAfterTransfer(chainAsset: chainAsset, amount: amount) ?? .zero
            presenter?.didReceive(eqTotalBalance: totalBalanceAfterTransfer)
        }
    }
}

extension WalletSendConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension WalletSendConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result, for: priceId)
    }
}

extension WalletSendConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter?.didReceiveFee(result: result)
    }
}
