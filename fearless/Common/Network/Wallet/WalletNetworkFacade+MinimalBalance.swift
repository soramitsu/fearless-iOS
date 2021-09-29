import RobinHood
import BigInt

extension WalletNetworkFacade {
    func fetchMinimalBalanceOperation() -> CompoundOperationWrapper<BigUInt> {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<BigUInt>(path: .existentialDeposit)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: constOperation,
            dependencies: [codingFactoryOperation]
        )
    }
}
