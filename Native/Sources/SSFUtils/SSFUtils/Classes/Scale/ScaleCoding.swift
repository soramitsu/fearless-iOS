import Foundation

public protocol ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws
}

public protocol ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws
}

public typealias ScaleCodable = ScaleDecodable & ScaleEncodable

public protocol ScaleEncoding: AnyObject {
    func appendRaw(data: Data)
    func encode() -> Data
}

public protocol ScaleDecoding: AnyObject {
    var remained: Int { get }
    func read(count: Int) throws -> Data
    func confirm(count: Int) throws
}

public extension ScaleDecoding {
    func readAndConfirm(count: Int) throws -> Data {
        let data = try read(count: count)
        try confirm(count: count)
        return data
    }
}

public final class ScaleEncoder: ScaleEncoding {
    var data: Data = .init()

    public init() {}

    public func appendRaw(data: Data) {
        self.data.append(data)
    }

    public func encode() -> Data {
        data
    }
}

public enum ScaleDecoderError: Error {
    case outOfBounds
}

public final class ScaleDecoder: ScaleDecoding {
    let data: Data

    private var pointer: Int = 0

    public var remained: Int {
        data.count - pointer
    }

    public init(data: Data) throws {
        self.data = data
    }

    public func read(count: Int) throws -> Data {
        guard pointer + count <= data.count else {
            throw ScaleDecoderError.outOfBounds
        }

        return Data(data[pointer ..< (pointer + count)])
    }

    public func confirm(count: Int) throws {
        guard pointer + count <= data.count else {
            throw ScaleDecoderError.outOfBounds
        }

        pointer += count
    }
}
