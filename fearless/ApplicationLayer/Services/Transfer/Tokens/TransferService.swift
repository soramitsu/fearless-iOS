import Foundation
import SSFModels
import SSFExtrinsicKit
import SSFUtils
import BigInt

protocol TransferFeeEstimationListener: AnyObject {
    func didReceiveFee(fee: BigUInt)
    func didReceiveFeeError(feeError: Error)
}

enum TransferServiceError: Error {
    case cannotEstimateFee(reason: String)
    case transferFailed(reason: String)
    case unexpected
}

struct Transfer {
    let chainAsset: ChainAsset
    let amount: BigUInt
    let receiver: String
    let tip: BigUInt?
}

protocol TransferServiceProtocol {
    func estimateFee(for transfer: Transfer) async throws -> BigUInt
    func submit(transfer: Transfer) async throws -> String
    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener)
    func unsubscribe()

    func estimateFee(for transfer: XorlessTransfer) async throws -> BigUInt
    func submit(transfer: XorlessTransfer) async throws -> String
}

extension TransferServiceProtocol {
    func estimateFee(for _: XorlessTransfer) async throws -> BigUInt { .zero }
    func submit(transfer _: XorlessTransfer) async throws -> String { "" }
}
