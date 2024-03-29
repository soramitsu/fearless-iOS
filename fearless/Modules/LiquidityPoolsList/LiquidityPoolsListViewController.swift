import UIKit
import SoraFoundation

final class LiquidityPoolsListViewController: UIViewController, ViewHolder {
    typealias RootViewType = LiquidityPoolsListViewLayout

    // MARK: Private properties

    private let output: LiquidityPoolsListViewOutput

    // MARK: - Constructor

    init(
        output: LiquidityPoolsListViewOutput,
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
        view = LiquidityPoolsListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - LiquidityPoolsListViewInput

extension LiquidityPoolsListViewController: LiquidityPoolsListViewInput {}

// MARK: - Localizable

extension LiquidityPoolsListViewController: Localizable {
    func applyLocalization() {}
}
