//
//  NFTTransferMessage.swift
//  
//
//  Created by Grigory on 25.8.23..
//

import Foundation
import BigInt

public struct NFTTransferMessage {
    public static func internalMessage(nftAddress: Address,
                                       nftTransferAmount: BigUInt,
                                       bounce: Bool,
                                       to: Address,
                                       from: Address,
                                       forwardPayload: Cell?) throws -> MessageRelaxed {
        let forwardAmount = BigUInt(stringLiteral: "1")
        let queryId = UInt64(Date().timeIntervalSince1970)
        
        let nftTransferData = NFTTransferData(
            queryId: queryId,
            newOwnerAddress: to,
            responseAddress: from,
            forwardAmount: forwardAmount,
            forwardPayload: forwardPayload)
        
        return MessageRelaxed.internal(
            to: nftAddress,
            value: nftTransferAmount,
            bounce: bounce,
            body: try Builder().store(nftTransferData).endCell())
    }
}
