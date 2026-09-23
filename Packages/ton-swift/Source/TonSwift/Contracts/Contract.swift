import Foundation
import BigInt

/// Common interface for all contracts that allows computing contract addresses and messages
public protocol Contract {
    var workchain: Int8 { get }
    var stateInit: StateInit { get }
    func address() throws -> Address
}

extension Contract {
    public func address() throws -> Address {
        let hash = try Builder().store(stateInit).endCell().hash()
        return Address(workchain: workchain, hash: hash)
    }
}

public struct ContractState {
    let balance: BigInt
    let last: ContractStateLast?
    let state: ContractStateStatus
}

public struct ContractStateLast {
    let lt: BigInt
    let hash: Data
}

public enum ContractStateStatus {
    case uninit
    case active(code: Data?, data: Data?)
    case frozen(stateHash: Data?)
}


public struct OpaqueContract: Contract {
    public let workchain: Int8
    public let stateInit: StateInit
    
    init(workchain: Int8, stateInit: StateInit) {
        self.workchain = workchain
        self.stateInit = stateInit
    }
}
