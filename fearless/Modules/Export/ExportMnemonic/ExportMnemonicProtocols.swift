import IrohaCrypto

protocol ExportMnemonicInteractorInputProtocol: AnyObject {
    func fetchExportDataForAddress(_ address: String)
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
    static func createViewForAddress(_ address: String) -> ExportGenericViewProtocol?
}
