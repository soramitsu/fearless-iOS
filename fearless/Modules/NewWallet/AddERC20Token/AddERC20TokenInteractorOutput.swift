import Foundation

protocol AddERC20TokenInteractorOutput: AnyObject {
    func didReceive(tokenInfo: ERC20TokenInfo)
    func didReceive(error: Error)
} 