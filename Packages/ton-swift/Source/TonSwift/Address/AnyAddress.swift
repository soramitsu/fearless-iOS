import Foundation

/// Represents `MsgAddress` structure per TL-B definition:
/// Note that in TON optional address is represented by MsgAddressExt and not as you'd expect `(Maybe Address)`.
/// ```
/// addr_none$00 = MsgAddressExt;
/// addr_extern$01 len:(## 9) external_address:(bits len)
///              = MsgAddressExt;
/// anycast_info$_ depth:(#<= 30) { depth >= 1 }
///    rewrite_pfx:(bits depth) = Anycast;
/// addr_std$10 anycast:(Maybe Anycast)
///    workchain_id:int8 address:bits256  = MsgAddressInt;
/// addr_var$11 anycast:(Maybe Anycast) addr_len:(## 9)
///    workchain_id:int32 address:(bits addr_len) = MsgAddressInt;
/// _ _:MsgAddressInt = MsgAddress;
/// _ _:MsgAddressExt = MsgAddress;
/// ```
///
public enum AnyAddress {
    case none
    case internalAddr(Address)
    case externalAddr(ExternalAddress)
    
    init(_ addr: Address) {
        self = .internalAddr(addr)
    }
    init(_ maybeAddr: Address?) {
        if let addr = maybeAddr {
            self = .internalAddr(addr)
        } else {
            self = .none
        }
    }
    
    init(_ addr: ExternalAddress) {
        self = .externalAddr(addr)
    }
    
    init(_ maybeAddr: ExternalAddress?) {
        if let addr = maybeAddr {
            self = .externalAddr(addr)
        } else {
            self = .none
        }
    }
    
    /// Converts to an optional internal address. Throws error if it is an external address.
    public func asInternal() throws -> Address? {
        switch self {
        case .none: return nil;
        case .internalAddr(let addr): return addr;
        case .externalAddr(_): throw TonError.custom("Expected internal address")
        }
    }
    
    /// Converts to an external address. Throws error if it is an internal address.
    public func asExternal() throws -> ExternalAddress? {
        switch self {
        case .none: return nil;
        case .internalAddr(_): throw TonError.custom("Expected external address")
        case .externalAddr(let addr): return addr;
        }
    }
}

extension AnyAddress: CellCodable {
    public func storeTo(builder: Builder) throws {
        switch self {
        case .none:
            try builder.store(uint: UInt64(0), bits: 2)
            break
        case .internalAddr(let addr):
            try addr.storeTo(builder: builder)
            break
        case .externalAddr(let addr):
            try addr.storeTo(builder: builder)
            break
        }
    }
    
    public static func loadFrom(slice: Slice) throws -> AnyAddress {
        let type = try slice.preloadUint(bits: 2)
        switch type {
        case 0:
            try slice.skip(2);
            return .none;
        case 1:
            return .externalAddr(try slice.loadType());
        case 2,3:
            return .internalAddr(try slice.loadType());
        default:
            throw TonError.custom("Unreachable error");
        }
    }
}
