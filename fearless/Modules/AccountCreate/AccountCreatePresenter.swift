import UIKit
import IrohaCrypto
import SoraFoundation

enum AdvancedSelectionContext: String {
    case cryptoType
    case networkType
}

final class AccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    let username: String

    private var metadata: AccountCreationMetadata?

    private var selectedCryptoType: CryptoType?
    private var selectedAddressType: SNAddressType?

    private var derivationPathViewModel: InputViewModelProtocol = {
        let inputHandling = InputHandler(predicate: NSPredicate.deriviationPath)
        return InputViewModel(inputHandler: inputHandling)
    }()

    private var isSetup = false

    init(username: String) {
        self.username = username
    }

    private func applyCryptoTypeViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = TitleWithSubtitleViewModel(title: cryptoType.titleForLocale(locale),
                                                   subtitle: cryptoType.subtitleForLocale(locale))

        view?.setSelectedCrypto(model: viewModel)
    }

    private func applyAddressTypeViewModel() {
        guard let addressType = selectedAddressType else {
            return
        }

        let locale = localizationManager?.selectedLocale ?? Locale.current

        let viewModel = IconWithTitleViewModel(icon: addressType.icon,
                                               title: addressType.titleForLocale(locale))

        view?.setSelectedNetwork(model: viewModel)
    }
}

extension AccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
        isSetup = true

        view?.setDerivationPath(viewModel: derivationPathViewModel)

        interactor.setup()
    }

    func selectCryptoType() {
        if let metadata = metadata {
            let context = AdvancedSelectionContext.cryptoType.rawValue as NSString
            let selectedType = selectedCryptoType ?? metadata.defaultCryptoType
            wireframe.presentCryptoTypeSelection(from: view,
                                                 availableTypes: metadata.availableCryptoTypes,
                                                 selectedType: selectedType,
                                                 delegate: self,
                                                 context: context)
        }
    }

    func selectNetworkType() {
        if let metadata = metadata {
            let context = AdvancedSelectionContext.networkType.rawValue as NSString
            let selectedType = selectedAddressType ?? metadata.defaultAccountType
            wireframe.presentNetworkTypeSelection(from: view,
                                                  availableTypes: metadata.availableAccountTypes,
                                                  selectedType: selectedType,
                                                  delegate: self,
                                                  context: context)
        }
    }

    func proceed() {
        guard
            let addressType = selectedAddressType,
            let cryptoType = selectedCryptoType else {
            return
        }

        let request = AccountCreationRequest(username: username,
                                             type: addressType,
                                             derivationPath: derivationPathViewModel.inputHandler.value,
                                             cryptoType: cryptoType)

        interactor.createAccount(request: request)
    }
}

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata: AccountCreationMetadata) {
        self.metadata = metadata

        selectedCryptoType = metadata.defaultCryptoType
        selectedAddressType = metadata.defaultAccountType

        view?.set(mnemonic: metadata.mnemonic)

        applyCryptoTypeViewModel()
        applyAddressTypeViewModel()
    }

    func didReceiveMnemonicGeneration(error: Error) {

    }

    func didCompleteAccountCreation() {
        wireframe.proceed(from: view)
    }

    func didReceiveAccountCreation(error: Error) {}
}

extension AccountCreatePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AdvancedSelectionContext(rawValue: context as String) {
            switch selectionContext {
            case .cryptoType:
                selectedCryptoType = metadata?.availableCryptoTypes[index]

                applyCryptoTypeViewModel()
                view?.didCompleteCryptoTypeSelection()
            case .networkType:
                selectedAddressType = metadata?.availableAccountTypes[index]

                applyAddressTypeViewModel()
                view?.didCompleteNetworkTypeSelection()
            }
        }
    }

    func modalPickerDidCancel(context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AdvancedSelectionContext(rawValue: context as String) {
            switch selectionContext {
            case .cryptoType:
                view?.didCompleteCryptoTypeSelection()
            case .networkType:
                view?.didCompleteNetworkTypeSelection()
            }
        }
    }
}

extension AccountCreatePresenter: Localizable {
    func applyLocalization() {
        if isSetup {
            applyCryptoTypeViewModel()
            applyAddressTypeViewModel()
        }
    }
}
