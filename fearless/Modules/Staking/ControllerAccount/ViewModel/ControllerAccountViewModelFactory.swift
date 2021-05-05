import IrohaCrypto
import SoraFoundation
import FearlessUtils

final class ControllerAccountViewModelFactory: ControllerAccountViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createViewModel(stashItem: StashItem?) -> LocalizableResource<ControllerAccountViewModel> {
        LocalizableResource { _ in
            guard let stashItem = stashItem else {
                return ControllerAccountViewModel(rows: [], actionButtonIsEnabled: false)
            }

            let stashAddress = stashItem.stash
            let stashIcon = try? self.iconGenerator
                .generateFromAddress(stashAddress)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            let stashViewModel = AccountInfoViewModel(
                title: "Stash account",
                address: stashAddress,
                name: stashAddress,
                icon: stashIcon
            )

            return ControllerAccountViewModel(
                rows: [
                    .stash(stashViewModel),
                    .learnMore
                ],
                actionButtonIsEnabled: true
            )
        }
    }
}
