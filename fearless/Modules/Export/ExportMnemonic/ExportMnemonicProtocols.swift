protocol ExportMnemonicInteractorInputProtocol: class {
    func fetchExportDataForAddress(_ address: String)
}

protocol ExportMnemonicInteractorOutputProtocol: class {
    func didReceive(exportData: ExportMnemonicData)
    func didReceive(error: Error)
}

protocol ExportMnemonicWireframeProtocol: ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?)
}

protocol ExportMnemonicViewFactoryProtocol: class {
    static func createViewForAddress(_ address: String) -> ExportGenericViewProtocol?
}
