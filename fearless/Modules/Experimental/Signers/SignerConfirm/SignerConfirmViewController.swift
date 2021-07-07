import UIKit
import SoraFoundation
import SoraUI

final class SignerConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = SignerConfirmViewLayout

    let presenter: SignerConfirmPresenterProtocol

    init(presenter: SignerConfirmPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SignerConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        presenter.setup()
    }

    private func configure() {
        rootView.confirmView.actionButton.addTarget(self, action: #selector(actionConfirm), for: .touchUpInside)

        rootView.extrinsicView.isHidden = true
        rootView.extrinsicToggle.addTarget(self, action: #selector(actionTxToggle), for: .valueChanged)

        rootView.accountView.addTarget(self, action: #selector(actionSelectAccount), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable.commonConfirm(preferredLanguages: selectedLocale.rLanguages)
        rootView.locale = selectedLocale
    }

    @objc private func actionConfirm() {
        presenter.confirm()
    }

    @objc private func actionTxToggle() {
        rootView.extrinsicView.isHidden = !rootView.extrinsicToggle.isActivated
    }

    @objc private func actionSelectAccount() {
        presenter.presentAccountOptions()
    }
}

extension SignerConfirmViewController: SignerConfirmViewProtocol {
    func didReceiveCall(viewModel: SignerConfirmCallViewModel) {
        rootView.accountView.subtitle = viewModel.accountName
        rootView.accountView.iconImage = viewModel.accountIcon.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        rootView.moduleView.valueLabel.text = viewModel.moduleName
        rootView.callView.valueLabel.text = viewModel.callName

        if let amount = viewModel.amount {
            rootView.insertAmountViewIfNeeded()

            rootView.amountView?.bind(viewModel: amount)
        } else {
            rootView.removeAmountViewIfNeeded()
        }

        rootView.extrinsicView.subtitleLabel.text = viewModel.extrinsicString

        rootView.extrinsicView.invalidateLayout()
        rootView.extrinsicView.setNeedsLayout()
    }

    func didReceiveFee(viewModel: SignerConfirmFeeViewModel) {
        rootView.feeView.bind(viewModel: viewModel.fee)
        rootView.confirmView.networkFeeView.bind(viewModel: viewModel.total)
    }
}

extension SignerConfirmViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
