import UIKit
import Rswift
import SoraFoundation

final class LanguageSelectionViewController: SelectionListViewController<SelectionSubtitleTableViewCell> {
    var presenter: LanguageSelectionPresenterProtocol!

    override var selectableCellIdentifier: ReuseIdentifier<SelectionSubtitleTableViewCell>! {
        R.reuseIdentifier.selectionSubtitleCellId
    }

    override var selectableCellNib: UINib? {
        UINib(resource: R.nib.selectionSubtitleTableViewCell)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        applyLocalization()

        presenter.setup()
    }
}

extension LanguageSelectionViewController: LanguageSelectionViewProtocol {}

extension LanguageSelectionViewController: Localizable {
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        title = R.string.localizable.languageTitle(preferredLanguages: languages)
    }
}
