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
    let settings: SettingsManagerProtocol

    init(webSocketService: WebSocketServiceProtocol,
         runtimeService: RuntimeRegistryServiceProtocol,
         validatorService: EraValidatorServiceProtocol,
         gitHubPhishingAPIService: ApplicationServiceProtocol,
         settings: SettingsManagerProtocol) {
        self.webSocketService = webSocketService
        self.runtimeService = runtimeService
        self.validatorService = validatorService
        self.gitHubPhishingAPIService = gitHubPhishingAPIService
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
}

extension ServiceCoordinator: ServiceCoordinatorProtocol {
    func updateOnAccountChange() {
        updateWebSocketSettings()
        updateRuntimeService()
        updateValidatorService()
    }

    func updateOnNetworkChange() {
        updateWebSocketSettings()
        updateRuntimeService()
        updateValidatorService()
    }

    func setup() {
        webSocketService.setup()
        runtimeService.setup()

        if let engine = webSocketService.connection {
            let chain = settings.selectedConnection.type.chain
            validatorService.update(to: chain, engine: engine)
            validatorService.setup()
        }

        gitHubPhishingAPIService.setup()
    }

    func throttle() {
        webSocketService.throttle()
        runtimeService.throttle()
        validatorService.throttle()
        gitHubPhishingAPIService.throttle()
    }
}

extension ServiceCoordinator {
    static func createDefault() -> ServiceCoordinatorProtocol {
        let webSocketService = WebSocketServiceFactory.createService()
        let runtimeService = RuntimeRegistryFacade.sharedService
        let gitHubPhishingAPIService = GitHubPhishingServiceFactory.createService()
        let validatorService = EraValidatorFactory.createService(runtime: runtimeService)

        return ServiceCoordinator(webSocketService: webSocketService,
                                  runtimeService: runtimeService,
                                  validatorService: validatorService,
                                  gitHubPhishingAPIService: gitHubPhishingAPIService,
                                  settings: SettingsManager.shared)
    }
}
