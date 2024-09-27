import UIKit
import SoraFoundation

protocol CrossChainTxTrackingViewOutput: AnyObject {
    func didLoad(view: CrossChainTxTrackingViewInput)
    func didTapBackButton()
}

final class CrossChainTxTrackingViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrossChainTxTrackingViewLayout

    // MARK: Private properties

    private let output: CrossChainTxTrackingViewOutput

    // MARK: - Constructor

    init(
        output: CrossChainTxTrackingViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
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
        view = CrossChainTxTrackingViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didTapBackButton()
        }
    }

    // MARK: - Private methods
}

// MARK: - CrossChainTxTrackingViewInput

extension CrossChainTxTrackingViewController: CrossChainTxTrackingViewInput {
    func didReceive(viewModel: CrossChainTxTrackingViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension CrossChainTxTrackingViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
