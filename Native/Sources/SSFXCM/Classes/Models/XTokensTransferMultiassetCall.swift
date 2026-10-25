import Foundation

struct XTokensTransferMultiassetCall: Codable {
    let asset: XcmVersionedMultiAsset
    let dest: XcmVersionedMultiLocation
    let destWeightLimit: XcmWeightLimit

    init(
        asset: XcmVersionedMultiAsset,
        dest: XcmVersionedMultiLocation,
        destWeightLimit: XcmWeightLimit
    ) {
        self.asset = asset
        self.dest = dest
        self.destWeightLimit = destWeightLimit
    }

    init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "XTokensTransferMultiassetCall is only ever encoded"
        ))
    }
}
