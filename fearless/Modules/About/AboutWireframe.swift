import UIKit

final class AboutWireframe: AboutWireframeProtocol {
    func showFontLicenses(from view: AboutViewProtocol, locale: Locale) {
        let controller = FontLicensesViewController(locale: locale)
        view.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
