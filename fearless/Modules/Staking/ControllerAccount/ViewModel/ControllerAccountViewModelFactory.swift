import IrohaCrypto
import SoraFoundation
import FearlessUtils

final class ControllerAccountViewModelFactory: ControllerAccountViewModelFactoryProtocol {
    let iconGenerator: IconGenerating
    let selectedAccount: AccountItem
    private lazy var addressFactory = SS58AddressFactory()

    init(selectedAccount: AccountItem, iconGenerator: IconGenerating) {
        self.selectedAccount = selectedAccount
        self.iconGenerator = iconGenerator
    }

    func createViewModel(
        stashItem: StashItem,
        selectedAccountItem: AccountItem,
        accounts: [AccountItem]
    ) -> ControllerAccountViewModel {
        let stashViewModel = LocalizableResource<AccountInfoViewModel> { _ in
            let stashAddress = stashItem.stash
            let stashName: String = {
                if let username = accounts.first(where: { $0.address == stashAddress })?.username {
                    return username
                }
                return stashAddress
            }()
            let stashIcon = try? self.iconGenerator
                .generateFromAddress(stashAddress)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            return AccountInfoViewModel(
                title: "Stash account",
                address: stashAddress,
                name: stashName,
                icon: stashIcon
            )
        }

        let controllerViewModel = LocalizableResource<AccountInfoViewModel> { locale in
            let selectedControllerAddress = selectedAccountItem.address
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
                name: selectedAccountItem.username,
                icon: controllerIcon
            )
        }

        let buttonState: ControllerAccountActionButtonState = {
            if stashItem.controller == self.selectedAccount.address {
                return .hidden
            }
            if selectedAccountItem.address == self.selectedAccount.address {
                return .enabled(false)
            }
            return .enabled(true)
        }()

        let canChooseOtherController = buttonState == .hidden ? false : true

        return ControllerAccountViewModel(
            stashViewModel: stashViewModel,
            controllerViewModel: controllerViewModel,
            actionButtonState: buttonState,
            canChooseOtherController: canChooseOtherController
        )
    }
}
