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

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations
        title = R.string.localizable.languageTitle(preferredLanguages: languages)
    }
}

extension LanguageSelectionViewController: LanguageSelectionViewProtocol {}

extension LanguageSelectionViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
