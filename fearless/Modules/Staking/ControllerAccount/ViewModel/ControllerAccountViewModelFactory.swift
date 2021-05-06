import IrohaCrypto
import SoraFoundation
import FearlessUtils

final class ControllerAccountViewModelFactory: ControllerAccountViewModelFactoryProtocol {
    let iconGenerator: IconGenerating
    let selectedAccount: AccountItem

    init(selectedAccount: AccountItem, iconGenerator: IconGenerating) {
        self.selectedAccount = selectedAccount
        self.iconGenerator = iconGenerator
    }

    func createViewModel(
        stashAddress: AccountAddress,
        controllerAddress: AccountAddress
    ) -> LocalizableResource<ControllerAccountViewModel> {
        LocalizableResource { locale in
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

            let controllerIcon = try? self.iconGenerator
                .generateFromAddress(controllerAddress)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            let controllerViewModel = AccountInfoViewModel(
                title: R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages),
                address: controllerAddress,
                name: controllerAddress,
                icon: controllerIcon
            )

            let buttonState: ControllerAccountActionButtonState = {
                if controllerAddress == self.selectedAccount.address {
                    return .hidden
                }
                return .enabled(true)
            }()

            return ControllerAccountViewModel(
                stashViewModel: stashViewModel,
                controllerViewModel: controllerViewModel,
                actionButtonState: buttonState
            )
        }
    }
}
