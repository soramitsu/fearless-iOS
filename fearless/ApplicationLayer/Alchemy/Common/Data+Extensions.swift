import Foundation

public extension Data {
    init<T>(from value: T) {
        var value = value
        self.init(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }

    func toHexString() -> String {
        "0x" + hex
    }

    var bytes: [UInt8] {
        Array(self)
    }

    func to<T>(type _: T.Type) -> T {
        withUnsafeBytes { $0.load(as: T.self) }
    }
}
