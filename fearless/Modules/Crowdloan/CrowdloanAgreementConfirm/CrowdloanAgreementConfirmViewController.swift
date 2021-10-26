import UIKit
import SoraFoundation

final class CrowdloanAgreementConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanAgreementConfirmViewLayout

    let presenter: CrowdloanAgreementConfirmPresenterProtocol

    init(presenter: CrowdloanAgreementConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanAgreementConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirm(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale
    }
}

extension CrowdloanAgreementConfirmViewController: CrowdloanAgreementConfirmViewProtocol {}

extension CrowdloanAgreementConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
