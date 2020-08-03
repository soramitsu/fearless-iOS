import UIKit
import IrohaCrypto

enum AdvancedSelectionContext: String {
    case cryptoType
    case networkType
}

final class AccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!

    private var metadata: AccountCreationMetadata?

    private var selectedCryptoType: CryptoType?
    private var selectedAddressType: SNAddressType?
}

extension AccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
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

    }
}

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata: AccountCreationMetadata) {
        self.metadata = metadata

        selectedCryptoType = metadata.defaultCryptoType
        selectedAddressType = metadata.defaultAccountType

        view?.set(mnemonic: metadata.mnemonic)
    }

    func didReceiveMnemonicGeneration(error: Error) {

    }

    func didCompleteAccountCreation() {

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
                view?.didCompleteCryptoTypeSelection()
            case .networkType:
                selectedAddressType = metadata?.availableAccountTypes[index]
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
