import UIKit
import Rswift
import SoraFoundation

final class ChainSelectionViewController: SelectionListViewController<SelectionIconDetailsTableViewCell> {
    override var selectableCellIdentifier: ReuseIdentifier<SelectionIconDetailsTableViewCell>! {
        ReuseIdentifier(identifier: SelectionIconDetailsTableViewCell.reuseIdentifier)
    }

    let localizedTitle: LocalizableResource<String>

    let presenter: ChainSelectionPresenterProtocol

    init(
        nibName: String,
        localizedTitle: LocalizableResource<String>,
        presenter: ChainSelectionPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizedTitle = localizedTitle

        super.init(nibName: nibName, bundle: nil)

        listPresenter = presenter
        self.localizationManager = localizationManager
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
        title = localizedTitle.value(for: selectedLocale)
    }
}
