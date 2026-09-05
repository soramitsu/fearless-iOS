//
//  JettonTransferData.swift
//  
//
//  Created by Grigory on 11.7.23..
//

import Foundation
import BigInt

public struct JettonTransferData: CellCodable {
    public let queryId: UInt64
    public let amount: BigUInt
    public let toAddress: Address
    public let responseAddress: Address
    public let forwardAmount: BigUInt
    public let comment: String?
    
    public func storeTo(builder: Builder) throws {
        try builder.store(uint: 0xf8a7ea5, bits: 32)
        try builder.store(uint: queryId, bits: 64)
        try builder.store(coins: Coins(amount.magnitude))
        try builder.store(AnyAddress(toAddress))
        try builder.store(AnyAddress(responseAddress))
        try builder.store(bit: false)
        try builder.store(coins: Coins(forwardAmount.magnitude))
        var commentCell: Cell?
        if let comment = comment {
            commentCell = try Builder().store(int: 0, bits: 32).writeSnakeData(Data(comment.utf8)).endCell()
        }
        try builder.store(bit: commentCell != nil)
        try builder.storeMaybe(ref: commentCell)
    }
    
    public static func loadFrom(slice: Slice) throws -> JettonTransferData {
        _ = try slice.loadUint(bits: 32)
        let queryId = try slice.loadUint(bits: 64)
        let amount = try slice.loadCoins().amount
        let toAddress: Address = try slice.loadType()
        let responseAddress: Address = try slice.loadType()
        try slice.skip(1)
        let forwardAmount = try slice.loadCoins().amount
        
        let hasComment = try slice.loadBoolean()
        var comment: String?
        if hasComment {
            let commentCell = try slice.loadRef()
            let slice = try commentCell.toSlice()
            try slice.skip(32)
            comment = try slice.loadSnakeString()
        }
        
        return JettonTransferData(queryId: queryId,
                                  amount: amount,
                                  toAddress: toAddress,
                                  responseAddress: responseAddress,
                                  forwardAmount: forwardAmount,
                                  comment: comment)
    }
}
