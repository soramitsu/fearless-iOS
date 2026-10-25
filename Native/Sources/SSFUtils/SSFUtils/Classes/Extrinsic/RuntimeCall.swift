import Foundation

public protocol RuntimeCallable: Codable {
    associatedtype Args: Codable

    var moduleName: String { get }
    var callName: String { get }
    var args: Args { get }
}

public struct NoRuntimeArgs: Codable {}

public struct RuntimeCall<T: Codable>: RuntimeCallable {
    public typealias Args = T

    public let moduleName: String
    public let callName: String
    public let args: Args

    public init(moduleName: String, callName: String, args: T) {
        self.moduleName = moduleName
        self.callName = callName
        self.args = args
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        moduleName = try container.decode(String.self)
        var nested = try container.nestedUnkeyedContainer()
        callName = try nested.decode(String.self)
        args = try nested.decode(Args.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(moduleName)
        var nested = container.nestedUnkeyedContainer()
        try nested.encode(callName)
        try nested.encode(args)
    }
}

public extension RuntimeCall where T == NoRuntimeArgs {
    init(moduleName: String, callName: String) {
        self.moduleName = moduleName
        self.callName = callName
        args = NoRuntimeArgs()
    }
}
