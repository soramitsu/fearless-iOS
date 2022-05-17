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

    var unavailbleStyle: ApplicationStatusStyle {
        ApplicationStatusStyle(
            backgroundColor: R.color.colorPink()!,
            titleColor: UIColor.white,
            titleFont: UIFont.h6Title
        )
    }

    var availableStyle: ApplicationStatusStyle {
        ApplicationStatusStyle(
            backgroundColor: R.color.colorGreen()!,
            titleColor: UIColor.white,
            titleFont: UIFont.h6Title
        )
    }
}

extension NetworkAvailabilityLayerPresenter: NetworkAvailabilityLayerInteractorOutputProtocol {
    func didDecideUnreachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.presentStatus(
            title: R.string.localizable
                .networkStatusConnecting(preferredLanguages: languages),
            style: unavailbleStyle,
            animated: true
        )
    }

    func didDecideReachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.dismissStatus(
            title: R.string.localizable
                .networkStatusConnected(preferredLanguages: languages),
            style: availableStyle,
            animated: true
        )
    }
}

extension NetworkAvailabilityLayerPresenter: Localizable {
    func applyLocalization() {}
}
