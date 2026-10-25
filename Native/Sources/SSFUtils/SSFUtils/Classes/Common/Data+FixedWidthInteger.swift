import Foundation

extension Data {
    enum Endianness {
        case BigEndian
        case LittleEndian
    }

    func scanValue<T: FixedWidthInteger>(
        at index: Data.Index,
        endianness: Endianness
    ) -> T {
        let number: T = subdata(in: index ..< index + MemoryLayout<T>.size)
            .withUnsafeBytes { $0.pointee }
        switch endianness {
        case .BigEndian:
            return number.bigEndian
        case .LittleEndian:
            return number.littleEndian
        }
    }
}
