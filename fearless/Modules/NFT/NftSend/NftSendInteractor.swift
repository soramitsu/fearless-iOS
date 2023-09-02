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

    init(
        transferService: NftTransferService,
        operationManager: OperationManagerProtocol,
        scamServiceOperationFactory: ScamServiceOperationFactoryProtocol,
        addressChainDefiner: AddressChainDefiner
    ) {
        self.transferService = transferService
        self.operationManager = operationManager
        self.scamServiceOperationFactory = scamServiceOperationFactory
        self.addressChainDefiner = addressChainDefiner
    }
}

// MARK: - NftSendInteractorInput

extension NftSendInteractor: NftSendInteractorInput {
    func setup(with output: NftSendInteractorOutput) {
        self.output = output
    }

    func estimateFee(for nft: NFT, address: String?) {
        Task {
            do {
                let address = address ?? ""

                let transfer = NftTransfer(
                    nft: nft,
                    receiver: address
                )

                let fee = try await transferService.estimateFee(for: transfer)

                await MainActor.run(body: {
                    output?.didReceiveFee(result: .success(RuntimeDispatchInfo(inclusionFee: FeeDetails(baseFee: fee, lenFee: .zero, adjustedWeightFee: .zero))))
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
            self?.output?.didReceiveFee(result: .success(RuntimeDispatchInfo(inclusionFee: FeeDetails(baseFee: fee, lenFee: .zero, adjustedWeightFee: .zero))))
        }
    }

    func didReceiveFeeError(feeError: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceiveFee(result: .failure(feeError))
        }
    }
}
