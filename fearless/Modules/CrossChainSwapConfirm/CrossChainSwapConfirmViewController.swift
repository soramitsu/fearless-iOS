import UIKit
import SoraFoundation

protocol CrossChainSwapConfirmViewOutput: AnyObject {
    func didLoad(view: CrossChainSwapConfirmViewInput)
}

final class CrossChainSwapConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrossChainSwapConfirmViewLayout

    // MARK: Private properties

    private let output: CrossChainSwapConfirmViewOutput

    // MARK: - Constructor

    init(
        output: CrossChainSwapConfirmViewOutput,
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
        view = CrossChainSwapConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - CrossChainSwapConfirmViewInput

extension CrossChainSwapConfirmViewController: CrossChainSwapConfirmViewInput {}

// MARK: - Localizable

extension CrossChainSwapConfirmViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
