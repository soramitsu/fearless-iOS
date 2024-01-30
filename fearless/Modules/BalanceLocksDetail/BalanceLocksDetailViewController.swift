import UIKit
import SoraFoundation

final class BalanceLocksDetailViewController: UIViewController, ViewHolder {
    typealias RootViewType = BalanceLocksDetailViewLayout

    // MARK: Private properties

    private let output: BalanceLocksDetailViewOutput

    // MARK: - Constructor

    init(
        output: BalanceLocksDetailViewOutput,
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
        view = BalanceLocksDetailViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - BalanceLocksDetailViewInput

extension BalanceLocksDetailViewController: BalanceLocksDetailViewInput {}

// MARK: - Localizable

extension BalanceLocksDetailViewController: Localizable {
    func applyLocalization() {}
}
