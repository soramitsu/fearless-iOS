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
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let call: SendConfirmTransferCall
    private let signingWrapper: SigningWrapperProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    let dependencyContainer: SendDepencyContainer
    private let runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>
    private let operationQueue: OperationQueue
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var utilityPriceProvider: AnySingleValueProvider<[PriceData]>?
    private var runtimeItemByChainId: [ChainModel.Id: RuntimeMetadataItem] = [:]

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        feeProxy: ExtrinsicFeeProxyProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        operationManager: OperationManagerProtocol,
        signingWrapper: SigningWrapperProtocol,
        dependencyContainer: SendDepencyContainer,
        wallet: MetaAccountModel,
        runtimeItemRepository: AnyDataProviderRepository<RuntimeMetadataItem>,
        operationQueue: OperationQueue
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.feeProxy = feeProxy
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriber = priceLocalSubscriber
        self.call = call
        self.operationManager = operationManager
        self.signingWrapper = signingWrapper
        self.dependencyContainer = dependencyContainer
        self.wallet = wallet
        self.runtimeItemRepository = runtimeItemRepository
        self.operationQueue = operationQueue
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
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
        if chainAsset.chain.isSora, !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
            utilityPriceProvider = priceLocalSubscriber.subscribeToPrice(for: utilityAsset, listener: self)
        }
    }

    private func fetchCurrentRuntimeItem() async throws -> RuntimeMetadataItem? {
        if let item = runtimeItemByChainId[chainAsset.chain.chainId] {
            return item
        }

        let currentChainId = chainAsset.chain.chainId

        return try await withUnsafeThrowingContinuation { continuation in
            let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())

            runtimeItemsOperation.completionBlock = { [weak self] in
                do {
                    let items = try runtimeItemsOperation.extractNoCancellableResultData()
                    self?.cache(runtimeItems: items)

                    let currentRuntimeItem = items.first(where: { $0.chain == currentChainId })
                    continuation.resume(returning: currentRuntimeItem)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            operationQueue.addOperation(runtimeItemsOperation)
        }
    }

    private func cache(runtimeItems: [RuntimeMetadataItem]) {
        runtimeItemByChainId = runtimeItems.reduce([ChainModel.Id: RuntimeMetadataItem]()) { partialResult, currentItem in
            var result = partialResult
            result[currentItem.chain] = currentItem
            return result
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
    func estimateFee() {
        Task {
            do {
                let runtimeItem = try await fetchCurrentRuntimeItem()
                let transferService = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset, runtimeItem: runtimeItem).transferService
                let fee: BigUInt
                switch call {
                case let .transfer(transfer):
                    fee = try await transferService.estimateFee(for: transfer)
                case let .xorlessTransfer(transfer):
                    fee = try await transferService.estimateFee(for: transfer)
                }
                await MainActor.run {
                    presenter?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
                }
            } catch {
                await MainActor.run {
                    presenter?.didReceiveFee(result: .failure(error))
                }
            }
        }
    }

    func submitExtrinsic() {
        Task {
            do {
                let runtimeItem = try await fetchCurrentRuntimeItem()
                let transferService = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset, runtimeItem: runtimeItem).transferService

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
                let runtimeItem = try await fetchCurrentRuntimeItem()
                let service = try await dependencyContainer
                    .prepareDepencies(chainAsset: chainAsset, runtimeItem: runtimeItem)
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
            let runtimeItem = try await fetchCurrentRuntimeItem()
            let dependencies = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset, runtimeItem: runtimeItem)

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

extension WalletSendConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Swift.Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter?.didReceiveFee(result: result)
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
