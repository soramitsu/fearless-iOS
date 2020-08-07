import UIKit

final class AccountImportViewController: UIViewController {
    var presenter: AccountImportPresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AccountImportViewController: AccountImportViewProtocol {}