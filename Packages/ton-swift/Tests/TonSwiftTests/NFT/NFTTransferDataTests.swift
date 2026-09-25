//
//  NFTTransferDataTests.swift
//  
//
//  Created by Grigory on 25.8.23..
//

import XCTest
import BigInt
@testable import TonSwift

final class NFTTransferDataTests: XCTestCase {

    private var nftTransferData: NFTTransferData {
        get throws {
            let queryId: UInt64 = 543
            let newOwnerAddress = Address.mock(
                workchain: 0,
                seed: "newOwnerAddressSeed"
            )
            let responseAddress = Address.mock(
                workchain: 0,
                seed: "responseAddressSeed"
            )
            let forwardAmount = BigUInt(stringLiteral: "05000000")
            let comment = "Hello, this is a comment"
            let commentCell = try Builder()
                .store(int: 0, bits: 32)
                .writeSnakeData(Data(comment.utf8)).endCell()
            
            return NFTTransferData(queryId: queryId,
                                   newOwnerAddress: newOwnerAddress,
                                   responseAddress: responseAddress,
                                   forwardAmount: forwardAmount,
                                   forwardPayload: commentCell)
        }
    }

    func testJettonTransferDataEncodeAndDecode() throws {
        let builder = Builder()
        let nftTransferDataCell = try builder.store(nftTransferData).endCell()
        let decodedNFTTransferData: NFTTransferData = try Slice(cell: nftTransferDataCell).loadType()

        XCTAssertEqual(try nftTransferData.queryId, decodedNFTTransferData.queryId)
        XCTAssertEqual(try nftTransferData.newOwnerAddress, decodedNFTTransferData.newOwnerAddress)
        XCTAssertEqual(try nftTransferData.responseAddress, decodedNFTTransferData.responseAddress)
        XCTAssertEqual(try nftTransferData.forwardAmount, decodedNFTTransferData.forwardAmount)
        XCTAssertEqual(try nftTransferData.forwardPayload, decodedNFTTransferData.forwardPayload)
    }
    
    func testJettonTransferDataEncode() throws {
        let builder = Builder()
        let nftTransferDataCell = try builder.store(try nftTransferData).endCell()

        XCTAssertEqual(try nftTransferDataCell.toString(),
                       """
                       x{5FCC3D14000000000000021F8006E2451A5FF8C5BEA1DC8505A789427312E714E1783A8DEBF2573D06BADDAD571001AAD4BD6DAA342C7D03C496083C01AEC31F1A457B8C993C62823E3713E11FD8186989681C_}
                        x{0000000048656C6C6F2C2074686973206973206120636F6D6D656E74}
                       """)
    }
}
