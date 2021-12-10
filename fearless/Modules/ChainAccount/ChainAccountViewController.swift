import UIKit
import SoraFoundation

final class ChainAccountViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChainAccountViewLayout

    let presenter: ChainAccountPresenterProtocol

    private var state: ChainAccountViewState = .loading

    init(presenter: ChainAccountPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChainAccountViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )
    }

    private func applyState() {
        switch state {
        case .loading:
            break
        case let .loaded(viewModel):
            rootView.balanceView.bind(to: viewModel.accountBalanceViewModel)
            rootView.assetInfoView.bind(to: viewModel.assetInfoViewModel)
        case .error:
            break
        }
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }
}

extension ChainAccountViewController: ChainAccountViewProtocol {
    func didReceiveState(_ state: ChainAccountViewState) {
        self.state = state
        applyState()
    }
}

extension ChainAccountViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ChainAccountViewController: HiddableBarWhenPushed {}
