import Foundation

enum ExtrinsicCheck: String, CaseIterable {
    case specVersion = "frame_system::extensions::check_spec_version::CheckSpecVersion"
    case txVersion = "frame_system::extensions::check_tx_version::CheckTxVersion"
    case genesis = "frame_system::extensions::check_genesis::CheckGenesis"
    case mortality = "frame_system::extensions::check_mortality::CheckMortality"
    case nonce = "frame_system::extensions::check_nonce::CheckNonce"
    case weight = "frame_system::extensions::check_weight::CheckWeight"
    case txPayment = "pallet_transaction_payment::ChargeTransactionPayment"
    case attests = "polkadot_runtime_common::claims::PrevalidateAttests"
    case assetTxPayment =
        "pallet_asset_tx_payment::ChargeAssetTxPayment" // Statemine/Statemint case
    case checkMetadataHash = "frame_metadata_hash_extension::CheckMetadataHash"
    case appCheck = "da_control::extensions::check_app_id::CheckAppId"

    // Fee and signature payloads resolve extensions concurrently. This deterministic lookup
    // deliberately keeps no shared mutable cache.
    static func from(string: String, runtimeMetadata _: RuntimeMetadata) -> Self? {
        if let check = ExtrinsicCheck(rawValue: string) {
            return check
        }

        var typeName: String? = string
        if typeName?.contains("<") == true {
            typeName = typeName?.components(separatedBy: "<").first
        }

        typeName = typeName?.components(separatedBy: "::").last

        for check in Self.allCases {
            if let checkTypeName = check.rawValue.components(separatedBy: "::").last,
               checkTypeName == typeName
            {
                return check
            }
        }

        return nil
    }
}
