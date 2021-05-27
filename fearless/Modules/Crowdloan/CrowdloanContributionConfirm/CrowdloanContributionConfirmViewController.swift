import UIKit
import SoraFoundation

final class CrowdloanContributionConfirmVC: UIViewController {
    typealias RootViewType = CrowdloanContributionConfirmViewLayout

    let presenter: CrowdloanContributionConfirmPresenterProtocol

    init(
        presenter: CrowdloanContributionConfirmPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
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
        view = CrowdloanContributionConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirmationTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension CrowdloanContributionConfirmVC: CrowdloanContributionConfirmViewProtocol {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
