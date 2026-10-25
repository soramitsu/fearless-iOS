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

    /// Overiden types explain which network has what full names
    /// Key UInt32 - is metadata reserver number to identify network
    /// Value - is String:String dictionary, which has fixing mappings from original name to actual
    /// name
    private static var overridenTypes: [UInt32: [String: String]] = [:]

    static func from(string: String, runtimeMetadata: RuntimeMetadata) -> Self? {
        if let check = ExtrinsicCheck(rawValue: string) {
            return check
        }

        var overridenTypes = overridenTypes[runtimeMetadata.metaReserved] ?? [:]

        if let overridenType = overridenTypes[string] {
            return from(string: overridenType, runtimeMetadata: runtimeMetadata)
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
                overridenTypes[string] = check.rawValue
                self.overridenTypes[runtimeMetadata.metaReserved] = overridenTypes
                return from(string: check.rawValue, runtimeMetadata: runtimeMetadata)
            }
        }

        return nil
    }
}
