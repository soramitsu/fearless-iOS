import IrohaCrypto
import SoraFoundation
import FearlessUtils

final class ControllerAccountViewModelFactory: ControllerAccountViewModelFactoryProtocol {
    let iconGenerator: IconGenerating
    let currentAccountItem: AccountItem
    private lazy var addressFactory = SS58AddressFactory()

    init(currentAccountItem: AccountItem, iconGenerator: IconGenerating) {
        self.currentAccountItem = currentAccountItem
        self.iconGenerator = iconGenerator
    }

    func createViewModel(
        stashItem: StashItem,
        stashAccountItem: AccountItem,
        chosenAccountItem: AccountItem
    ) -> ControllerAccountViewModel {
        let stashViewModel = LocalizableResource<AccountInfoViewModel> { locale in
            let stashAddress = stashAccountItem.address
            let stashIcon = try? self.iconGenerator
                .generateFromAddress(stashAddress)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            return AccountInfoViewModel(
                title: R.string.localizable.stackingStashAccount(preferredLanguages: locale.rLanguages),
                address: stashAddress,
                name: stashAccountItem.username,
                icon: stashIcon
            )
        }

        let controllerViewModel = LocalizableResource<AccountInfoViewModel> { locale in
            let selectedControllerAddress = chosenAccountItem.address
            let controllerIcon = try? self.iconGenerator
                .generateFromAddress(selectedControllerAddress)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            return AccountInfoViewModel(
                title: R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages),
                address: selectedControllerAddress,
                name: chosenAccountItem.username,
                icon: controllerIcon
            )
        }

        let buttonState: ControllerAccountActionButtonState = {
            if stashAccountItem.address != self.currentAccountItem.address {
                return .hidden
            }
            if chosenAccountItem.address == stashItem.controller {
                return .enabled(false)
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
