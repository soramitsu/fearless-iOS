protocol ExportSeedInteractorInputProtocol: AnyObject {
    func fetchExportDataForAddress(_ address: String)
}

protocol ExportSeedInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: ExportSeedData)
    func didReceive(error: Error)
}

protocol ExportSeedWireframeProtocol: ExportGenericWireframeProtocol {}

protocol ExportSeedViewFactoryProtocol: AnyObject {
    static func createViewForAddress(_ address: String) -> ExportGenericViewProtocol?
}
