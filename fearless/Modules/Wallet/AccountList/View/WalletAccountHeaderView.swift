import UIKit
import CommonWallet
import SoraUI
import SoraFoundation

final class WalletAccountHeaderView: UICollectionViewCell {
    @IBOutlet private(set) var titleLabel: UILabel!

    var viewModel: WalletViewModelProtocol?

    override func awakeFromNib() {
        super.awakeFromNib()

        localizationManager = LocalizationManager.shared
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel = nil
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations
        titleLabel.text = R.string.localizable.walletTitle(preferredLanguages: languages)
    }
}

extension WalletAccountHeaderView: Localizable {
    func applyLocalization() {
        setupLocalization()

        if superview != nil {
            setNeedsLayout()
        }
    }
}

extension WalletAccountHeaderView: WalletViewProtocol {

    func bind(viewModel: WalletViewModelProtocol) {
        self.viewModel = viewModel
    }
}
