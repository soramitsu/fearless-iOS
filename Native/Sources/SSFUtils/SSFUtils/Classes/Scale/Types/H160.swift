import Foundation

public struct H160: FixedLengthDataStoring, Equatable {
    public static var length: Int { 20 }

    public let value: Data

    public init(value: Data) {
        self.value = value
    }
}
