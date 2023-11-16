import UIKit
import RobinHood
import BigInt
import SSFModels

final class NftSendInteractor {
    // MARK: - Private properties

    private weak var output: NftSendInteractorOutput?
    private let transferService: NftTransferService
    private let operationManager: OperationManagerProtocol
    private let scamServiceOperationFactory: ScamServiceOperationFactoryProtocol
    private let addressChainDefiner: AddressChainDefiner
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let chain: ChainModel
    private let wallet: MetaAccountModel

    init(
        transferService: NftTransferService,
        operationManager: OperationManagerProtocol,
        scamServiceOperationFactory: ScamServiceOperationFactoryProtocol,
        addressChainDefiner: AddressChainDefiner,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) {
        self.transferService = transferService
        self.operationManager = operationManager
        self.scamServiceOperationFactory = scamServiceOperationFactory
        self.addressChainDefiner = addressChainDefiner
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.chain = chain
        self.wallet = wallet
    }
}

// MARK: - NftSendInteractorInput

extension NftSendInteractor: NftSendInteractorInput {
    func setup(with output: NftSendInteractorOutput) {
        self.output = output

        if let chainAsset = chain.utilityChainAssets().first,
           let accountId = wallet.fetch(for: chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
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
        let allOperation = scamServiceOperationFactory.fetchScamInfoOperation(for: address)

        allOperation.completionBlock = { [weak self] in
            guard let result = allOperation.result else {
                return
            }

            switch result {
            case let .success(scamInfo):
                DispatchQueue.main.async {
                    self?.output?.didReceive(scamInfo: scamInfo)
                }
            case .failure:
                break
            }
        }
        operationManager.enqueue(operations: [allOperation], in: .transient)
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
