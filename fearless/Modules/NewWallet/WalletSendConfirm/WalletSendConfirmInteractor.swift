import UIKit
import RobinHood
import Web3
import IrohaCrypto
import SSFModels
import SSFCrypto
import SoraKeystore
import Web3PromiseKit

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
    private let wallet: MetaAccountModel
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?

    private var gasPrice: EthereumQuantity?
    private var gasCount: EthereumQuantity?

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
        dependencyContainer: SendDepencyContainer,
        wallet: MetaAccountModel
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
        self.wallet = wallet
    }

    private func provideConstants() {
        Task {
            let dependencies = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset)

            dependencies.existentialDepositService.fetchExistentialDeposit(
                chainAsset: chainAsset
            ) { [weak self] result in
                self?.presenter?.didReceiveMinimumBalance(result: result)
            }
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
        Task {
            do {
                let transfer = Transfer(chainAsset: chainAsset, amount: amount, receiver: receiverAddress, tip: tip)
                let transferService = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset).transferService
                let fee = try await transferService.estimateFee(for: transfer)
                let runtimeDispatchInfo = RuntimeDispatchInfo(inclusionFee: FeeDetails(baseFee: fee, lenFee: .zero, adjustedWeightFee: .zero))

                await MainActor.run {
                    presenter?.didReceiveFee(result: .success(runtimeDispatchInfo))
                }
            } catch {
                await MainActor.run {
                    presenter?.didReceiveFee(result: .failure(error))
                }
            }
        }
    }

    func submitExtrinsic(for amount: BigUInt, tip: BigUInt?, receiverAddress: String) {
        Task {
            do {
                let transfer = Transfer(chainAsset: chainAsset, amount: amount, receiver: receiverAddress, tip: tip)
                let transferService = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset).transferService
                let txHash = try await transferService.submit(transfer: transfer)

                await MainActor.run {
                    presenter?.didTransfer(result: .success(txHash))
                }
            } catch {
                await MainActor.run {
                    presenter?.didTransfer(result: .failure(error))
                }
            }
        }
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
            Task {
                let service = try await dependencyContainer
                    .prepareDepencies(chainAsset: chainAsset)
                    .equilibruimTotalBalanceService
                equilibriumTotalBalanceService = service

                let totalBalanceAfterTransfer = equilibriumTotalBalanceService?
                    .totalBalanceAfterTransfer(chainAsset: chainAsset, amount: amount) ?? .zero
                presenter?.didReceive(eqTotalBalance: totalBalanceAfterTransfer)
            }
        }
    }
}

extension WalletSendConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Swift.Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension WalletSendConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result, for: priceId)
    }
}

extension WalletSendConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Swift.Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter?.didReceiveFee(result: result)
    }
}
