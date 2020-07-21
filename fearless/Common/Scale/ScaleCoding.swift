import Foundation

protocol ScaleEncodable {
    func encode(scaleEncoder: ScaleEncoding) throws
}

protocol ScaleDecodable {
    init(scaleDecoder: ScaleDecoding) throws
}

typealias ScaleCodable = ScaleEncodable & ScaleDecodable

protocol ScaleEncoding: class {
    func appendRaw(data: Data)
    func encode() -> Data
}

protocol ScaleDecoding: class {
    var remained: Int { get }
    func read(count: Int) throws -> Data
    func confirm(count: Int) throws
}

extension ScaleDecoding {
    func readAndConfirm(count: Int) throws -> Data {
        let data = try read(count: count)
        try confirm(count: count)
        return data
    }
}

final class ScaleEncoder: ScaleEncoding {
    var data: Data = Data()

    func appendRaw(data: Data) {
        self.data.append(data)
    }

    func encode() -> Data {
        return data
    }
}

enum ScaleDecoderError: Error {
    case outOfBounds
}

final class ScaleDecoder: ScaleDecoding {
    let data: Data

    private var pointer: Int = 0

    var remained: Int {
        data.count - pointer
    }

    init(data: Data) throws {
        self.data = data
    }

    func read(count: Int) throws -> Data {
        guard pointer + count <= data.count else {
            throw ScaleDecoderError.outOfBounds
        }

        return Data(data[pointer..<(pointer + count)])
    }

    func confirm(count: Int) throws {
        guard pointer + count <= data.count else {
            throw ScaleDecoderError.outOfBounds
        }

        pointer += count
    }
}
