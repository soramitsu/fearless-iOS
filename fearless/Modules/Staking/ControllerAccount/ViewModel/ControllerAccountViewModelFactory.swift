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
        accounts: [AccountItem]?
    ) -> LocalizableResource<ControllerAccountViewModel> {
        LocalizableResource { locale in
            let stashAddress = stashItem.stash
            let stashName: String = {
                if let username = accounts?.first(where: { $0.address == stashAddress })?.username {
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
            let stashViewModel = AccountInfoViewModel(
                title: "Stash account",
                address: stashAddress,
                name: stashName,
                icon: stashIcon
            )

            let selectedControllerAddress = selectedAccountItem.address
            let controllerIcon = try? self.iconGenerator
                .generateFromAddress(selectedControllerAddress)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            let controllerViewModel = AccountInfoViewModel(
                title: R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages),
                address: selectedControllerAddress,
                name: selectedAccountItem.username,
                icon: controllerIcon
            )

            let buttonState: ControllerAccountActionButtonState = {
                if selectedAccountItem.address == self.selectedAccount.address {
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
