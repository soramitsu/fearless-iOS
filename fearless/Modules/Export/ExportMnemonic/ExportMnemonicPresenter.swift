import Foundation
import SoraFoundation

final class ExportMnemonicPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportMnemonicWireframeProtocol!
    var interactor: ExportMnemonicInteractorInputProtocol!

    let address: String
    let localizationManager: LocalizationManager

    init(address: String, localizationManager: LocalizationManager) {
        self.address = address
        self.localizationManager = localizationManager
    }
}

extension ExportMnemonicPresenter: ExportGenericPresenterProtocol {
    func setup() {
        interactor.fetchExportDataForAddress(address)
    }

    func activateExport() {

    }

    func activateAccessoryOption() {
        
    }
}

extension ExportMnemonicPresenter: ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportData: ExportMnemonicData) {
        let viewModel = ExportMnemonicViewModel(option: .mnemonic,
                                                networkType: exportData.networkType,
                                                derivationPath: exportData.derivationPath,
                                                cryptoType: exportData.account.cryptoType,
                                                mnemonic: exportData.mnemonic)
        view?.set(viewModel: viewModel)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(error: CommonError.undefined,
                                  from: view,
                                  locale: localizationManager.selectedLocale)
        }
    }
}
