import Foundation

/// Runtime metadata of live chains, cut down to the call enums that the call encoding tests need.
/// Test support only: no product depends on this target. See README.md for how the files are made.
public struct RuntimeMetadataFixture {
    public enum Name: String, CaseIterable {
        case polkadotAssetHub = "polkadot-asset-hub-2005000"
        case polkadot = "polkadot-2005000"
        case acala = "acala-2370"
        case sora = "sora-134"
        case liberland = "liberland-34"
    }

    /// What the unmodified chain metadata says about the kept pallets, read with an independent
    /// decoder before the metadata was cut down.
    public struct Manifest: Decodable {
        public struct Pallet: Decodable {
            public struct Call: Decodable {
                public let name: String
                /// The variant index the runtime dispatches the call by.
                public let index: UInt8
                /// Place of the call in the pallet's call list.
                public let position: Int
                public let fields: [String]
            }

            public let name: String
            public let moduleIndex: UInt8
            public let calls: [Call]
        }

        public let chain: String
        public let genesisHash: String
        public let specVersion: UInt32
        public let fetched: String
        public let pallets: [Pallet]
    }

    public enum LoadingError: Error {
        case resourceMissing(String)
        case invalidHex(String)
    }

    public let name: Name
    /// SCALE encoded V14 runtime metadata, starting with the `meta` magic.
    public let metadata: Data
    public let manifest: Manifest

    public static func load(_ name: Name) throws -> RuntimeMetadataFixture {
        let hex = try String(contentsOf: url(of: name.rawValue, extension: "hex"))
        let manifestData = try Data(
            contentsOf: url(of: name.rawValue + ".manifest", extension: "json")
        )

        return try RuntimeMetadataFixture(
            name: name,
            metadata: decode(hex: hex),
            manifest: JSONDecoder().decode(Manifest.self, from: manifestData)
        )
    }

    private static func url(of resource: String, extension fileExtension: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: resource, withExtension: fileExtension) else {
            throw LoadingError.resourceMissing("\(resource).\(fileExtension)")
        }

        return url
    }

    private static func decode(hex: String) throws -> Data {
        var digits = Substring(hex.trimmingCharacters(in: .whitespacesAndNewlines))
        if digits.hasPrefix("0x") {
            digits = digits.dropFirst(2)
        }

        guard digits.count.isMultiple(of: 2) else {
            throw LoadingError.invalidHex("odd number of digits")
        }

        var bytes = Data(capacity: digits.count / 2)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index ..< next], radix: 16) else {
                throw LoadingError.invalidHex(String(digits[index ..< next]))
            }

            bytes.append(byte)
            index = next
        }

        return bytes
    }
}
