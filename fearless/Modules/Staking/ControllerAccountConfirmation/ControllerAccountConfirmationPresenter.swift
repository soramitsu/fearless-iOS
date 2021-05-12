import Foundation
import SoraFoundation
import FearlessUtils

final class ControllerAccountConfirmationPresenter {
    weak var view: ControllerAccountConfirmationViewProtocol?
    var wireframe: ControllerAccountConfirmationWireframeProtocol!
    var interactor: ControllerAccountConfirmationInteractorInputProtocol!

    let iconGenerator: IconGenerating
    private let stashAccountItem: AccountItem
    private let controllerAccountItem: AccountItem

    init(
        stashAccountItem: AccountItem,
        controllerAccountItem: AccountItem,
        iconGenerator: IconGenerating
    ) {
        self.stashAccountItem = stashAccountItem
        self.controllerAccountItem = controllerAccountItem
        self.iconGenerator = iconGenerator
    }

    private func setupView() {
        let viewModel = LocalizableResource<ControllerAccountConfirmationVM> { locale in
            let stashViewModel = self.createAccountInfoViewModel(
                self.stashAccountItem,
                title: R.string.localizable.stackingStashAccount(preferredLanguages: locale.rLanguages)
            )
            let controllerViewModel = self.createAccountInfoViewModel(
                self.controllerAccountItem,
                title: R.string.localizable.stakingControllerAccountTitle(preferredLanguages: locale.rLanguages)
            )

            return ControllerAccountConfirmationVM(
                stashViewModel: stashViewModel,
                controllerViewModel: controllerViewModel
            )
        }
        view?.reload(with: viewModel)
    }

    private func createAccountInfoViewModel(_ accountItem: AccountItem, title: String) -> AccountInfoViewModel {
        let address = accountItem.address
        let icon = try? iconGenerator
            .generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )
        return AccountInfoViewModel(
            title: title,
            address: address,
            name: accountItem.username,
            icon: icon
        )
    }
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationPresenterProtocol {
    func setup() {
        setupView()
    }
}

extension ControllerAccountConfirmationPresenter: ControllerAccountConfirmationInteractorOutputProtocol {}
