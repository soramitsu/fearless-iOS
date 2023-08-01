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
        let feeDetails = FeeDetails(
            baseFee: BigUInt(stringLiteral: "10000000000"),
            lenFee: BigUInt(stringLiteral: "0"),
            adjustedWeightFee: BigUInt(stringLiteral: "10005000")
        )
        let dispatchInfo = RuntimeDispatchInfo(inclusionFee: feeDetails)

        return CompoundOperationWrapper.createWithResult([.success(dispatchInfo)])
    }
}
