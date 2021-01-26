import Foundation
import FearlessUtils

struct EraRewardPoints: ScaleDecodable {
    let total: UInt32
    let individuals: [IndividualRewardPoints]

    init(scaleDecoder: ScaleDecoding) throws {
        total = try UInt32(scaleDecoder: scaleDecoder)
        individuals = try [IndividualRewardPoints](scaleDecoder: scaleDecoder)
    }

    init(total: UInt32, individuals: [IndividualRewardPoints]) {
        self.total = total
        self.individuals = individuals
    }
}

struct IndividualRewardPoints: ScaleCodable {
    let accountId: Data
    let points: UInt32

    init(scaleDecoder: ScaleDecoding) throws {
        accountId = try scaleDecoder.readAndConfirm(count: 32)
        points = try UInt32(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        scaleEncoder.appendRaw(data: accountId)
        try points.encode(scaleEncoder: scaleEncoder)
    }
}
