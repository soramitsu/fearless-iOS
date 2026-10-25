import Foundation

public struct H512: FixedLengthDataStoring, Equatable {
    public static var length: Int { 64 }

    public let value: Data

    public init(value: Data) {
        self.value = value
    }
}
