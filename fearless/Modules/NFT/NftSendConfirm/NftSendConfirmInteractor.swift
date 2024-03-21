import UIKit
import BigInt
import SSFModels

final class NftSendConfirmInteractor {
    // MARK: - Private properties

    private weak var output: NftSendConfirmInteractorOutput?
    private let transferService: NftTransferService
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let wallet: MetaAccountModel
    private let chain: ChainModel

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        transferService: NftTransferService,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        wallet: MetaAccountModel,
        chain: ChainModel
    ) {
        self.transferService = transferService
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriber = priceLocalSubscriber
        self.wallet = wallet
        self.chain = chain
    }

    private func subscribeToPrice(for chainAsset: ChainAsset) {
        if let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
            priceProvider = try? priceLocalSubscriber.subscribeToPrice(for: utilityAsset, listener: self)
        } else {
            priceProvider = try? priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
        }
    }

    private func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }
        return chainAsset
    }
}

// MARK: - NftSendConfirmInteractorInput

extension NftSendConfirmInteractor: NftSendConfirmInteractorInput {
    func setup(with output: NftSendConfirmInteractorOutput) {
        self.output = output

        if let chainAsset = chain.utilityChainAssets().first,
           let accountId = wallet.fetch(for: chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
            subscribeToPrice(for: chainAsset)
        }
    }

    func estimateFee(for nft: NFT, address: String?) {
        Task {
            do {
                let address = address ?? ""

                let transfer = NftTransfer(
                    nft: nft,
                    receiver: address,
                    value: 1
                )

                let fee = try await transferService.estimateFee(for: transfer)

                await MainActor.run(body: {
                    output?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
                })

                transferService.subscribeForFee(transfer: transfer, listener: self)
            } catch {
                await MainActor.run(body: {
                    output?.didReceiveFee(result: .failure(error))
                })
            }
        }
    }

    func submitExtrinsic(nft: NFT, receiverAddress: String) {
        Task {
            do {
                let transfer = NftTransfer(nft: nft, receiver: receiverAddress, value: 1)
                let txHash = try await transferService.submit(transfer: transfer)

                await MainActor.run {
                    output?.didTransfer(result: .success(txHash))
                }
            } catch {
                await MainActor.run {
                    output?.didTransfer(result: .failure(error))
                }
            }
        }
    }
}

extension NftSendConfirmInteractor: TransferFeeEstimationListener {
    func didReceiveFee(fee: BigUInt) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
        }
    }

    func didReceiveFeeError(feeError: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceiveFee(result: .failure(feeError))
        }
    }
}

extension NftSendConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Swift.Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension NftSendConfirmInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        output?.didReceivePriceData(result: result)
    }
}
