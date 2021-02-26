import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import IrohaCrypto

protocol ServiceCoordinatorProtocol: ApplicationServiceProtocol {
    func updateOnAccountChange()
    func updateOnNetworkChange()
}

final class ServiceCoordinator {
    let webSocketService: WebSocketServiceProtocol
    let runtimeService: RuntimeRegistryServiceProtocol
    let validatorService: EraValidatorServiceProtocol
    let gitHubPhishingAPIService: ApplicationServiceProtocol
    let rewardCalculatorService: RewardCalculatorServiceProtocol
    let settings: SettingsManagerProtocol

    init(webSocketService: WebSocketServiceProtocol,
         runtimeService: RuntimeRegistryServiceProtocol,
         validatorService: EraValidatorServiceProtocol,
         gitHubPhishingAPIService: ApplicationServiceProtocol,
         rewardCalculatorService: RewardCalculatorServiceProtocol,
         settings: SettingsManagerProtocol) {
        self.webSocketService = webSocketService
        self.runtimeService = runtimeService
        self.validatorService = validatorService
        self.gitHubPhishingAPIService = gitHubPhishingAPIService
        self.rewardCalculatorService = rewardCalculatorService
        self.settings = settings
    }

    private func updateWebSocketSettings() {
        let connectionItem = settings.selectedConnection
        let account = settings.selectedAccount

        let settings = WebSocketServiceSettings(url: connectionItem.url,
                                                addressType: connectionItem.type,
                                                address: account?.address)
        webSocketService.update(settings: settings)
    }

    private func updateRuntimeService() {
        let connectionItem = settings.selectedConnection
        runtimeService.update(to: connectionItem.type.chain)
    }

    private func updateValidatorService() {
        if let engine = webSocketService.connection {
            let chain = settings.selectedConnection.type.chain
            validatorService.update(to: chain, engine: engine)
        }
    }

    private func updateRewardCalculatorService() {
        let chain = settings.selectedConnection.type.chain
        rewardCalculatorService.update(to: chain)
    }
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        updateWebSocketSettings()
        updateRuntimeService()
        updateValidatorService()
        updateRewardCalculatorService()
    }

    func updateOnNetworkChange() {
        updateWebSocketSettings()
        updateRuntimeService()
        updateValidatorService()
        updateRewardCalculatorService()
    }

    func setup() {
        webSocketService.setup()
        runtimeService.setup()

        let chain = settings.selectedConnection.type.chain

        if let engine = webSocketService.connection {
            validatorService.update(to: chain, engine: engine)
            validatorService.setup()
        }

        gitHubPhishingAPIService.setup()

        rewardCalculatorService.update(to: chain)
        rewardCalculatorService.setup()

        let validatorsOperation = validatorService.fetchInfoOperation()
        let calculatorOperation = rewardCalculatorService.fetchCalculatorOperation()

        let mapOperation: BaseOperation<[(String, Decimal)]> = ClosureOperation {
            let info = try validatorsOperation.extractNoCancellableResultData()
            let calculator = try calculatorOperation.extractNoCancellableResultData()

            let factory = SS58AddressFactory()

            let rewards: [(String, Decimal)] = try info.validators.map { validator in
                let reward = calculator.calculateForValidator(accountId: validator.accountId)

                let address = try factory.address(fromPublicKey: AccountIdWrapper(rawData: validator.accountId),
                                                  type: chain.addressType)
                return (address, reward * 100.0)
            }

            return rewards
        }

        mapOperation.addDependency(validatorsOperation)
        mapOperation.addDependency(calculatorOperation)

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let result = try mapOperation.extractNoCancellableResultData()
                    Logger.shared.warning("Reward: \(result)")
                } catch {
                    Logger.shared.error("Did receive error: \(error)")
                }
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [validatorsOperation, calculatorOperation, mapOperation],
                                                     in: .transient)
    }

    func throttle() {
        webSocketService.throttle()
        runtimeService.throttle()
        validatorService.throttle()
        gitHubPhishingAPIService.throttle()
        rewardCalculatorService.throttle()
    }
}

extension ServiceCoordinator {
    static func createDefault() -> ServiceCoordinatorProtocol {
        let webSocketService = WebSocketServiceFactory.createService()
        let runtimeService = RuntimeRegistryFacade.sharedService
        let gitHubPhishingAPIService = GitHubPhishingServiceFactory.createService()
        let validatorService = EraValidatorFactory.createService(runtime: runtimeService)
        let rewardCalculatorService = RewardCalculatorServiceFactory.createService(runtime: runtimeService,
                                                                                   validators: validatorService)

        return ServiceCoordinator(webSocketService: webSocketService,
                                  runtimeService: runtimeService,
                                  validatorService: validatorService,
                                  gitHubPhishingAPIService: gitHubPhishingAPIService,
                                  rewardCalculatorService: rewardCalculatorService,
                                  settings: SettingsManager.shared)
    }
}
