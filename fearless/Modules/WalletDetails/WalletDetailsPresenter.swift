import SoraFoundation
import FearlessUtils
import UIKit
final class WalletDetailsPresenter {
    weak var view: WalletDetailsViewProtocol?
    let interactor: WalletDetailsInteractorInputProtocol
    let wireframe: WalletDetailsWireframeProtocol
    let selectedWallet: MetaAccountModel

    private var chainsWithAccounts: [ChainModel: ChainAccountResponse] = [:]
    private lazy var inputViewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(
            predicate: NSPredicate.notEmpty,
            processor: ByteLengthProcessor.username
        )
        inputHandling.changeValue(to: selectedWallet.name)
        return InputViewModel(
            inputHandler: inputHandling,
            title: R.string.localizable.usernameSetupChooseTitle(preferredLanguages: selectedLocale.rLanguages)
        )
    }()

    private lazy var iconGenerator = {
        PolkadotIconGenerator()
    }

    init(
        interactor: WalletDetailsInteractorInputProtocol,
        wireframe: WalletDetailsWireframeProtocol,
        selectedWallet: MetaAccountModel,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedWallet = selectedWallet
        self.localizationManager = localizationManager
    }
}

extension WalletDetailsPresenter: Localizable {
    func applyLocalization() {
        provideViewModel(chainsWithAccounts: chainsWithAccounts)
    }
}

extension WalletDetailsPresenter: WalletDetailsViewOutputProtocol {
    func didLoad(ui: WalletDetailsViewProtocol) {
        view = ui
        view?.setInput(viewModel: inputViewModel)
        interactor.setup()
    }

    func updateData() {
//        TODO: Will required when add chain acounts changes
    }

    func didTapCloseButton() {
        if let view = self.view {
            wireframe.close(view)
        }
    }

    func willDisappear() {
        if inputViewModel.inputHandler.value != selectedWallet.name {
            interactor.update(inputViewModel.inputHandler.value)
        }
    }

    func didReceive(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(
            error: CommonError.undefined,
            from: view,
            locale: locale
        )
    }
}

extension WalletDetailsPresenter: WalletDetailsInteractorOutputProtocol {
    func didReceive(chainsWithAccounts: [ChainModel: ChainAccountResponse]) {
        self.chainsWithAccounts = chainsWithAccounts
        provideViewModel(chainsWithAccounts: chainsWithAccounts)
    }
}

private extension WalletDetailsPresenter {
    func provideViewModel(chainsWithAccounts: [ChainModel: ChainAccountResponse]) {
        let viewModel = WalletDetailsViewModel(
            navigationTitle: R.string.localizable.tabbarWalletTitle(
                preferredLanguages: selectedLocale.rLanguages
            ),
            chainViewModels: chainsWithAccounts.map {
                let icon = $0.key.icon.map { RemoteImageViewModel(url: $0) }
                let address = $0.value.toAddress()
                var addressImage: UIImage?
                if let address = address {
                    addressImage = try? PolkadotIconGenerator().generateFromAddress(address)
                        .imageWithFillColor(
                            R.color.colorBlack()!,
                            size: UIConstants.normalAddressIconSize,
                            contentScale: UIScreen.main.scale
                        )
                }
                return WalletDetailsCellViewModel(
                    chainImageViewModel: icon,
                    chainName: $0.key.name,
                    addressImage: addressImage,
                    address: address
                )
            }
        )
        view?.bind(to: viewModel)
    }
}
