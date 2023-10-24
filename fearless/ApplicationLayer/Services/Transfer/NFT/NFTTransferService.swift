import Foundation
import BigInt

struct NftTransfer {
    let nft: NFT
    let receiver: String
}

protocol NftTransferService {
    func estimateFee(for transfer: NftTransfer) async throws -> BigUInt
    func submit(transfer: NftTransfer) async throws -> String
    func subscribeForFee(transfer: NftTransfer, listener: TransferFeeEstimationListener)
}
