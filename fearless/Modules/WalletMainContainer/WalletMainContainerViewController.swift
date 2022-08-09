import UIKit
import SoraFoundation

final class WalletMainContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletMainContainerViewLayout

    // MARK: Private properties

    private let output: WalletMainContainerViewOutput

    private let balanceInfoViewController: UIViewController
    private let assetListViewController: UIViewController
    private let nftViewController: UIViewController
    private lazy var pageControllers: [UIViewController] = {
        [assetListViewController, nftViewController]
    }()

    // MARK: - Constructor

    init(
        balanceInfoViewController: UIViewController,
        assetListViewController: UIViewController,
        nftViewController: UIViewController,
        output: WalletMainContainerViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.balanceInfoViewController = balanceInfoViewController
        self.assetListViewController = assetListViewController
        self.nftViewController = nftViewController
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = WalletMainContainerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setup()
    }

    // MARK: - Private methods

    private func setup() {
        rootView.delegate = self
        setupEmbededBalanceView()
        setupPageViewController()
    }

    private func setupEmbededBalanceView() {
        addChild(balanceInfoViewController)

        guard let view = balanceInfoViewController.view else {
            return
        }
        rootView.walletBalanceViewContainer.addSubview(view)
        view.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        controller.didMove(toParent: self)
    }

    private func setupPageViewController() {
        rootView.pageViewController.delegate = self

        addChild(rootView.pageViewController)

        rootView.pageViewController.setViewControllers([pageControllers[0]], direction: .forward, animated: false)
    }
}

// MARK: - WalletMainContainerViewInput

extension WalletMainContainerViewController: WalletMainContainerViewInput {
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension WalletMainContainerViewController: Localizable {
    func applyLocalization() {}
}

// MARK: - WalletMainContainerViewDelegate

extension WalletMainContainerViewController: WalletMainContainerViewDelegate {
    func didSelect(_ segmentIndex: Int) {
        rootView.pageViewController.setViewControllers(
            [pageControllers[segmentIndex]],
            direction: .init(from: segmentIndex) ?? .forward,
            animated: true
        )
    }

    func switchWalletDidTap() {
        output.didTapOnSwitchWallet()
    }

    func scanQRDidTap() {
        output.didTapOnQR()
    }

    func searchDidTap() {
        output.didTapSearch()
    }

    func selectNetworkDidTap() {
        output.didTapSelectNetwork()
    }
}

// MARK: - UIPageViewControllerDelegate

extension WalletMainContainerViewController: UIPageViewControllerDelegate {}

extension UIPageViewController.NavigationDirection {
    init?(from segmentIndex: Int) {
        switch segmentIndex {
        case 0:
            self = .reverse
        case 1:
            self = .forward
        default:
            return nil
        }
    }
}
