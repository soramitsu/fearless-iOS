import Foundation

struct NetworkInfoMode: OptionSet {
    typealias RawValue = UInt8

    static let none: NetworkInfoMode = []
    static let name = NetworkInfoMode(rawValue: 1)
    static let node = NetworkInfoMode(rawValue: 2)
    static let all: NetworkInfoMode = [.name, .node]

    var rawValue: NetworkInfoMode.RawValue

    init(rawValue: NetworkInfoMode.RawValue) {
        self.rawValue = rawValue
    }
}
