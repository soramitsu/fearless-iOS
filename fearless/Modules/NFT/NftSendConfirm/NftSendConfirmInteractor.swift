import UIKit
import BigInt

final class NftSendConfirmInteractor {
    // MARK: - Private properties

    private weak var output: NftSendConfirmInteractorOutput?
    private let transferService: NftTransferService

    init(
        transferService: NftTransferService
    ) {
        self.transferService = transferService
    }
}

// MARK: - NftSendConfirmInteractorInput

extension NftSendConfirmInteractor: NftSendConfirmInteractorInput {
    func setup(with output: NftSendConfirmInteractorOutput) {
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

    func submitExtrinsic(nft: NFT, receiverAddress: String) {
        Task {
            do {
                let transfer = NftTransfer(nft: nft, receiver: receiverAddress)
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
            self?.output?.didReceiveFee(result: .success(RuntimeDispatchInfo(inclusionFee: FeeDetails(baseFee: fee, lenFee: .zero, adjustedWeightFee: .zero))))
        }
    }

    func didReceiveFeeError(feeError: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.didReceiveFee(result: .failure(feeError))
        }
    }
}
