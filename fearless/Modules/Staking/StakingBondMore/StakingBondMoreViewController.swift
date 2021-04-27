import UIKit
import SoraFoundation

final class StakingBondMoreViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingBondMoreViewLayout

    let presenter: StakingBondMorePresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingBondMorePresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingBalanceViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        presenter.setup()
    }
}

extension StakingBondMoreViewController: StakingBondMoreViewProtocol {
    func reload(with _: LocalizableResource<String>) {
        // TODO:
    }
}

extension StakingBondMoreViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            // TODO:
        }
    }
}
