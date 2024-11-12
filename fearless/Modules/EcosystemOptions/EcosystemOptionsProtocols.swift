import SSFModels

typealias EcosystemOptionsModuleCreationResult = (
    view: EcosystemOptionsViewInput,
    input: EcosystemOptionsModuleInput
)

protocol EcosystemOptionsRouterInput: AnyDismissable {}

protocol EcosystemOptionsModuleInput: AnyObject {}

protocol EcosystemOptionsModuleOutput: AnyObject {
    func showMnemonicExport(flow: ExportFlow)
    func showKeystoreExport(flow: ExportFlow)
    func showSeedExport(flow: ExportFlow)
    func showWalletDetails(chains: [ChainModel]?)
}
