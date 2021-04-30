import UIKit
import SoraFoundation
import CommonWallet

final class StakingBMConfirmationVC: UIViewController, ViewHolder {
    typealias RootViewType = StakingBMConfirmationViewLayout

    let presenter: StakingBondMoreConfirmationPresenterProtocol

    var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .autoupdatingCurrent
    }

    init(
        presenter: StakingBondMoreConfirmationPresenterProtocol,
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
        view = StakingBMConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()
        presenter.setup()
    }
}

extension StakingBMConfirmationVC: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .commonConfirmTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.locale = selectedLocale
        }
    }
}

extension StakingBMConfirmationVC: StakingBondMoreConfirmationViewProtocol {}
