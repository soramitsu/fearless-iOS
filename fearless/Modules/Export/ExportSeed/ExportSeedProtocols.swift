protocol ExportSeedInteractorInputProtocol: class {
    func fetchExportDataForAddress(_ address: String)
}

protocol ExportSeedInteractorOutputProtocol: class {
    func didReceive(exportData: ExportSeedData)
    func didReceive(error: Error)
}

protocol ExportSeedWireframeProtocol: ExportGenericWireframeProtocol {}

protocol ExportSeedViewFactoryProtocol: class {
    static func createViewForAddress(_ address: String) -> ExportGenericViewProtocol?
}
