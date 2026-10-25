import BigInt
import Foundation

struct XcmV1MultiAsset: Codable {
    enum CodingKeys: String, CodingKey {
        case assetId = "id"
        case fun
    }

    let assetId: XcmV1MultiassetAssetId
    let fun: XcmV1MultiassetFungibility

    init(multilocation: XcmV1MultiLocation, amount: BigUInt) {
        assetId = .concrete(multilocation)
        fun = .fungible(amount: amount)
    }

    init(assetId: XcmV1MultiassetAssetId, fun: XcmV1MultiassetFungibility) {
        self.assetId = assetId
        self.fun = fun
    }
}

extension XcmV1MultiAsset: Equatable {}
