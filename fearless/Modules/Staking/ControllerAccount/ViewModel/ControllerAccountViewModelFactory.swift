import IrohaCrypto
import SoraFoundation
import FearlessUtils

final class ControllerAccountViewModelFactory: ControllerAccountViewModelFactoryProtocol {
    let iconGenerator: IconGenerating
    let selectedAccountAddress: AccountAddress

    init(selectedAccountAddress: AccountAddress, iconGenerator: IconGenerating) {
        self.selectedAccountAddress = selectedAccountAddress
        self.iconGenerator = iconGenerator
    }

    func createViewModel(stashItem: StashItem?) -> LocalizableResource<ControllerAccountViewModel> {
        LocalizableResource { locale in
            guard let stashItem = stashItem else {
                return ControllerAccountViewModel(rows: [], actionButtonState: .hidden)
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

            let contollerAddress = stashItem.controller
            let controllerIcon = try? self.iconGenerator
                .generateFromAddress(contollerAddress)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            let controllerViewModel = AccountInfoViewModel(
                title: R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages),
                address: contollerAddress,
                name: contollerAddress,
                icon: controllerIcon
            )

            let buttonState: ControllerAccountActionButtonState = {
                if contollerAddress == self.selectedAccountAddress {
                    return .hidden
                }
                return .enabled(true)
            }()

            return ControllerAccountViewModel(
                rows: [
                    .stash(stashViewModel),
                    .controller(controllerViewModel),
                    .learnMore
                ],
                actionButtonState: buttonState
            )
        }
    }
}
