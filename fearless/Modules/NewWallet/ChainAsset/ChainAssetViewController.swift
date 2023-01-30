import UIKit
import SoraFoundation

final class ChainAssetViewController: UIViewController, ViewHolder {
    enum Constants {
        static let defaultContentHeight: CGFloat = 270
    }

    typealias RootViewType = ChainAssetViewLayout

    let presenter: ChainAssetPresenterProtocol

    private var state: ChainAccountViewState = .loading
    private let balanceInfoViewController: UIViewController

    var observable = ViewModelObserverContainer<ContainableObserver>()

    weak var reloadableDelegate: ReloadableDelegate?

    var contentInsets: UIEdgeInsets = .zero

    lazy var preferredContentHeight: CGFloat = Constants.defaultContentHeight

    init(
        presenter: ChainAssetPresenterProtocol,
        balanceInfoViewController: UIViewController,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.balanceInfoViewController = balanceInfoViewController
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChainAssetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupEmbededBalanceView()

        rootView.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )

        rootView.optionsButton.addTarget(self, action: #selector(optionsButtonClicked), for: .touchUpInside)
        rootView.sendButton.addTarget(self, action: #selector(sendButtonClicked), for: .touchUpInside)
        rootView.receiveButton.addTarget(self, action: #selector(receiveButtonClicked), for: .touchUpInside)
        rootView.buyButton.addTarget(self, action: #selector(buyButtonClicked), for: .touchUpInside)
        rootView.selectNetworkButton.addTarget(self, action: #selector(selectNetworkButtonClicked), for: .touchUpInside)
        rootView.addressCopyableLabel.onСopied = { [weak self] in
            self?.presenter.addressDidCopied()
        }
        rootView.polkaswapButton.addTarget(self, action: #selector(polkaswapButtonClicked), for: .touchUpInside)
        presenter.setup()
    }

    private func setupEmbededBalanceView() {
        addChild(balanceInfoViewController)

        guard let view = balanceInfoViewController.view else {
            return
        }
        rootView.walletBalanceViewContainer.addSubview(view)
        view.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalToSuperview()
            make.width.equalToSuperview()
        }

        controller.didMove(toParent: self)
    }

    private func applyState() {
        switch state {
        case .loading:
            break
        case let .loaded(viewModel):
            rootView.bind(viewModel: viewModel)
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

    @objc private func optionsButtonClicked() {
        presenter.didTapOptionsButton()
    }

    @objc private func selectNetworkButtonClicked() {
        presenter.didTapSelectNetwork()
    }

    @objc private func polkaswapButtonClicked() {
        presenter.didTapPolkaswapButton()
    }
}

extension ChainAssetViewController: ChainAssetViewProtocol {
    func didReceiveState(_ state: ChainAccountViewState) {
        self.state = state
        applyState()
    }
}

extension ChainAssetViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension ChainAssetViewController: HiddableBarWhenPushed {}

extension ChainAssetViewController: Containable {
    var contentView: UIView {
        view
    }

    func setContentInsets(_: UIEdgeInsets, animated _: Bool) {}
}
