import UIKit
import SoraFoundation

final class WalletHistoryFilterViewController: UIViewController {
    let presenter: WalletHistoryFilterPresenterProtocol

    init(
        presenter: WalletHistoryFilterPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension WalletHistoryFilterViewController: WalletHistoryFilterViewProtocol {
    func didReceive(viewModel: WalletHistoryFilterViewModel) {
        
    }
}

extension WalletHistoryFilterViewController: Localizable {
    func applyLocalization() {}
}
