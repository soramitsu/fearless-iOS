import UIKit
import SoraFoundation

final class StoriesViewController: UIViewController, ControllerBackedProtocol {
    var presenter: StoriesPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
    }
}

extension StoriesViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        // Localize static UI elements here
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StoriesViewController: StoriesViewProtocol {

}
