import UIKit
import IrohaCrypto
import SoraFoundation
import SSFUtils

final class AccountCreatePresenter {
    static let maxEthereumDerivationPathLength: Int = 15

    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol
    var interactor: AccountCreateInteractorInputProtocol

    let usernameSetup: UsernameSetupModel
    var flow: AccountCreateFlow

    private var mnemonic: [String]?
    private var selectedCryptoType: CryptoType = .sr25519
    private var substrateDerivationPathViewModel: InputViewModelProtocol?
    private var ethereumDerivationPathViewModel: InputViewModelProtocol?

    init(
        usernameSetup: UsernameSetupModel,
        wireframe: AccountCreateWireframeProtocol,
        interactor: AccountCreateInteractorInputProtocol,
        flow: AccountCreateFlow
    ) {
        self.usernameSetup = usernameSetup
        self.wireframe = wireframe
        self.interactor = interactor
        self.flow = flow
    }

    private func applySubstrateCryptoTypeViewModel() {
        let viewModel = createCryptoTypeViewModel(selectedCryptoType)
        let selectableModel = SelectableViewModel(
            underlyingViewModel: viewModel,
            selectable: flow.supportsSelection
        )
        view?.setSelectedSubstrateCrypto(model: selectableModel)
    }

    private func applyEthereumCryptoTypeViewModel() {
        let viewModel = createCryptoTypeViewModel(.ecdsa)
        view?.setEthereumCrypto(model: viewModel)
    }

    private func createCryptoTypeViewModel(_ cryptoType: CryptoType) -> TitleWithSubtitleViewModel {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        return TitleWithSubtitleViewModel(
            title: cryptoType.titleForLocale(locale),
            subtitle: cryptoType.subtitleForLocale(locale)
        )
    }

    private func applySubstrateDerivationPathViewModel() {
        let viewModel = createViewModel(
            for: selectedCryptoType,
            isEthereum: false
        )
        substrateDerivationPathViewModel = viewModel

        view?.bind(substrateViewModel: viewModel)
        view?.didValidateSubstrateDerivationPath(.none)
    }

    private func applyEthereumDerivationPathViewModel() {
        let viewModel = createViewModel(
            for: .ecdsa,
            isEthereum: true,
            processor: NumbersAndSlashesProcessor(),
            maxLength: AccountCreatePresenter.maxEthereumDerivationPathLength
        )
        ethereumDerivationPathViewModel = viewModel

        view?.bind(ethereumViewModel: viewModel)
        view?.didValidateEthereumDerivationPath(.none)
    }

    private func createViewModel(
        for cryptoType: CryptoType,
        isEthereum: Bool,
        processor: TextProcessing? = nil,
        maxLength: Int? = nil
    ) -> AccountCreateViewModel {
        let predicate: NSPredicate?
        let placeholder: String

        if isEthereum {
            predicate = NSPredicate.deriviationPathHardSoft
            placeholder = DerivationPathConstants.defaultEthereum
        } else {
            switch cryptoType {
            case .sr25519:
                predicate = NSPredicate.deriviationPathHardSoftPassword
                placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
            case .ed25519, .ecdsa:
                predicate = NSPredicate.deriviationPathHardPassword
                placeholder = DerivationPathConstants.hardPasswordPlaceholder
            }
        }

        let inputHandling = InputHandler(
            maxLength: maxLength ?? Int.max,
            predicate: predicate,
            processor: processor
        )
        return AccountCreateViewModel(
            inputHandler: inputHandling,
            placeholder: placeholder
        )
    }

    private func presentDerivationPathError(_ cryptoType: CryptoType, isEthereum: Bool) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        if isEthereum {
            _ = wireframe.present(
                error: AccountCreationError.invalidDerivationHardSoftNumeric,
                from: view,
                locale: locale
            )
        } else {
            switch cryptoType.utilsType {
            case .sr25519:
                _ = wireframe.present(
                    error: AccountCreationError.invalidDerivationHardSoftPassword,
                    from: view,
                    locale: locale
                )
            case .ed25519, .ecdsa:
                _ = wireframe.present(
                    error: AccountCreationError.invalidDerivationHardPassword,
                    from: view,
                    locale: locale
                )
            }
        }
    }
}

