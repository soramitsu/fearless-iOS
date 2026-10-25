import Foundation

public enum ChaincodeType {
    case soft
    case hard
}

public struct Chaincode: Equatable {
    public let data: Data
    public let type: ChaincodeType

    public init(data: Data, type: ChaincodeType) {
        self.data = data
        self.type = type
    }
}
