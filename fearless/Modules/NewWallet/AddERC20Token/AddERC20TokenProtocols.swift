import Foundation
import SSFModels
import RobinHood
import Web3

protocol AddERC20TokenModuleOutput: AnyObject {
    func didFinishAddingToken()
}

protocol AddERC20TokenViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: AddERC20TokenViewModel)
    func didReceive(isLoading: Bool)
    func didReceive(selectNetworkViewModel: SelectNetworkViewModel?)
}

protocol AddERC20TokenViewOutput: AnyObject {
    func didLoad(view: AddERC20TokenViewInput)
    func didTapSave()
    func didChangeTokenAddress(_ address: String)
    func didTapSelectNetwork()
}

protocol AddERC20TokenInteractorInput: AnyObject {
    func setup(with output: AddERC20TokenInteractorOutput)
    func validateAndFetchToken(address: String, chain: ChainModel) async throws
    func saveToken(_ token: ERC20TokenInfo, for chain: ChainModel)
}

protocol AddERC20TokenInteractorOutput: AnyObject {
    func didReceive(tokenInfo: ERC20TokenInfo)
    func didReceive(error: Error)
    func didFinishSavingToken()
}

protocol AddERC20TokenRouterInput: AnyObject, AnyDismissable, ErrorPresentable, SheetAlertPresentable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        contextTag: Int?,
        delegate: SelectNetworkDelegate?
    )
}

protocol AddERC20TokenModuleInput: AnyObject {}

typealias AddERC20TokenModuleCreationResult = (view: AddERC20TokenViewInput, input: AddERC20TokenModuleInput)

struct ERC20TokenInfo {
    let address: String
    let name: String
    let symbol: String
    let decimals: UInt8
    let totalSupply: BigUInt
}

struct AddERC20TokenViewModel {
    let tokenAddress: String
    let tokenName: String?
    let tokenSymbol: String?
    let tokenDecimals: UInt8?
    let tokenTotalSupply: BigUInt?
    let isSaveEnabled: Bool
    let isLoading: Bool
} 
