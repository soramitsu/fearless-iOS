import UIKit
import SoraFoundation

final class NetworkAvailabilityLayerPresenter {
    private var view: ApplicationStatusPresentable

    init(
        view: ApplicationStatusPresentable,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.view = view
        self.localizationManager = localizationManager
    }
}

extension NetworkAvailabilityLayerPresenter: NetworkAvailabilityLayerInteractorOutputProtocol {
    func didDecideUnreachableStatusPresentation() {
        view.presentStatus(
            with: .connectionOffline(locale: selectedLocale),
            animated: true
        )
    }

    func didDecideReachableStatusPresentation() {
        view.dismissStatus(
            with: .connectionOnline(locale: selectedLocale),
            animated: true
        )
    }
}

extension NetworkAvailabilityLayerPresenter: Localizable {
    func applyLocalization() {}
}
