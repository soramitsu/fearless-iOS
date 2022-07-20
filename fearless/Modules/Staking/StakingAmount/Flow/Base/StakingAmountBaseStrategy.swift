import Foundation

protocol StakingAmountBaseStrategyOutput {}

class StakingAmountBaseStrategy: StakingAmountStrategy {
    let eraInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol

    func setup() {
        provideNetworkStakingInfo()
    }

    private func provideNetworkStakingInfo() {
        let wrapper = eraInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(networkStakingInfo: info)
                } catch {
                    self?.presenter?.didReceive(networkStakingInfoError: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}
