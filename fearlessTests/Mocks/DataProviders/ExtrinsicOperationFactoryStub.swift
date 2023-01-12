//@testable import fearless
//import RobinHood
//
//final class ExtrinsicOperationFactoryStub: ExtrinsicOperationFactoryProtocol {
//    func createGenesisBlockHashOperation() -> BaseOperation<String> {
//        return BaseOperation()
//    }
//    
//    func submit(
//        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
//        signer: SigningWrapperProtocol,
//        numberOfExtrinsics: Int
//    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]> {
//        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)
//
//        return CompoundOperationWrapper.createWithResult([.success(txHash)])
//    }
//    
//    func submitAndWatch(
//        _ closure: @escaping ExtrinsicBuilderClosure,
//        signer: SigningWrapperProtocol
//    ) -> CompoundOperationWrapper<SubmitAndWatchExtrinsicResult> {
//        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)
//        
//        return CompoundOperationWrapper.createWithResult((.success(txHash), nil))
//    }
//
//    func estimateFeeOperation(
//        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
//        numberOfExtrinsics: Int
//    ) -> CompoundOperationWrapper<[FeeExtrinsicResult]> {
//        let dispatchInfo = RuntimeDispatchInfo(dispatchClass: "Extrinsic",
//                                               fee: "10000000000",
//                                               weight: 10005000)
//
//        return CompoundOperationWrapper.createWithResult([.success(dispatchInfo)])
//    }
//}
