import UIKit
import SoraFoundation

class RootViewController: UIViewController, ViewHolder {
    typealias RootViewType = RootViewLayout

    let presenter: RootPresenterProtocol

    init(presenter: RootPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RootViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension RootViewController: RootViewProtocol {}

extension RootViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
