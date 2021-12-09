import Foundation
import FearlessUtils

protocol AccountViewModelFactoryProtocol {
    func buildViewModel(
        address: String,
        locale: Locale
    ) -> AccountViewModel
}

class AccountViewModelFactory: AccountViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func buildViewModel(
        address: String,
        locale: Locale
    ) -> AccountViewModel {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: locale.rLanguages)

        return AccountViewModel(
            title: title,
            name: address,
            icon: try? iconGenerator.generateFromAddress(address)
        )
    }
}
