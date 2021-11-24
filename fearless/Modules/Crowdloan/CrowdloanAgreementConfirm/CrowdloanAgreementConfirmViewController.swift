import UIKit
import SoraFoundation

final class CrowdloanAgreementConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanAgreementConfirmViewLayout

    let presenter: CrowdloanAgreementConfirmPresenterProtocol
    private var viewState: CrowdloanAgreementConfirmViewState = .normal

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
        configure()

        presenter.setup()
    }

    private func configure() {
        rootView.networkFeeConfirmView.actionButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirm(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale
    }

    @objc private func actionConfirm() {
        presenter.confirmAgreement()
    }

    private func applyState() {
        switch viewState {
        case .normal:
            rootView.networkFeeConfirmView.actionButton.set(loading: false)
        case .confirmLoading:
            rootView.networkFeeConfirmView.actionButton.set(loading: true)
        }
    }
}

extension CrowdloanAgreementConfirmViewController: CrowdloanAgreementConfirmViewProtocol {
    func didReceive(state: CrowdloanAgreementConfirmViewState) {
        viewState = state
        applyState()
    }

    func didReceiveFee(viewModel: BalanceViewModelProtocol?) {
        rootView.bind(feeViewModel: viewModel)
    }

    func didReceiveAccount(viewModel: CrowdloanAccountViewModel?) {
        rootView.bind(accountViewModel: viewModel)
    }
}

extension CrowdloanAgreementConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
