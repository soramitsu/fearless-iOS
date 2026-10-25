import Foundation

public enum KnownType: String, CaseIterable {
    // primitives that may vary by network, may have different index,
    // MAY BE NOT USED by new runtime metadata implementation
    case balance = "Balance"
    case index = "Index"
    
    // name varies by network, mapping provided by remote JSON
    case call = "GenericCall"
    
    // resolved for all versions of metadata
    case phase = "frame_system::Phase"
    case address = "sp_runtime::multiaddress::MultiAddress"
    case signature13 = "MultiSignature"
    case signature = "sp_runtime::MultiSignature"
    case extrinsic = "sp_runtime::generic::unchecked_extrinsic::UncheckedExtrinsic"
    case addressId32 = "sp_core::crypto::AccountId32" // regular networks
    case addressId20 = "account::AccountId20" // ethereum-based networks like Moonbeam/Moonriver
    case rawAddress = "AccountId"
    
    /// Sorted from Substrate based to Ethereum based
    static var addressIdTypes: [KnownType] {
        [.addressId32, .addressId20]
    }

    public var name: String { rawValue }
}
