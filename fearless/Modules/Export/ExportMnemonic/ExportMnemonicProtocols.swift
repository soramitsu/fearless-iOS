import IrohaCrypto
import SSFModels

protocol ExportMnemonicInteractorInputProtocol: AnyObject {
    func cancelExport()
    func fetchExportDataForWallet(wallet: MetaAccountModel, accounts: [ChainAccountInfo])
    func fetchExportDataForAddress(_ address: String, chain: ChainModel, wallet: MetaAccountModel)
}

protocol ExportMnemonicInteractorOutputProtocol: AnyObject {
    func didReceive(exportDatas: [ExportMnemonicData])
    func didReceive(exportDatas: [ExportMnemonicData], notShown: [ExportMnemonicNotShown])
    func didReceive(error: Error)
}

protocol ExportMnemonicWireframeProtocol: ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?)
    func showJsonExport(flow: ExportFlow, from view: ExportGenericViewProtocol?)
    func openConfirmationForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel,
        backupProof: VerifiedMnemonicBackup?,
        from view: ExportGenericViewProtocol?
    )
    func openConfirmationForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel,
        from view: ExportGenericViewProtocol?
    )
}

protocol ExportMnemonicViewFactoryProtocol: AnyObject {
    static func createViewForAddress(flow: ExportFlow) -> ExportGenericViewProtocol?
}

extension ExportMnemonicInteractorInputProtocol {
    func cancelExport() {}
}

extension ExportMnemonicInteractorOutputProtocol {
    func didReceive(exportDatas: [ExportMnemonicData], notShown: [ExportMnemonicNotShown]) {
        if exportDatas.isEmpty, let error = notShown.first?.error {
            didReceive(error: error)
        } else {
            didReceive(exportDatas: exportDatas)
        }
    }
}

extension ExportMnemonicWireframeProtocol {
    func openConfirmationForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel,
        backupProof _: VerifiedMnemonicBackup?,
        from view: ExportGenericViewProtocol?
    ) {
        openConfirmationForMnemonic(mnemonic, wallet: wallet, from: view)
    }

    func showJsonExport(flow: ExportFlow, from view: ExportGenericViewProtocol?) {
        guard let passwordView = AccountExportPasswordViewFactory.createView(flow: flow) else { return }
        view?.controller.navigationController?.pushViewController(passwordView.controller, animated: true)
    }
}
