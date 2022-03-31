import Foundation
import SoraFoundation
import FearlessUtils

final class ExportMnemonicPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportMnemonicWireframeProtocol!
    var interactor: ExportMnemonicInteractorInputProtocol!

    let flow: ExportFlow
    let localizationManager: LocalizationManager

    private(set) var exportData: ExportMnemonicData?

    init(flow: ExportFlow, localizationManager: LocalizationManager) {
        self.flow = flow
        self.localizationManager = localizationManager
    }

    private func share() {
//        guard let data = exportData else {
//            return
//        }
//
//        let text: String
//
//        let locale = localizationManager.selectedLocale
//
//        if let derivationPath = exportData?.derivationPath {
//            text = R.string.localizable
//                .exportMnemonicWithDpTemplate(
//                    chain.name,
//                    data.mnemonic.toString(),
//                    derivationPath,
//                    preferredLanguages: locale.rLanguages
//                )
//        } else {
//            text = R.string.localizable
//                .exportMnemonicWithoutDpTemplate(
//                    chain.name,
//                    data.mnemonic.toString(),
//                    preferredLanguages: locale.rLanguages
//                )
//        }
//
//        wireframe.share(source: TextSharingSource(message: text), from: view) { [weak self] completed in
//            if completed {
//                self?.wireframe.close(view: self?.view)
//            }
//        }
    }
}

extension ExportMnemonicPresenter: ExportGenericPresenterProtocol {
    func didTapExportSubstrateButton() {}

    func didTapExportEthereumButton() {}

    func setup() {
        switch flow {
        case let .single(chain, address):
            interactor.fetchExportDataForAddress(address, chain: chain)
        case let .multiple(account):
            break
        }
    }

    func activateExport() {
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let exportTitle = R.string.localizable.accountExportAction(preferredLanguages: locale.rLanguages)
        let exportAction = AlertPresentableAction(title: exportTitle) { [weak self] in
            self?.share()
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction],
            closeAction: cancelTitle
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }

    func activateAccessoryOption() {
        guard let exportData = exportData else {
            return
        }

        wireframe.openConfirmationForMnemonic(exportData.mnemonic, from: view)
    }
}

extension ExportMnemonicPresenter: ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportData _: ExportMnemonicData) {
//        self.exportData = exportData
//        let viewModel = ExportMnemonicViewModel(
//            option: .mnemonic,
//            chain: chain,
//            cryptoType: exportData.cryptoType,
//            derivationPath: exportData.derivationPath,
//            mnemonic: exportData.mnemonic.allWords()
//        )
//
//        let multipleExportViewModel = MultiExportViewModel(viewModels: [viewModel])
//        view?.set(viewModel: multipleExportViewModel)
    }

    func didReceive(error: Error) {
        if !wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
