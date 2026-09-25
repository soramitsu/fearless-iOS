import Foundation

extension IOSPortableWalletSemanticMaterial {
    struct AssetRowPresentation: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let chainID: String
        let assetID: String
        let accountID: [UInt8]
        let enabled: Bool?
        let sortIndex: Int32
        let markedNotNeed: Bool
        let chainAccountName: String?

        var description: String { "AssetRowPresentation(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }

        static func == (left: Self, right: Self) -> Bool {
            let namesMatch: Bool
            switch (left.chainAccountName, right.chainAccountName) {
            case (nil, nil):
                namesMatch = true
            case let (leftName?, rightName?):
                namesMatch = Array(leftName.utf8) == Array(rightName.utf8)
            default:
                namesMatch = false
            }
            return Array(left.chainID.utf8) == Array(right.chainID.utf8) &&
                Array(left.assetID.utf8) == Array(right.assetID.utf8) &&
                left.accountID == right.accountID && left.enabled == right.enabled &&
                left.sortIndex == right.sortIndex && left.markedNotNeed == right.markedNotNeed &&
                namesMatch
        }
    }

    static func decodeAssetRowPresentation(_ value: [UInt8]) throws -> [AssetRowPresentation] {
        try ensure(value.count <= maxSecret)
        var cursor = Cursor(bytes: value)
        defer { cursor.erase() }
        let version = try cursor.readByte()
        try ensure(version == 1)
        let count = try cursor.readUInt16()
        try ensure(count > 0 && count <= (value.count - 3) / 15)
        var rows = [AssetRowPresentation]()
        rows.reserveCapacity(count)
        for _ in 0 ..< count {
            let chainID = try cursor.readText(allowEmpty: false)
            let assetID = try cursor.readText(allowEmpty: false)
            let accountID = try cursor.readValue(maximum: maxPublic)
            let enabledCode = try cursor.readByte()
            try ensure(enabledCode <= 2)
            let enabled: Bool? = enabledCode == 0 ? nil : enabledCode == 2
            let sortIndex = Int32(bitPattern: try cursor.readUInt32())
            let markedNotNeed = try cursor.readBoolean()
            let namePresent = try cursor.readBoolean()
            let chainAccountName = namePresent ? try cursor.readText(allowEmpty: true) : nil
            try ensure(enabled != nil || sortIndex != Int32.max || markedNotNeed || chainAccountName != nil)
            if let previous = rows.last {
                let previousChainID = Array(previous.chainID.utf8)
                let chainIDBytes = Array(chainID.utf8)
                let previousAssetID = Array(previous.assetID.utf8)
                let assetIDBytes = Array(assetID.utf8)
                let ascending: Bool
                if previousChainID != chainIDBytes {
                    ascending = previousChainID.lexicographicallyPrecedes(chainIDBytes)
                } else if previousAssetID != assetIDBytes {
                    ascending = previousAssetID.lexicographicallyPrecedes(assetIDBytes)
                } else {
                    ascending = previous.accountID.lexicographicallyPrecedes(accountID)
                }
                try ensure(ascending)
            }
            rows.append(AssetRowPresentation(
                chainID: chainID, assetID: assetID, accountID: accountID,
                enabled: enabled, sortIndex: sortIndex,
                markedNotNeed: markedNotNeed, chainAccountName: chainAccountName
            ))
        }
        try ensure(cursor.isAtEnd)
        return rows
    }
}
