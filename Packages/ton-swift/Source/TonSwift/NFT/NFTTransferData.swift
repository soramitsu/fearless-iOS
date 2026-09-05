//
//  NFTTransferData.swift
//  
//
//  Created by Grigory on 25.8.23..
//

import Foundation
import BigInt

public struct NFTTransferData: CellCodable {
    public let queryId: UInt64
    public let newOwnerAddress: Address
    public let responseAddress: Address
    public let forwardAmount: BigUInt
    public let forwardPayload: Cell?
    
    public func storeTo(builder: Builder) throws {
        try builder.store(uint: 0x5fcc3d14, bits: 32) // transfer op
        try builder.store(uint: queryId, bits: 64)
        try builder.store(AnyAddress(newOwnerAddress))
        try builder.store(AnyAddress(responseAddress))
        try builder.store(bit: false) // null custom_payload
        try builder.store(coins: Coins(forwardAmount.magnitude))
        try builder.store(bit: forwardPayload != nil) // forward_payload in this slice - false, separate cell - true
        try builder.storeMaybe(ref: forwardPayload)
    }
    
    public static func loadFrom(slice: Slice) throws -> NFTTransferData {
        try slice.skip(32)
        let queryId = try slice.loadUint(bits: 64)
        let newOwnerAddress: Address = try slice.loadType()
        let responseAddress: Address = try slice.loadType()
        try slice.skip(1)
        let forwardAmount = try slice.loadCoins().amount
        let hasPayloadCell = try slice.loadBoolean()
        var forwardPayload: Cell?
        if hasPayloadCell, let payloadCell = try slice.loadMaybeRef() {
            forwardPayload = payloadCell
        }
        return NFTTransferData(
            queryId: queryId,
            newOwnerAddress: newOwnerAddress,
            responseAddress: responseAddress,
            forwardAmount: forwardAmount,
            forwardPayload: forwardPayload)
    }
}
