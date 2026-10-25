import XCTest
import TweetNacl
import BigInt
@testable import TonSwift

final class WalletContractV2Test: XCTestCase {
    
    private let publicKey = Data(hex: "5754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")!
    private let secretKey = Data(hex: "34aebb9ea454967f16c407c0f8877763e86212116468169d93a3dcbcafe530c95754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")!
    
    func testR1() throws {
        let contractR1 = try WalletV2(workchain: 0, publicKey: publicKey, revision: .r1)
        
        XCTAssertEqual(try contractR1.address(), try Address.parse("EQD3ES67JiTYq5y2eE1-fivl5kANn-gKDDjvpbxNCQWPzs4D"))
        XCTAssertEqual(try contractR1.stateInit.data?.toString(), "x{000000005754865E86D0ADE1199301BBB0319A25ED6B129C4B0A57F28F62449B3DF9C522}")
        XCTAssertEqual(try contractR1.stateInit.code?.toString(), "x{FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F2608308D71820D31FD31F01F823BBF263ED44D0D31FD3FFD15131BAF2A103F901541042F910F2A2F800029320D74A96D307D402FB00E8D1A4C8CB1FCBFFC9ED54}")
        
        let transfer = try contractR1.createTransfer(args: try args())
        let transferCell = try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: secretKey))
        XCTAssertEqual(try transferCell.toString(), """
                       x{6DC1459A6FF72EEE1384045986E70817819D4AF22F0F05CBF932927D1887C3CC68F624CD310132C32DE03941BF40AFC6917AA4579BB1CFDB2C4A390476D51C010000003E642574FF01}\n x{62007D507CF9B4D00622B6DC23E0BA7F3CA9584A13C5A3830F3DA8E9B76F27EFF641202FAF0800000000000000000000000000000000000048656C6C6F2C20776F726C6421}
                       """)
    }
    
    func testR2() throws {
        let contractR2 = try WalletV2(workchain: 0, publicKey: publicKey, revision: .r2)
        
        XCTAssertEqual(try contractR2.address(), try Address.parse("EQAkAcNLtzCHudScK9Hsk9I_7SrunBWf_9VrA2xJmGebwEsl"))
        XCTAssertEqual(try contractR2.stateInit.data?.toString(), "x{000000005754865E86D0ADE1199301BBB0319A25ED6B129C4B0A57F28F62449B3DF9C522}")
        XCTAssertEqual(try contractR2.stateInit.code?.toString(), "x{FF0020DD2082014C97BA218201339CBAB19C71B0ED44D0D31FD70BFFE304E0A4F2608308D71820D31FD31F01F823BBF263ED44D0D31FD3FFD15131BAF2A103F901541042F910F2A2F800029320D74A96D307D402FB00E8D1A4C8CB1FCBFFC9ED54}")
        
        let transfer = try contractR2.createTransfer(args: try args())
        let transferCell = try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: secretKey))
        XCTAssertEqual(try transferCell.toString(), """
                       x{6DC1459A6FF72EEE1384045986E70817819D4AF22F0F05CBF932927D1887C3CC68F624CD310132C32DE03941BF40AFC6917AA4579BB1CFDB2C4A390476D51C010000003E642574FF01}
                        x{62007D507CF9B4D00622B6DC23E0BA7F3CA9584A13C5A3830F3DA8E9B76F27EFF641202FAF0800000000000000000000000000000000000048656C6C6F2C20776F726C6421}
                       """)
    }
    
    private func args() throws -> WalletTransferData {
        return try WalletTransferData(
            seqno: 62,
            messages: [
                .internal(
                    to: Address.parse("kQD6oPnzaaAMRW24R8F0_nlSsJQni0cGHntR027eT9_sgtwt"),
                    value: BigUInt(0.1 * 1000000000),
                    textPayload: "Hello, world!"
                )
            ],
            sendMode: SendMode(payMsgFees: true),
            timeout: 1680176383
        )
    }
}
