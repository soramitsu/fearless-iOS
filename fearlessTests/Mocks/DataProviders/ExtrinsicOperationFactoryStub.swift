import Foundation
@testable import fearless
import RobinHood
import BigInt

final class ExtrinsicOperationFactoryStub: ExtrinsicOperationFactoryProtocol {
    func createGenesisBlockHashOperation() -> BaseOperation<String> {
        return BaseOperation()
    }
    
    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]> {
        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)

        return CompoundOperationWrapper.createWithResult([.success(txHash)])
    }
    
    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<SubmitAndWatchExtrinsicResult> {
        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)
        
        return CompoundOperationWrapper.createWithResult((.success(txHash), nil))
    }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[FeeExtrinsicResult]> {
        let feeValue = BigUInt(stringLiteral: "10000005000")
        let dispatchInfo = RuntimeDispatchInfo(feeValue: feeValue)

        return CompoundOperationWrapper.createWithResult([.success(dispatchInfo)])
    }
}
