import UIKit
import SoraFoundation

protocol AccountStatisticsViewOutput: AnyObject {
    func didLoad(view: AccountStatisticsViewInput)
}

final class AccountStatisticsViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountStatisticsViewLayout

    // MARK: Private properties

    private let output: AccountStatisticsViewOutput

    // MARK: - Constructor

    init(
        output: AccountStatisticsViewOutput,
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
        view = AccountStatisticsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - AccountStatisticsViewInput

extension AccountStatisticsViewController: AccountStatisticsViewInput {}

// MARK: - Localizable

extension AccountStatisticsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
