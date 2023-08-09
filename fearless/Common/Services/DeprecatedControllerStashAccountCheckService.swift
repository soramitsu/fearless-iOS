import SSFModels

final class DeprecatedControllerStashAccountCheckService {
    private let callFactory: SubstrateCallFactoryProtocol
    
    init(callFactory: SubstrateCallFactoryProtocol) {
        self.callFactory = callFactory
    }
    
    func checkAccountDeprecations(address: AccountAddress, chainAsset: ChainAsset) -> Bool {
        do {
            let setController = try callFactory.setController(address, chainAsset: chainAsset)
            
        }
        catch {
            return false
        }
    }
}
