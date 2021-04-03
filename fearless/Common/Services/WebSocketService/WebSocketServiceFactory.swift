import Foundation
import SoraFoundation

final class WebSocketServiceFactory {
    static func createService() -> WebSocketServiceProtocol {
        let localizationManager = LocalizationManager.shared
        let webSocketService = WebSocketService.shared
        webSocketService.networkStatusPresenter =
            createNetworkStatusPresenter(localizationManager: localizationManager)

        return webSocketService
    }

    static func createNetworkStatusPresenter(
        localizationManager: LocalizationManagerProtocol
    ) -> NetworkAvailabilityLayerInteractorOutputProtocol? {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return nil
        }

        let prenseter = NetworkAvailabilityLayerPresenter()
        prenseter.localizationManager = localizationManager
        prenseter.view = window

        return prenseter
    }
}
