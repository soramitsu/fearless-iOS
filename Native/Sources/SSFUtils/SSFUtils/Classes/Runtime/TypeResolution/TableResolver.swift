import Foundation

public class TableResolver: TypeResolving {
    let mapping: [String: String]

    public init(mapping: [String: String]) {
        self.mapping = mapping
    }

    public func resolve(typeName: String, using availableNames: Set<String>) -> String? {
        let key = typeName.lowercased()
        if let mapped = mapping[key], availableNames.contains(mapped) {
            return mapped
        }

        return nil
    }
}

public extension TableResolver {
    static func noise() -> TableResolver {
        let mapping: [String: String] = [
            "()": "Null",
            "vec<u8>": "Bytes",
            "&[u8]": "Bytes",
            "<lookup as staticlookup>::source": "LookupSource",
            "<t::lookup as staticlookup>::source": "LookupSource",
            "<inherentofflinereport as inherentofflinereport>::inherent": "InherentOfflineReport",
            "<balance as hascompact>::type": "Compact<Balance>",
            "<blocknumber as hascompact>::type": "Compact<BlockNumber>",
            "<moment as hascompact>::type": "Compact<Moment>",
        ]

        return TableResolver(mapping: mapping)
    }
}
