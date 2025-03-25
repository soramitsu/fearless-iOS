import Foundation

protocol AddERC20TokenInteractorInput: AnyObject {
    func setup(with output: AddERC20TokenInteractorOutput)
    func validateAndFetchToken(address: String)
    func saveToken(_ token: ERC20TokenInfo)
} 