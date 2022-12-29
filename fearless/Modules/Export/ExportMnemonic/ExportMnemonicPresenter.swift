import Foundation
import SoraFoundation
import FearlessUtils

final class ExportMnemonicPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportMnemonicWireframeProtocol!
    var interactor: ExportMnemonicInteractorInputProtocol!

    let flow: ExportFlow
    let localizationManager: LocalizationManager

    private(set) var exportDatas: [ExportMnemonicData]?

    init(flow: ExportFlow, localizationManager: LocalizationManager) {
        self.flow = flow
        self.localizationManager = localizationManager
    }

    private func share() {
        // TODO: Support custom accounts
        guard let exportData = exportDatas?.first else {
            return
        }

        let text: String

        let locale = localizationManager.selectedLocale

        if let derivationPath = exportData.derivationPath {
            text = R.string.localizable
                .exportMnemonicWithDpTemplate(
                    exportData.chain.name,
                    exportData.mnemonic.toString(),
                    derivationPath,
                    preferredLanguages: locale.rLanguages
                )
        } else {
            text = R.string.localizable
                .exportMnemonicWithoutDpTemplate(
                    exportData.chain.name,
                    exportData.mnemonic.toString(),
                    preferredLanguages: locale.rLanguages
                )
        }

        wireframe.share(source: TextSharingSource(message: text), from: view) { [weak self] completed in
            if completed {
                self?.wireframe.close(view: self?.view)
            }
        }
    }
}

extension ExportMnemonicPresenter: ExportGenericPresenterProtocol {
    func didLoadView() {
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let exportTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let exportAction = SheetAlertPresentableAction(title: exportTitle) { [weak self] in
            self?.wireframe.back(view: self?.view)
        }

        let cancelTitle = R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(title: cancelTitle)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction, cancelAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, from: view)
    }

    func setup() {
        switch flow {
        case let .single(chain, address, wallet):
            interactor.fetchExportDataForAddress(address, chain: chain, wallet: wallet)
        case let .multiple(wallet, _):
            interactor.fetchExportDataForWallet(wallet: wallet, accounts: flow.exportingAccounts)
        }
    }

    func activateExport() {
        guard let exportData = exportDatas?.first else {
            return
        }

        wireframe.openConfirmationForMnemonic(exportData.mnemonic, from: view)
    }

    func activateAccessoryOption() {}
}

extension ExportMnemonicPresenter: ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportDatas: [ExportMnemonicData]) {
        self.exportDatas = exportDatas

        let viewModels = exportDatas.compactMap { exportData in
            ExportMnemonicViewModel(
                option: .mnemonic,
                chain: exportData.chain,
                cryptoType: exportData.cryptoType,
                derivationPath: exportData.derivationPath,
                mnemonic: exportData.mnemonic.allWords(),
                ethereumBased: exportData.chain.isEthereumBased
            )
        }

        let multipleExportViewModel = MultiExportViewModel(
            viewModels: viewModels,
            option: .mnemonic,
            flow: flow
        )
        view?.set(viewModel: multipleExportViewModel)
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
