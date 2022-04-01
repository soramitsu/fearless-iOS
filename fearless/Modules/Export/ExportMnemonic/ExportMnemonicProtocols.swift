import IrohaCrypto

protocol ExportMnemonicInteractorInputProtocol: AnyObject {
    func fetchExportDataForWallet(_ wallet: MetaAccountModel)
    func fetchExportDataForAddress(_ address: String, chain: ChainModel)
}

protocol ExportMnemonicInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: ExportMnemonicData)
    func didReceive(error: Error)
}

protocol ExportMnemonicWireframeProtocol: ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?)
    func openConfirmationForMnemonic(_ mnemonic: IRMnemonicProtocol, from view: ExportGenericViewProtocol?)
}

protocol ExportMnemonicViewFactoryProtocol: AnyObject {
    static func createViewForAddress(flow: ExportFlow) -> ExportGenericViewProtocol?
}
