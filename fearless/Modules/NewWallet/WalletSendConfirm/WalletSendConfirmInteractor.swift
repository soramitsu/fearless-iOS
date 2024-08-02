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

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let selectedMetaAccount: MetaAccountModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let call: SendConfirmTransferCall
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    let dependencyContainer: SendDepencyContainer
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var utilityPriceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        dependencyContainer: SendDepencyContainer,
        wallet: MetaAccountModel
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriber = priceLocalSubscriber
        self.call = call
        self.dependencyContainer = dependencyContainer
        self.wallet = wallet
    }

    private func subscribeToAccountInfo() {
        var chainsAssets = [chainAsset]
        if !chainAsset.isUtility,
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
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
        if let utilityAsset = getFeePaymentChainAsset(for: chainAsset), utilityAsset != chainAsset {
            utilityPriceProvider = priceLocalSubscriber.subscribeToPrice(for: utilityAsset, listener: self)
        }
    }

    private func subscribeToFee() {
        switch call {
        case let .transfer(transfer):
            Task {
                do {
                    let transferService = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset).transferService
                    transferService.subscribeForFee(transfer: transfer, listener: self)
                } catch {
                    await MainActor.run {
                        presenter?.didReceiveFee(result: .failure(error))
                    }
                }
            }
        case let .xorlessTransfer(xorlessTransfer):
            break
        }
    }
}

extension WalletSendConfirmInteractor: WalletSendConfirmInteractorInputProtocol {
    func setup() {
        subscribeToPrice()
        subscribeToAccountInfo()
        provideConstants()
        subscribeToFee()
    }

    func submitExtrinsic() {
        Task {
            do {
                let transferService = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset).transferService

                let txHash: String
                switch call {
                case let .transfer(transfer):
                    txHash = try await transferService.submit(transfer: transfer)
                case let .xorlessTransfer(transfer):
                    txHash = try await transferService.submit(transfer: transfer)
                }

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

    func provideConstants() {
        Task {
            let dependencies = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset)

            dependencies.existentialDepositService.fetchExistentialDeposit(
                chainAsset: chainAsset
            ) { [weak self] result in
                self?.presenter?.didReceiveMinimumBalance(result: result)
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

extension WalletSendConfirmInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, chainAsset: ChainAsset) {
        presenter?.didReceivePriceData(result: result, for: chainAsset.asset.priceId)
    }
}

extension WalletSendConfirmInteractor: TransferFeeEstimationListener {
    func didReceiveFee(fee: BigUInt) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
        }
    }

    func didReceiveFeeError(feeError: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceiveFee(result: .failure(feeError))
        }
    }
}
