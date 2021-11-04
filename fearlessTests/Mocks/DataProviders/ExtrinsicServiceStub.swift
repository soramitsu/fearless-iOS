import Foundation
@testable import fearless

final class ExtrinsicServiceStub: ExtrinsicServiceProtocol {
    let dispatchInfo: Result<RuntimeDispatchInfo, Error>
    let txHash: Result<String, Error>

    init(dispatchInfo: Result<RuntimeDispatchInfo, Error>, txHash: Result<String, Error>) {
        self.dispatchInfo = dispatchInfo
        self.txHash = txHash
    }

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        queue.async {
            completionClosure(self.dispatchInfo)
        }
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        queue.async {
            completionClosure(self.txHash)
        }
    }
    
    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        queue.async {
            completionClosure(self.txHash, nil)
        }
    }

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        completionClosure([self.dispatchInfo])
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        completionClosure([self.txHash])
    }
}

extension ExtrinsicServiceStub {
    static func dummy() -> ExtrinsicServiceStub {
        let dispatchInfo = RuntimeDispatchInfo(dispatchClass: "Extrinsic",
                                               fee: "10000000000",
                                               weight: 10005000)

        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)
        return ExtrinsicServiceStub(dispatchInfo: .success(dispatchInfo), txHash: .success(txHash))
    }
}
