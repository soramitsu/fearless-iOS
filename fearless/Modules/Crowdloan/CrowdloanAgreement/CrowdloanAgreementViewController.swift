import UIKit
import SoraFoundation

final class CrowdloanAgreementViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanAgreementViewLayout

    private var agreementViewModel: CrowdloanAgreementViewModel?
    private var state: CrowdloanAgreementState = .loading

    let presenter: CrowdloanAgreementPresenterProtocol

    init(
        presenter: CrowdloanAgreementPresenterProtocol,
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
        view = CrowdloanAgreementViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        presenter.setup()

        title = "Moonbeam (GLMR)"
    }

    private func configure() {
        rootView.termsSwitchView.addTarget(self, action: #selector(actionSwitchTerms), for: .valueChanged)
        rootView.confirmAgreementButton.addTarget(self, action: #selector(actionConfirmAgreement), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable.commonBonus(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale

        applyAgreementViewModel()
    }

    @objc private func actionSwitchTerms() {
        presenter.setTermsAgreed(value: rootView.termsSwitchView.isOn)
    }

    @objc private func actionConfirmAgreement() {
        presenter.confirmAgreement()
    }

    private func applyAgreementViewModel() {
        guard let agreementViewModel = agreementViewModel else {
            return
        }

        rootView.textView.text = agreementViewModel.agreementText
        rootView.titleLabel.text = agreementViewModel.title
        rootView.confirmAgreementButton.isEnabled = agreementViewModel.isTermsAgreed

        if agreementViewModel.isTermsAgreed {
            rootView.confirmAgreementButton.applyDefaultStyle()
        } else {
            rootView.confirmAgreementButton.applyDisabledStyle()
        }
    }

    private func applyState() {
        switch state {
        case .loading:
            rootView.confirmAgreementButton.isEnabled = false
            rootView.confirmAgreementButton.applyDisabledStyle()

            rootView.contentView.isHidden = true
            didStartLoading()
        case let .loaded(viewModel):
            agreementViewModel = viewModel
            didStopLoading()
            rootView.contentView.isHidden = false

            applyAgreementViewModel()
        case .error:
            rootView.confirmAgreementButton.isEnabled = false
            rootView.confirmAgreementButton.applyDisabledStyle()

            didStopLoading()
            rootView.contentView.isHidden = true
        }
    }
}

extension CrowdloanAgreementViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension CrowdloanAgreementViewController: CrowdloanAgreementViewProtocol {
    func didReceive(state: CrowdloanAgreementState) {
        self.state = state

        applyState()
    }
}

extension CrowdloanAgreementViewController: LoadableViewProtocol {}
