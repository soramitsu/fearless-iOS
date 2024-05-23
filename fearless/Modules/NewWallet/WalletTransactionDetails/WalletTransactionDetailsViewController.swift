import UIKit

import SoraFoundation

final class WalletTransactionDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletTransactionDetailsViewLayout

    let presenter: WalletTransactionDetailsPresenterProtocol
    private var state: WalletTransactionDetailsViewState = .loading

    init(presenter: WalletTransactionDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletTransactionDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.navigationTitleLabel.text = R.string.localizable.commonDetails(preferredLanguages: selectedLocale.rLanguages)

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        rootView.senderView.addTarget(
            self,
            action: #selector(senderAccountViewClicked),
            for: .touchUpInside
        )

        rootView.receiverView.addTarget(
            self,
            action: #selector(receiverOrValidatorAccountViewClicked),
            for: .touchUpInside
        )

        rootView.extrinsicHashView.addTarget(
            self,
            action: #selector(extrinsicViewClicked),
            for: .touchUpInside
        )
    }

    private func applyState(_ state: WalletTransactionDetailsViewState) {
        switch state {
        case .loading:
            rootView.contentView.isHidden = true
        case let .loaded(viewModel):
            rootView.contentView.isHidden = false
            rootView.bind(to: viewModel)
        case .empty:
            rootView.contentView.isHidden = true
        }
    }

    @objc func closeButtonClicked() {
        presenter.didTapCloseButton()
    }

    @objc func receiverOrValidatorAccountViewClicked() {
        presenter.didTapReceiverOrValidatorView()
    }

    @objc func senderAccountViewClicked() {
        presenter.didTapSenderView()
    }

    @objc func extrinsicViewClicked() {
        presenter.didTapExtrinsicView()
    }
}

extension WalletTransactionDetailsViewController: WalletTransactionDetailsViewProtocol {
    func didReceiveState(_ state: WalletTransactionDetailsViewState) {
        self.state = state
        applyState(state)
    }
}

extension WalletTransactionDetailsViewController: Localizable {
    func applyLocalization() {}
}
