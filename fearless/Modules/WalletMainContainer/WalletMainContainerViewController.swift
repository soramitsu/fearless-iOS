import UIKit
import SoraFoundation

final class WalletMainContainerViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletMainContainerViewLayout

    // MARK: Private properties

    private let output: WalletMainContainerViewOutput

    private let balanceInfoViewController: UIViewController
    private let pageControllers: [UIViewController]

    // MARK: - Constructor

    init(
        balanceInfoViewController: UIViewController,
        pageControllers: [UIViewController],
        output: WalletMainContainerViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.balanceInfoViewController = balanceInfoViewController
        self.pageControllers = pageControllers
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
        rootView.segmentedControl.delegate = self
        setupEmbededBalanceView()
        setupPageViewController()
        setupActions()
    }

    private func setupEmbededBalanceView() {
        addChild(balanceInfoViewController)

        guard let view = balanceInfoViewController.view else {
            return
        }

        rootView.addBalance(view)
        controller.didMove(toParent: self)
    }

    private func setupPageViewController() {
        addChild(rootView.pageViewController)

        rootView.pageViewController.setViewControllers([pageControllers[0]], direction: .forward, animated: false)
    }

    private func setupActions() {
        rootView.switchWalletButton.addTarget(self, action: #selector(handleSwitchWalletTap), for: .touchUpInside)
        rootView.scanQRButton.addTarget(self, action: #selector(handleScanQRTap), for: .touchUpInside)
        rootView.searchButton.addTarget(self, action: #selector(handleSearchTap), for: .touchUpInside)
        rootView.selectNetworkButton.addTarget(self, action: #selector(handleSelectNetworkTap), for: .touchUpInside)
        rootView.issuesButton.addTarget(self, action: #selector(handleIssueButtonDidTap), for: .touchUpInside)

        let walletBalanceTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBalanceDidTap))
        rootView.walletBalanceViewContainer.addGestureRecognizer(walletBalanceTapGesture)
    }

    // MARK: - Actions

    @objc private func handleSwitchWalletTap() {
        output.didTapOnSwitchWallet()
    }

    @objc private func handleScanQRTap() {
        output.didTapOnQR()
    }

    @objc private func handleSearchTap() {
        output.didTapSearch()
    }

    @objc private func handleSelectNetworkTap() {
        output.didTapSelectNetwork()
    }

    @objc private func handleBalanceDidTap() {
        output.didTapOnBalance()
    }

    @objc private func handleIssueButtonDidTap() {
        output.didTapIssueButton()
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
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - FWSegmentedControlDelegate

extension WalletMainContainerViewController: FWSegmentedControlDelegate {
    func didSelect(_ segmentIndex: Int) {
        rootView.pageViewController.setViewControllers(
            [pageControllers[segmentIndex]],
            direction: .init(from: segmentIndex) ?? .forward,
            animated: true
        )
    }
}

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
