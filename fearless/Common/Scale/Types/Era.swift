import Foundation
import FearlessUtils
import BigInt

enum Era {
    case immortal
    case mortal(period: UInt64, phase: UInt64)
}

enum EraCodingError: Error {
    case undefinedValue
    case unsupported
    case invalidPeriod
    case phaseAndPeriodMismatch
}

extension Era: ScaleCodable {
    init(scaleDecoder: ScaleDecoding) throws {
        let firstByte = try UInt8(scaleDecoder: scaleDecoder)

        guard firstByte > 0 else {
            self = .immortal
            return
        }

        let secondByte = try UInt8(scaleDecoder: scaleDecoder)

        let encoded = UInt64(firstByte) + (UInt64(secondByte) << 8)
        let period = 2 << (encoded % (1 << 4))
        let quantizeFactor = max(period >> 12, 1)
        let phase = (encoded >> 4) * quantizeFactor

        guard period >= 4 else {
            throw EraCodingError.invalidPeriod
        }

        guard phase < period else {
            throw EraCodingError.phaseAndPeriodMismatch
        }

        self = .mortal(period: period, phase: phase)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .immortal:
            try UInt8(0).encode(scaleEncoder: scaleEncoder)
        case .mortal:
            throw EraCodingError.unsupported
        }
    }
}
