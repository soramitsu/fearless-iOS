import UIKit
import SafariServices

final class PurchaseViewController: SFSafariViewController {
    var presenter: PurchasePresenterProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        presenter.setup()
    }

    private func configure() {
        preferredControlTintColor = R.color.colorWhite()!
        preferredBarTintColor = R.color.colorAlmostBlack()!
    }
}

extension PurchaseViewController: PurchaseViewProtocol {}
