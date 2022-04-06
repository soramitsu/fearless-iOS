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
    func didTapExportSubstrateButton() {}

    func didTapExportEthereumButton() {}

    func setup() {
        switch flow {
        case let .single(chain, address):
            interactor.fetchExportDataForAddress(address, chain: chain)
        case let .multiple(wallet, accounts):
            interactor.fetchExportDataForWallet(wallet: wallet, accounts: flow.exportingAccounts)
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
        // TODO: Support custom accounts
        guard let exportData = exportDatas?.first else {
            return
        }

        wireframe.openConfirmationForMnemonic(exportData.mnemonic, from: view)
    }
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

        let multipleExportViewModel = MultiExportViewModel(viewModels: viewModels)
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
