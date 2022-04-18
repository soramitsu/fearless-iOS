import UIKit
import SoraFoundation

final class ChainAccountViewController: UIViewController, ViewHolder {
    enum Constants {
        static let defaultContentHeight: CGFloat = 450
    }

    typealias RootViewType = ChainAccountViewLayout

    let presenter: ChainAccountPresenterProtocol

    private var state: ChainAccountViewState = .loading

    var observable = ViewModelObserverContainer<ContainableObserver>()

    weak var reloadableDelegate: ReloadableDelegate?

    var contentInsets: UIEdgeInsets = .zero

    lazy var preferredContentHeight: CGFloat = Constants.defaultContentHeight

    init(
        presenter: ChainAccountPresenterProtocol,
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

        rootView.optionsButton.addTarget(self, action: #selector(optionsButtonClicked), for: .touchUpInside)
        rootView.sendButton.addTarget(self, action: #selector(sendButtonClicked), for: .touchUpInside)
        rootView.receiveButton.addTarget(self, action: #selector(receiveButtonClicked), for: .touchUpInside)
        rootView.buyButton.addTarget(self, action: #selector(buyButtonClicked), for: .touchUpInside)
        rootView.balanceView.lockedView.button
            .addTarget(self, action: #selector(lockedInfoButtonClicked), for: .touchUpInside)
    }

    private func applyState() {
        switch state {
        case .loading:
            break
        case let .loaded(viewModel):
            rootView.balanceView.bind(to: viewModel.accountBalanceViewModel)
            rootView.assetInfoView.bind(to: viewModel.assetInfoViewModel)
            rootView.buyButton.isEnabled = viewModel.chainAsset?.purchaseProviders?.first != nil
        case .error:
            break
        }
    }

    @objc private func backButtonClicked() {
        presenter.didTapBackButton()
    }

    @objc private func sendButtonClicked() {
        presenter.didTapSendButton()
    }

    @objc private func receiveButtonClicked() {
        presenter.didTapReceiveButton()
    }

    @objc private func buyButtonClicked() {
        presenter.didTapBuyButton()
    }

    @objc private func lockedInfoButtonClicked() {
        presenter.didTapInfoButton()
    }

    @objc private func optionsButtonClicked() {
        presenter.didTapOptionsButton()
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

extension ChainAccountViewController: Containable {
    var contentView: UIView {
        view
    }

    func setContentInsets(_: UIEdgeInsets, animated _: Bool) {}
}
