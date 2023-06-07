import IrohaCrypto
import SSFModels

protocol ExportMnemonicInteractorInputProtocol: AnyObject {
    func fetchExportDataForWallet(wallet: MetaAccountModel, accounts: [ChainAccountInfo])
    func fetchExportDataForAddress(_ address: String, chain: ChainModel, wallet: MetaAccountModel)
}

protocol ExportMnemonicInteractorOutputProtocol: AnyObject {
    func didReceive(exportDatas: [ExportMnemonicData])
    func didReceive(error: Error)
}

protocol ExportMnemonicWireframeProtocol: ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?)
    func openConfirmationForMnemonic(_ mnemonic: IRMnemonicProtocol, from view: ExportGenericViewProtocol?)
}

protocol ExportMnemonicViewFactoryProtocol: AnyObject {
    static func createViewForAddress(flow: ExportFlow) -> ExportGenericViewProtocol?
}
