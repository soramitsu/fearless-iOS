import UIKit
import SoraFoundation

final class LiquidityPoolDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = LiquidityPoolDetailsViewLayout

    // MARK: Private properties

    private let output: LiquidityPoolDetailsViewOutput

    // MARK: - Constructor

    init(
        output: LiquidityPoolDetailsViewOutput,
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
        view = LiquidityPoolDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - LiquidityPoolDetailsViewInput

extension LiquidityPoolDetailsViewController: LiquidityPoolDetailsViewInput {}

// MARK: - Localizable

extension LiquidityPoolDetailsViewController: Localizable {
    func applyLocalization() {}
}
