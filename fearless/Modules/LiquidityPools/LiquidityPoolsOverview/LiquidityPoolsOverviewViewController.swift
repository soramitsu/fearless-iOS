import UIKit
import SoraFoundation

final class LiquidityPoolsOverviewViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = LiquidityPoolsOverviewViewLayout

    // MARK: Private properties

    private let output: LiquidityPoolsOverviewViewOutput

    private let userPoolsViewController: UIViewController
    private let availablePoolsViewController: UIViewController
    private var refreshControl = UIRefreshControl()
    private var viewLoadingFinished: Bool = false

    // MARK: - Constructor

    init(
        output: LiquidityPoolsOverviewViewOutput,
        localizationManager: LocalizationManagerProtocol?,
        userPoolsViewController: UIViewController,
        availablePoolsViewController: UIViewController
    ) {
        self.output = output
        self.userPoolsViewController = userPoolsViewController
        self.availablePoolsViewController = availablePoolsViewController
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = true
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = LiquidityPoolsOverviewViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.backButtonClicked()
        }

        setupEmbededUserPoolsView()
        setupEmbededAvailablePoolsView()
        refreshControl.addTarget(self, action: #selector(handleRefreshControlEvent), for: .valueChanged)
        rootView.scrollView.refreshControl = refreshControl
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !viewLoadingFinished else {
            return
        }

        viewLoadingFinished = true

        rootView.refreshLayout()
    }

    // MARK: - Private methods

    @objc private func handleRefreshControlEvent() {
        output.handleRefreshControlEvent()
    }

    private func setupEmbededUserPoolsView() {
        addChild(userPoolsViewController)

        guard let view = userPoolsViewController.view else {
            return
        }

        rootView.addUserPoolsView(view)
        controller.didMove(toParent: self)
    }

    private func setupEmbededAvailablePoolsView() {
        addChild(availablePoolsViewController)

        guard let view = availablePoolsViewController.view else {
            return
        }

        rootView.addAvailablePoolsView(view)
        controller.didMove(toParent: self)
    }
}

// MARK: - LiquidityPoolsOverviewViewInput

extension LiquidityPoolsOverviewViewController: LiquidityPoolsOverviewViewInput {
    func changeUserPoolsVisibility(visible: Bool) {
        rootView.userPoolsContainerView.isHidden = !visible
    }

    func didReceiveUserPoolsCount(count: Int) {
        refreshControl.endRefreshing()
        rootView.bind(userPoolsCount: count)
    }
}

// MARK: - Localizable

extension LiquidityPoolsOverviewViewController: Localizable {
    func applyLocalization() {}
}
