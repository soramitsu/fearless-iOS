import SSFModels

protocol ExportSeedInteractorInputProtocol: AnyObject {
    func fetchExportDataForAddress(_ address: String, chain: ChainModel, wallet: MetaAccountModel)
    func fetchExportDataForWallet(_ wallet: MetaAccountModel, accounts: [ChainAccountInfo])
    func didBackupSeed(wallet: MetaAccountModel, completion: @escaping (Result<Void, Error>) -> Void)
}

protocol ExportSeedInteractorOutputProtocol: AnyObject {
    /// `notShown` lists the requested accounts whose seed is not in `exportData`.
    func didReceive(exportData: [ExportSeedData], notShown: [ExportSeedNotShown])
    func didReceive(error: Error)
}

protocol ExportSeedWireframeProtocol: ExportGenericWireframeProtocol {
    /// The JSON export of the same accounts; the user has already authenticated.
    func showJsonExport(flow: ExportFlow, from view: ExportGenericViewProtocol?)
}

protocol ExportSeedViewFactoryProtocol: AnyObject {
    static func createViewForAddress(flow: ExportFlow) -> ExportGenericViewProtocol?
}
