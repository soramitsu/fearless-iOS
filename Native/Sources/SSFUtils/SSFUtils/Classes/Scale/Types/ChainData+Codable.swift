import Foundation

extension ChainData: Codable {
    private enum Case: String, CaseIterable {
        case none = "None"
        case raw
        case blakeTwo256 = "BlakeTwo256"
        case sha256 = "Sha256"
        case keccak256 = "Keccak256"
        case shaThree256 = "ShaThree256"
        
        static func from(rawValue: String) -> Case? {
            if rawValue.lowercased().contains("raw") {
                return .raw
            }
            
            return Case(rawValue: rawValue)
        }
        
        var intValue: UInt8 {
            switch self {
            case .none: return 0
            case .raw: return 1
            case .blakeTwo256: return 2
            case .sha256: return 3
            case .keccak256: return 4
            case .shaThree256: return 5
            }
        }
        
        static func from(intValue: UInt8) -> Case? {
            for entr in allCases {
                if entr.intValue == intValue {
                    return entr
                }
            }
            
            return nil
        }
    }
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var type: Case
        do {
            let typeString = try container.decode(String.self)
            guard let typeFromString = Case.from(rawValue: typeString) else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "unexpected type found: \(typeString)")
            }
            type = typeFromString
        } catch {
            let typeInt = try container.decode(UInt8.self)
            guard let typeFromInt = Case.from(intValue: typeInt) else {
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "unexpected type found: \(typeInt)")
            }
            type = typeFromInt
        }
        
        if type == .none {
            self = .none
        } else {
            var data: Data
            do {
                data = try container.decode(Data.self)
            } catch {
                let datas = try container.decode([String].self)
                data = datas.compactMap { try? Data(hexStringSSF: $0) }.reduce(Data(), +)
            }

            switch type {
            case .raw:
                self = .raw(data: data)
            case .blakeTwo256:
                self = .blakeTwo256(data: H256(value: data))
            case .sha256:
                self = .sha256(data: H256(value: data))
            case .keccak256:
                self = .keccak256(data: H256(value: data))
            case .shaThree256:
                self = .shaThree256(data: H256(value: data))
            default:
                throw DecodingError.dataCorruptedError(in: container,
                                                       debugDescription: "unexpected type found: \(type)")
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .none:
            try container.encode(Case.none.rawValue)
        case .raw(let data):
            try container.encode(Case.raw.rawValue)
            try container.encode(data)
        case .blakeTwo256(let hash):
            try container.encode(Case.blakeTwo256.rawValue)
            try container.encode(hash.value)
        case .sha256(let hash):
            try container.encode(Case.sha256.rawValue)
            try container.encode(hash.value)
        case .keccak256(let hash):
            try container.encode(Case.keccak256.rawValue)
            try container.encode(hash.value)
        case .shaThree256(let hash):
            try container.encode(Case.shaThree256.rawValue)
            try container.encode(hash.value)
        }
    }
}
