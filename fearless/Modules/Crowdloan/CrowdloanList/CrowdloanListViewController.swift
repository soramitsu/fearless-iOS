import UIKit
import SoraFoundation

final class CrowdloanListViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanListViewLayout

    let presenter: CrowdloanListPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    init(presenter: CrowdloanListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages
        title = R.string.localizable.tabbarCrowdloanTitle(preferredLanguages: languages)
    }
}

extension CrowdloanListViewController: CrowdloanListViewProtocol {}

extension CrowdloanListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
