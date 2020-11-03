import UIKit

final class AccountExportPasswordViewController: UIViewController {
    var presenter: AccountExportPasswordPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AccountExportPasswordViewController: AccountExportPasswordViewProtocol {}