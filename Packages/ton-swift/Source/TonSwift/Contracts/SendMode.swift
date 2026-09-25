import Foundation

/// Various raw options for sending a message that affect error handling,
/// paying fees and sending the value.
/// This struct is a wrapper around sendmode flags that prevents accidental misuse.
public struct SendMode {
    /// Pays message fwd/ihr fees separately.
    /// If the flag is not set, those fees are subtracted from the message value.
    public let payMsgFees: Bool

    /// Ignores the errors in the action phase (due to invalid address, insufficient funds etc.)
    /// That is, if this message cannot be sent, this does not fail the rest of the transaction.
    public let ignoreErrors: Bool

    /// Options for sending the value.
    public let value: SendValueOptions

    init(payMsgFees: Bool = false, ignoreErrors: Bool = false, value: SendValueOptions = .messageValue) {
        self.payMsgFees = payMsgFees
        self.ignoreErrors = ignoreErrors
        self.value = value
    }

    /// Standard flags for the wallet is to pay msg fees on behalf of the sender
    /// and ignore errors so that sequence number can be bumped securely,
    /// so that bad transactions cannot be replayed indefinitely.
    public static func walletDefault() -> Self {
        return SendMode(payMsgFees: true, ignoreErrors: true)
    }
}

extension SendMode: RawRepresentable {
    public init?(rawValue: UInt8) {
        if rawValue & SendModeInvalidFlags > 0 {
            return nil // these bits are not used and must be set to zero
        }
        if let v = SendValueOptions(rawValue: rawValue) {
            self.value = v
        } else {
            return nil
        }
        self.payMsgFees = (rawValue & SendModePayMsgFees > 0)
        self.ignoreErrors = (rawValue & SendModeIgnoreErrors > 0)
    }

    public var rawValue: UInt8 {
        var m: UInt8 = value.rawValue
        if payMsgFees { m |= SendModePayMsgFees }
        if ignoreErrors { m |= SendModeIgnoreErrors }
        return m
    }
}

public enum SendValueOptions {
    /// Default choice: send the value specified for the message (minus the possible fees).
    case messageValue

    /// In addition to the specified value, message gets the remaining value from the incoming value.
    case addInboundValue

    /// Spend the entire balance (minus the fees).
    case sendRemainingBalance

    /// Spend the entire balance (minus the fees) and destroy the contract.
    case sendRemainingBalanceAndDestroy
}

extension SendValueOptions: RawRepresentable {
    public typealias RawValue = UInt8

    public init?(rawValue: UInt8) {
        if rawValue & SendModeConflictingFlags == SendModeConflictingFlags {
            return nil // cannot set conflicting bits
        }
        if rawValue & SendModeSpendRemainingBalance > 0 {
            if rawValue & SendModeDestroyWhenEmpty > 0 {
                self = .sendRemainingBalanceAndDestroy
            } else {
                self = .sendRemainingBalance
            }
        } else if rawValue & SendModeAddRemainingInboundValue > 0 {
            self = .addInboundValue
        } else {
            self = .messageValue
        }
    }

    public var rawValue: UInt8 {
        switch self {
        case .messageValue: return 0
        case .addInboundValue: return SendModeAddRemainingInboundValue
        case .sendRemainingBalance: return SendModeSpendRemainingBalance
        case .sendRemainingBalanceAndDestroy: return SendModeSpendRemainingBalance | SendModeDestroyWhenEmpty
        }
    }
}

/// Pays message fwd/ihr fees separately.
/// If the flag is not set, those fees are subtracted from the message value.
/// IMPORTANT: do not use this flag directly, use `SendMode` type instead.
let SendModePayMsgFees: UInt8 = 1

/// Ignores the errors in the action phase (due to invalid address, insufficient funds etc.)
/// That is, if this message cannot be sent, this does not fail the rest of the transaction.
/// IMPORTANT: do not use this flag directly, use `SendMode` type instead.
let SendModeIgnoreErrors: UInt8 = 2

/// Account is destroyed when remaining balance is zero.
/// This flag comes into effect only when used together with `spendRemainingBalance`.
/// IMPORTANT: do not use this flag directly, use `SendMode` type instead.
let SendModeDestroyWhenEmpty: UInt8 = 32

/// In addition to the specified value, message gets the remaining value from the incoming value.
/// This flag cannot be used together with `spendRemainingBalance`.
/// IMPORTANT: do not use this flag directly, use `SendMode` type instead.
let SendModeAddRemainingInboundValue: UInt8 = 64

/// Message sends the entire remaining balance of the contract,
/// forwarding fees are subtracted from that amount.
/// This flag cannot be used together with `addRemainingInboundValue`.
/// IMPORTANT: do not use this flag directly, use `SendMode` type instead.
let SendModeSpendRemainingBalance: UInt8 = 128

private let SendModeInvalidFlags: UInt8 = 4+8+16

private let SendModeConflictingFlags: UInt8 = 128+64
