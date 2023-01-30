import Foundation
import SoraFoundation

final class WebSocketServiceFactory {
    static func createNetworkStatusPresenter(
        localizationManager: LocalizationManagerProtocol
    ) -> NetworkAvailabilityLayerInteractorOutputProtocol? {
        guard let window = UIApplication.shared.keyWindow as? ApplicationStatusPresentable else {
            return nil
        }

        let prenseter = NetworkAvailabilityLayerPresenter(
            view: window,
            localizationManager: localizationManager
        )

        return prenseter
    }
}
