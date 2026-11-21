import UIKit
import SoraFoundation

final class WalletMainContainerViewController: UIViewController, ViewHolder, AllDonePresentable,
    AdaptiveFullWidthContent {
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
        if FWAppearance.walletHeaderRestyled { applyLocalization() }
        output.didLoad(view: self)
        setup()
    }

    // MARK: - Private methods

    private func setup() {
        rootView.segmentedControl.delegate = self
        setupEmbededBalanceView()
        setupPageViewController()
        setupActions()
        rootView.addressCopyableLabel.onСopied = { [weak self] in
            self?.output.addressDidCopied()
        }
    }

    private func setupEmbededBalanceView() {
        addChild(balanceInfoViewController)

        guard let view = balanceInfoViewController.view else {
            return
        }

        rootView.addBalance(view)
        balanceInfoViewController.didMove(toParent: self)
    }

    private func setupPageViewController() {
        addChild(rootView.pageViewController)

        rootView.pageViewController.setViewControllers([pageControllers[0]], direction: .forward, animated: false)
        // One list: the balance card folds away while the list's search field has the keyboard.
        for page in pageControllers {
            (page as? WalletInlineSearchHosting)?.onInlineSearchActiveChange = { [weak self] active in
                self?.rootView.setSearchFocused(active, animated: true)
            }
            (page as? WalletHomeListChanging)?.onListChange = { [weak self] in
                self?.rootView.setNeedsLayout()
            }
        }
    }

    private func setupActions() {
        rootView.switchWalletButton.addTarget(self, action: #selector(handleSwitchWalletTap), for: .touchUpInside)
        rootView.scanQRButton.addTarget(self, action: #selector(handleScanQRTap), for: .touchUpInside)
        rootView.searchButton.addTarget(self, action: #selector(handleSearchTap), for: .touchUpInside)
        rootView.selectNetworkButton.addTarget(self, action: #selector(handleSelectNetworkTap), for: .touchUpInside)

        let walletBalanceTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBalanceDidTap))
        rootView.walletBalanceViewContainer.addGestureRecognizer(walletBalanceTapGesture)

        rootView.accountScoreView.starView.didFinishTouchingCosmos = { [weak self] _ in
            // The stars also report a touch the page took for a scroll (cancelled); only a tap opens the score.
            guard let self, !self.rootView.isScrollingPage else { return }
            self.output.didTapAccountScore()
        }

        let actions: [(FWRoundActionButton, WalletHomeAction)] = [
            (rootView.sendButton, .send), (rootView.receiveButton, .receive),
            (rootView.buyButton, .buy), (rootView.swapButton, .swap)
        ]
        for (button, action) in actions {
            button.addAction { [weak self] in
                self?.output.didTapHomeAction(action)
            }
        }
    }

    // MARK: - Actions

    @objc private func handleSwitchWalletTap() {
        output.didTapOnSwitchWallet()
    }

    @objc private func handleScanQRTap() {
        output.didTapOnQR()
    }

    /// The asset list's own search field takes the keyboard; another page keeps the search screen.
    @objc private func handleSearchTap() {
        if let page = rootView.pageViewController.viewControllers?.first as? WalletInlineSearchHosting,
           page.focusInlineSearch() {
            return
        }
        output.didTapSearch()
    }

    @objc private func handleSelectNetworkTap() {
        output.didTapSelectNetwork()
    }

    @objc private func handleBalanceDidTap() {
        output.didTapOnBalance()
    }
}

// MARK: - WalletMainContainerViewInput

extension WalletMainContainerViewController: WalletMainContainerViewInput {
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel) {
        rootView.bind(viewModel: viewModel)
    }

    func didReceiveAccountScoreViewModel(_ viewModel: AccountScoreViewModel) {
        rootView.bind(accountScoreViewModel: viewModel)
    }

    func didReceiveNftAvailability(isNftAvailable: Bool) {
        rootView.segmentContainer.isHidden = !isNftAvailable
    }

    func didReceive(syncUpdate: WalletSyncUpdate) {
        rootView.apply(syncUpdate: syncUpdate)
    }
}

// MARK: - Localizable

extension WalletMainContainerViewController: Localizable {
    func applyLocalization() {
        if FWAppearance.walletHeaderRestyled, !isViewLoaded { return }
        rootView.locale = selectedLocale
    }
}

// MARK: - FWSegmentedControlDelegate

extension WalletMainContainerViewController: FWSegmentedControlDelegate {
    func didSelect(_ segmentIndex: Int) {
        let page = pageControllers[segmentIndex]
        // The page slides in beside the one it replaces; neither of their lists may take the status-bar tap.
        rootView.assignScrollToTop(in: page.view)
        rootView.pageViewController.setViewControllers(
            [page],
            direction: .init(from: segmentIndex) ?? .forward,
            animated: true
        ) { [weak self] _ in
            // The home follows the list it shows now.
            self?.rootView.setNeedsLayout()
        }
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

// MARK: - Launch flight tiers (kit v4)

extension WalletMainContainerViewController: FWFlightTiered {
    var flightTiers: [FWFlightTier] {
        let list = (rootView.pageViewController.viewControllers?.first as? FWFlightTiered)?.flightTiers ?? []
        return rootView.flightTiers + list
    }
}
