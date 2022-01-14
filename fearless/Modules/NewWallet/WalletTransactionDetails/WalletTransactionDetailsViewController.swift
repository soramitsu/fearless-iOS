import UIKit
import CommonWallet

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
}

extension WalletTransactionDetailsViewController: WalletTransactionDetailsViewProtocol {
    func didReceiveState(_ state: WalletTransactionDetailsViewState) {
        self.state = state
        applyState(state)
    }
}