extension AccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
        interactor.setup()
        switch flow {
        case .wallet, .backup:
            view?.set(chainType: .both)
        case let .chain(model):
            if let cryptoType = CryptoType(rawValue: model.meta.substrateCryptoType) {
                selectedCryptoType = cryptoType
            }
            view?.set(chainType: model.chain.isEthereumBased ? .ethereum : .substrate)
        }
        applySubstrateCryptoTypeViewModel()
        applySubstrateDerivationPathViewModel()
        applyEthereumCryptoTypeViewModel()
        applyEthereumDerivationPathViewModel()
    }

    func activateInfo() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        let message = R.string.localizable.accountCreationInfo(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.commonInfo(preferredLanguages: locale.rLanguages)
        wireframe.present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }

    func validateSubstrate() {
        guard let viewModel = substrateDerivationPathViewModel else {
            return
        }

        if viewModel.inputHandler.completed {
            view?.didValidateSubstrateDerivationPath(.valid)
        } else {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(selectedCryptoType, isEthereum: false)
        }
    }

    func validateEthereum() {
        guard let viewModel = ethereumDerivationPathViewModel else {
            return
        }

        if viewModel.inputHandler.value.components(separatedBy: "/").map({ component in
            component.replacingOccurrences(of: "/", with: "", options: NSString.CompareOptions.literal, range: nil)
        }).filter({ component in
            if component.isEmpty {
                return false
            }
            if let _ = UInt32(component) {
                return false
            } else {
                return true
            }
        }).isEmpty, viewModel.inputHandler.completed {
            view?.didValidateEthereumDerivationPath(.valid)
        } else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(.ecdsa, isEthereum: true)
        }
    }

    func selectSubstrateCryptoType() {
        wireframe.presentCryptoTypeSelection(
            from: view,
            availableTypes: CryptoType.allCases,
            selectedType: selectedCryptoType,
            delegate: self,
            context: nil
        )
    }

    func proceed(withReplaced flow: AccountCreateFlow?) {
        let unwrappedFlow = flow ?? self.flow

        guard
            let mnemonic = mnemonic,
            let substrateViewModel = substrateDerivationPathViewModel,
            let ethereumViewModel = ethereumDerivationPathViewModel
        else {
            return
        }
        guard let mnemonic = interactor.createMnemonicFromString(mnemonic.joined(separator: " ")) else {
            didReceiveMnemonicGeneration(error: AccountCreateError.invalidMnemonicFormat)
            return
        }

        guard substrateViewModel.inputHandler.completed else {
            view?.didValidateSubstrateDerivationPath(.invalid)
            presentDerivationPathError(selectedCryptoType, isEthereum: false)
            return
        }

        guard ethereumViewModel.inputHandler.completed else {
            view?.didValidateEthereumDerivationPath(.invalid)
            presentDerivationPathError(.ecdsa, isEthereum: true)
            return
        }
        let ethereumDerivationPath = (ethereumDerivationPathViewModel?.inputHandler.value)
            .nonEmpty(or: DerivationPathConstants.defaultEthereum)
        let substrateDerivationPath = (substrateDerivationPathViewModel?.inputHandler.value).nonEmpty(or: "")
        switch unwrappedFlow {
        case .wallet:
            let request = MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic,
                username: usernameSetup.username,
                substrateDerivationPath: substrateDerivationPath,
                ethereumDerivationPath: ethereumDerivationPath,
                cryptoType: selectedCryptoType,
                defaultChainId: nil
            )
            wireframe.confirm(
                from: view,
                flow: .wallet(request)
            )
        case let .chain(model):
            let request = ChainAccountImportMnemonicRequest(
                mnemonic: mnemonic,
                username: usernameSetup.username,
                derivationPath: model.chain.isEthereumBased ? ethereumDerivationPath : substrateDerivationPath,
                cryptoType: model.chain.isEthereumBased ? .ecdsa : selectedCryptoType,
                isEthereum: model.chain.isEthereumBased,
                meta: model.meta,
                chainId: model.chain.chainId
            )
            wireframe.confirm(from: view, flow: .chain(request))
        case .backup:
            let request = MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic,
                username: usernameSetup.username,
                substrateDerivationPath: substrateDerivationPath,
                ethereumDerivationPath: ethereumDerivationPath,
                cryptoType: selectedCryptoType,
                defaultChainId: nil
            )
            wireframe.showBackupCreatePassword(
                request: request,
                from: view
            )
        }
    }

    func didTapBackupButton() {
        proceed(withReplaced: .backup)
    }
}

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(mnemonic: [String]) {
        view?.set(mnemonic: mnemonic)
        self.mnemonic = mnemonic
    }

    func didReceiveMnemonicGeneration(error: Error) {
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

extension AccountCreatePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        selectedCryptoType = CryptoType.allCases[index]

        applySubstrateCryptoTypeViewModel()
        applySubstrateDerivationPathViewModel()

        view?.didCompleteCryptoTypeSelection()
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        view?.didCompleteCryptoTypeSelection()
    }
}

extension AccountCreatePresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            applySubstrateCryptoTypeViewModel()
            applyEthereumCryptoTypeViewModel()
        }
    }
}

private extension Optional where Wrapped == String {
    func nonEmpty(or defaultValue: String) -> String {
        guard let self = self, !self.isEmpty else {
            return defaultValue
        }

        return self
    }
}
