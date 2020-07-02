import UIKit
import Rswift
import SoraFoundation

final class NodeSelectionViewController: SelectionListViewController<SelectionSubtitleTableViewCell> {
    var presenter: NodeSelectionPresenterProtocol!

    override var selectableCellIdentifier: ReuseIdentifier<SelectionSubtitleTableViewCell>! {
        return R.reuseIdentifier.selectionSubtitleCellId
    }

    override var selectableCellNib: UINib? {
        return UINib(resource: R.nib.selectionSubtitleTableViewCell)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()

        presenter.setup()
    }
}

extension NodeSelectionViewController: NodeSelectionViewProtocol {}

extension NodeSelectionViewController: Localizable {
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        title = R.string.localizable.languageTitle(preferredLanguages: languages)
    }
}
