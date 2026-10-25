import Foundation

public enum TransferServiceError: Error {
    case accountNotExists
    case runtimeMetadaUnavailable
    case weakSelf
    case unexpectedWeb3Behaviour
    case transferFailed(reason: String)
    case cannotEstimateFee(reason: String)
    case unsubscribeFailed
}
