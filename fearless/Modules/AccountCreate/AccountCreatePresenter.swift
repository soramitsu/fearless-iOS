import UIKit
import IrohaCrypto
import SoraFoundation

enum AccountCreateContext: String {
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

    private var derivationPathViewModel: InputViewModelProtocol?

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

    private func applyDerivationPathViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            predicate = NSPredicate.deriviationPathHardSoftPassword
            placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
        } else {
            predicate = NSPredicate.deriviationPathHardPassword
            placeholder = DerivationPathConstants.hardPasswordPlaceholder
        }

        let inputHandling = InputHandler(predicate: predicate)
        let viewModel = InputViewModel(inputHandler: inputHandling, placeholder: placeholder)

        self.derivationPathViewModel = viewModel

        view?.setDerivationPath(viewModel: viewModel)
        view?.didValidateDerivationPath(.none)
    }

    private func presentDerivationPathError(_ cryptoType: CryptoType) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch cryptoType {
        case .sr25519:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationHardSoftPassword,
                                  from: view,
                                  locale: locale)
        case .ed25519, .ecdsa:
            _ = wireframe.present(error: AccountCreationError.invalidDerivationHardPassword,
                                  from: view,
                                  locale: locale)
        }
    }
}

extension AccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateInfo() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let message = R.string.localizable.accountCreationInfo(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.commonInfo(preferredLanguages: locale.rLanguages)
        wireframe.present(message: message,
                          title: title,
                          closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                          from: view)
    }

    func validate() {
        guard let viewModel = derivationPathViewModel, let cryptoType = selectedCryptoType else {
            return
        }

        if viewModel.inputHandler.completed {
            view?.didValidateDerivationPath(.valid)
        } else {
            view?.didValidateDerivationPath(.invalid)
            presentDerivationPathError(cryptoType)
        }
    }

    func selectCryptoType() {
        if let metadata = metadata {
            let context = AccountCreateContext.cryptoType.rawValue as NSString
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
            let context = AccountCreateContext.networkType.rawValue as NSString
            let selectedType = selectedAddressType ?? metadata.defaultAddressType
            wireframe.presentNetworkTypeSelection(from: view,
                                                  availableTypes: metadata.availableAddressTypes,
                                                  selectedType: selectedType,
                                                  delegate: self,
                                                  context: context)
        }
    }

    func proceed() {
        guard
            let addressType = selectedAddressType,
            let cryptoType = selectedCryptoType,
            let viewModel = derivationPathViewModel,
            let metadata = metadata else {
            return
        }

        guard viewModel.inputHandler.completed else {
            view?.didValidateDerivationPath(.invalid)
            presentDerivationPathError(cryptoType)
            return
        }

        let request = AccountCreationRequest(username: username,
                                             type: addressType,
                                             derivationPath: viewModel.inputHandler.value,
                                             cryptoType: cryptoType)

        wireframe.confirm(from: view,
                          request: request,
                          metadata: metadata)
    }
}

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata: AccountCreationMetadata) {
        self.metadata = metadata

        selectedCryptoType = metadata.defaultCryptoType
        selectedAddressType = metadata.defaultAddressType

        view?.set(mnemonic: metadata.mnemonic)

        applyCryptoTypeViewModel()
        applyAddressTypeViewModel()
        applyDerivationPathViewModel()
    }

    func didReceiveMnemonicGeneration(error: Error) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined,
                              from: view,
                              locale: locale)
    }
}

extension AccountCreatePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AccountCreateContext(rawValue: context as String) {
            switch selectionContext {
            case .cryptoType:
                selectedCryptoType = metadata?.availableCryptoTypes[index]

                applyCryptoTypeViewModel()
                applyDerivationPathViewModel()

                view?.didCompleteCryptoTypeSelection()
            case .networkType:
                selectedAddressType = metadata?.availableAddressTypes[index]

                applyAddressTypeViewModel()
                view?.didCompleteNetworkTypeSelection()
            }
        }
    }

    func modalPickerDidCancel(context: AnyObject?) {
        if
            let context = context as? NSString,
            let selectionContext = AccountCreateContext(rawValue: context as String) {
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
        if let view = view, view.isSetup {
            applyCryptoTypeViewModel()
            applyAddressTypeViewModel()
        }
    }
}
