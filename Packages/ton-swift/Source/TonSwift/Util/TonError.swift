import Foundation

public enum TonError: Error {
    case indexOutOfBounds(Int)
    case offsetOutOfBounds(Int)
    case custom(String)
    case varUIntOutOfBounds(limit: Int, actualBits: Int)
}

extension TonError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .indexOutOfBounds(let index):
            return "Index \(index) is out of bounds"
            
        case .offsetOutOfBounds(let offset):
            return "Offset \(offset) is out of bounds"
        
        case .varUIntOutOfBounds(let limit, let actualBits):
            return "VarUInteger is out of bounds: the (VarUInt \(limit)) specifies max size \((limit-1)*8) bits long, but the actual number is \(actualBits) bits long"
            
        case .custom(let text):
            return text
        }
    }
}
