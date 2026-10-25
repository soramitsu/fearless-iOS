import Foundation

public struct H256: FixedLengthDataStoring, Equatable {
    public static var length: Int { 32 }

    public let value: Data

    public init(value: Data) {
        self.value = value
    }
}
