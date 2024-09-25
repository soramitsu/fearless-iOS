import UIKit
import SoraFoundation

protocol SwapContainerViewOutput: AnyObject {
    func didLoad(view: SwapContainerViewInput)
}

final class SwapContainerViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = SwapContainerViewLayout

    // MARK: Private properties

    private let output: SwapContainerViewOutput
    private let polkaswapViewController: UIViewController
    private let okxViewController: UIViewController

    // MARK: - Constructor

    init(
        output: SwapContainerViewOutput,
        localizationManager: LocalizationManagerProtocol?,
        polkaswapViewController: UIViewController,
        okxViewController: UIViewController
    ) {
        self.output = output
        self.polkaswapViewController = polkaswapViewController
        self.okxViewController = okxViewController
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = SwapContainerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        setupEmbededPolkaswapView()
        setupEmbededOkxView()
    }

    // MARK: - Private methods

    private func setupEmbededPolkaswapView() {
        addChild(polkaswapViewController)

        guard let view = polkaswapViewController.view else {
            return
        }

        rootView.addPolkaswapView(view)
        polkaswapViewController.didMove(toParent: self)
    }

    private func setupEmbededOkxView() {
        addChild(okxViewController)

        guard let view = okxViewController.view else {
            return
        }

        rootView.addOkxView(view)
        okxViewController.didMove(toParent: self)
    }
}

// MARK: - SwapContainerViewInput

extension SwapContainerViewController: SwapContainerViewInput {
    func switchToPolkaswap() {
        rootView.polkaswapContainer?.isHidden = false
        rootView.okxContainer?.isHidden = true
    }

    func switchToOkx() {
        rootView.polkaswapContainer?.isHidden = true
        rootView.okxContainer?.isHidden = false
    }
}

// MARK: - Localizable

extension SwapContainerViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
