import Foundation
import FearlessFoundation
import IrohaCrypto
import SSFUtils
import SSFModels

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
}

extension ExportMnemonicPresenter: ExportGenericPresenterProtocol {
    func didLoadView() {
        let locale = localizationManager.selectedLocale

        let title = R.string.localizable.accountExportWarningTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.accountExportWarningMessage(preferredLanguages: locale.rLanguages)

        let exportTitle = R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages)
        let exportAction = SheetAlertPresentableAction(title: exportTitle, style: .pinkBackgroundWhiteText)

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(title: cancelTitle) { [weak self] in
            self?.wireframe.back(view: self?.view)
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [exportAction, cancelAction],
            closeAction: nil,
            icon: R.image.iconWarningBig()
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
        let mnemonics = uniqueMnemonics()

        guard !mnemonics.isEmpty else {
            return
        }

        wireframe.openConfirmationForMnemonics(mnemonics, wallet: flow.wallet, from: view)
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

private extension ExportMnemonicPresenter {
    func uniqueMnemonics() -> [IRMnemonicProtocol] {
        var seenKeys = Set<String>()

        return (exportDatas ?? []).compactMap { exportData in
            let key = exportData.mnemonic.allWords().joined(separator: "\n")

            guard seenKeys.insert(key).inserted else {
                return nil
            }

            return exportData.mnemonic
        }
    }
}
