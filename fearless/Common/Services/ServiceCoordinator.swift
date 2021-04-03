import Foundation
import SoraKeystore
import SoraFoundation

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

    init(
        webSocketService: WebSocketServiceProtocol,
        runtimeService: RuntimeRegistryServiceProtocol,
        validatorService: EraValidatorServiceProtocol,
        gitHubPhishingAPIService: ApplicationServiceProtocol,
        rewardCalculatorService: RewardCalculatorServiceProtocol,
        settings: SettingsManagerProtocol
    ) {
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

        let settings = WebSocketServiceSettings(
            url: connectionItem.url,
            addressType: connectionItem.type,
            address: account?.address
        )
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
        let validatorService = EraValidatorFacade.sharedService
        let rewardCalculatorService = RewardCalculatorFacade.sharedService

        return ServiceCoordinator(
            webSocketService: webSocketService,
            runtimeService: runtimeService,
            validatorService: validatorService,
            gitHubPhishingAPIService: gitHubPhishingAPIService,
            rewardCalculatorService: rewardCalculatorService,
            settings: SettingsManager.shared
        )
    }
}
