import Foundation
import FearlessUtils

struct IdentityInfo: ScaleDecodable {
    let additional: [ChainData: ChainData]
    let display: ChainData
    let legal: ChainData
    let web: ChainData
    let riot: ChainData
    let email: ChainData
    let pgpFingerprint: H160?
    let image: ChainData
    let twitter: ChainData

    init(scaleDecoder: ScaleDecoding) throws {
        additional = try [ChainData: ChainData](scaleDecoder: scaleDecoder)
        display = try ChainData(scaleDecoder: scaleDecoder)
        legal = try ChainData(scaleDecoder: scaleDecoder)
        web = try ChainData(scaleDecoder: scaleDecoder)
        riot = try ChainData(scaleDecoder: scaleDecoder)
        email = try ChainData(scaleDecoder: scaleDecoder)

        switch try ScaleOption<H160>(scaleDecoder: scaleDecoder) {
        case .none:
            pgpFingerprint = nil
        case .some(let value):
            pgpFingerprint = value
        }

        image = try ChainData(scaleDecoder: scaleDecoder)
        twitter = try ChainData(scaleDecoder: scaleDecoder)
    }
}

enum IdentityJudgementError: Error {
    case undefined(value: UInt8)
}

enum IdentityJudgement: ScaleCodable {
    case unknown
    case freePaid(Balance)
    case reasonable
    case knownGood
    case outOfDate
    case lowQuality
    case erroneous

    init(scaleDecoder: ScaleDecoding) throws {
        let firstByte = try UInt8(scaleDecoder: scaleDecoder)

        switch firstByte {
        case 0:
            self = .unknown
        case 1:
            let balance = try Balance(scaleDecoder: scaleDecoder)
            self = .freePaid(balance)
        case 2:
            self = .reasonable
        case 3:
            self = .knownGood
        case 4:
            self = .outOfDate
        case 5:
            self = .lowQuality
        case 6:
            self = .erroneous
        default:
            throw IdentityJudgementError.undefined(value: firstByte)
        }
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        switch self {
        case .unknown:
            try UInt8(0).encode(scaleEncoder: scaleEncoder)
        case .freePaid(let balance):
            try UInt8(1).encode(scaleEncoder: scaleEncoder)
            try balance.encode(scaleEncoder: scaleEncoder)
        case .reasonable:
            try UInt8(2).encode(scaleEncoder: scaleEncoder)
        case .knownGood:
            try UInt8(3).encode(scaleEncoder: scaleEncoder)
        case .outOfDate:
            try UInt8(4).encode(scaleEncoder: scaleEncoder)
        case .lowQuality:
            try UInt8(5).encode(scaleEncoder: scaleEncoder)
        case .erroneous:
            try UInt8(6).encode(scaleEncoder: scaleEncoder)
        }
    }
}

struct IdentityRegistrationJudgement: ScaleCodable {
    let registrarIndex: UInt32
    let judgement: IdentityJudgement

    init(scaleDecoder: ScaleDecoding) throws {
        registrarIndex = try UInt32(scaleDecoder: scaleDecoder)
        judgement = try IdentityJudgement(scaleDecoder: scaleDecoder)
    }

    func encode(scaleEncoder: ScaleEncoding) throws {
        try registrarIndex.encode(scaleEncoder: scaleEncoder)
        try judgement.encode(scaleEncoder: scaleEncoder)
    }
}

struct IdentityRegistration: ScaleDecodable {
    let judgements: [IdentityRegistrationJudgement]
    let deposit: Balance
    let info: IdentityInfo

    init(scaleDecoder: ScaleDecoding) throws {
        judgements = try [IdentityRegistrationJudgement](scaleDecoder: scaleDecoder)
        deposit = try Balance(scaleDecoder: scaleDecoder)
        info = try IdentityInfo(scaleDecoder: scaleDecoder)
    }
}
