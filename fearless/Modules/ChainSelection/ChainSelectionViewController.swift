import UIKit
import Rswift
import SoraFoundation

final class ChainSelectionViewController: SelectionListViewController<SelectionIconDetailsTableViewCell> {
    override var selectableCellIdentifier: ReuseIdentifier<SelectionIconDetailsTableViewCell>! {
        ReuseIdentifier(identifier: SelectionIconDetailsTableViewCell.reuseIdentifier)
    }

    let presenter: ChainSelectionPresenterProtocol

    init(nibName: String, presenter: ChainSelectionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nibName, bundle: nil)

        listPresenter = presenter
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()

        presenter.setup()
    }
}

extension ChainSelectionViewController: ChainSelectionViewProtocol {}

extension ChainSelectionViewController: Localizable {
    func applyLocalization() {
        title = R.string.localizable.connectionManagementTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}
