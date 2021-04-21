import UIKit
import SoraFoundation

final class StakingBalanceViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingBalanceViewLayout

    let presenter: StakingBalancePresenterProtocol

    init(
        presenter: StakingBalancePresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingBalanceViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension StakingBalanceViewController: StakingBalanceViewProtocol {
    func applyLocalization() {}
}
