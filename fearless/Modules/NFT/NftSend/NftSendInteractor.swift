import UIKit
import RobinHood
import BigInt
import SSFModels

final class NftSendInteractor {
    // MARK: - Private properties

    private weak var output: NftSendInteractorOutput?
    private let transferService: NftTransferService
    private let operationManager: OperationManagerProtocol
    private let scamInfoFetching: ScamInfoFetching
    private let addressChainDefiner: AddressChainDefiner
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chain: ChainModel
    private let wallet: MetaAccountModel

    private var priceProvider: AnySingleValueProvider<[PriceData]>?

    init(
        transferService: NftTransferService,
        operationManager: OperationManagerProtocol,
        scamInfoFetching: ScamInfoFetching,
        addressChainDefiner: AddressChainDefiner,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        self.transferService = transferService
        self.operationManager = operationManager
        self.scamInfoFetching = scamInfoFetching
        self.addressChainDefiner = addressChainDefiner
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chain = chain
        self.wallet = wallet
    }

    private func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if let utilityAsset = chainAsset.chain.utilityChainAssets().first {
            return utilityAsset
        }
        return chainAsset
    }
}

// MARK: - NftSendInteractorInput

extension NftSendInteractor: NftSendInteractorInput {
    func setup(with output: NftSendInteractorOutput) {
        self.output = output

        if let chainAsset = chain.utilityChainAssets().first,
           let accountId = wallet.fetch(for: chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
            if let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
                priceProvider = priceLocalSubscriber.subscribeToPrice(for: utilityAsset, listener: self)
            } else {
                priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)
            }
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

    func fetchScamInfo(for address: String) {
        Task {
            let scamInfo = try await scamInfoFetching.fetch(address: address, chain: chain)
            output?.didReceive(scamInfo: scamInfo)
        }
    }

    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        addressChainDefiner.validate(address: address, for: chain)
    }
}

extension NftSendInteractor: TransferFeeEstimationListener {
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

extension NftSendInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Swift.Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        output?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension NftSendInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        output?.didReceivePriceData(result: result)
    }
}
