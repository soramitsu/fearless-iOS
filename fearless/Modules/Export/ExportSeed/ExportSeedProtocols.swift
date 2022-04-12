protocol ExportSeedInteractorInputProtocol: AnyObject {
    func fetchExportDataForAddress(_ address: String, chain: ChainModel)
    func fetchExportDataForWallet(_ wallet: MetaAccountModel, accounts: [ChainAccountInfo])
}

protocol ExportSeedInteractorOutputProtocol: AnyObject {
    func didReceive(exportData: [ExportSeedData])
    func didReceive(error: Error)
}

protocol ExportSeedWireframeProtocol: ExportGenericWireframeProtocol {}

protocol ExportSeedViewFactoryProtocol: AnyObject {
    static func createViewForAddress(flow: ExportFlow) -> ExportGenericViewProtocol?
}
