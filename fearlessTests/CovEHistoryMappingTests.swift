@testable import fearless
import BigInt
import SSFModels
import SSFUtils
import XCTest

/// Mapping of remote history records (SubQuery, Subsquid, Giantsquid, Arrowsquid, SORA Subsquid and the EVM
/// explorers) into `AssetTransactionData`: direction, status, peer, amount scaling, fees and timestamps.
final class CovEHistoryMappingTests: XCTestCase {
    private let alice = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
    private let bob = "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
    private lazy var chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 42, assetPresicion: 10)
    private let asset = ChainModelGenerator.generateAssetWithId("covE-asset", symbol: "CVE", assetPresicion: 10)

    func testSubqueryTransfersRewardsExtrinsicsAndUnknownRecords() throws {
        let outgoing: SubqueryHistoryElement = try decode("""
        {"id":"t1","timestamp":"1700000000","address":"\(alice)",
         "transfer":{"amount":"15000000000","to":"\(bob)","from":"\(alice)","fee":"1250000000","success":true}}
        """)
        XCTAssertEqual(outgoing.label, .transfers)
        let sent = outgoing.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(sent.transactionId, "t1")
        XCTAssertEqual(sent.status, .commited)
        XCTAssertEqual(sent.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(sent.peerName, bob)
        XCTAssertEqual(sent.peerId, try AddressFactory.accountId(from: bob, chain: chain).toHex())
        XCTAssertEqual(sent.amount.decimalValue, Decimal(string: "1.5"))
        XCTAssertEqual(sent.fees.map(\.amount.decimalValue), try [XCTUnwrap(Decimal(string: "0.125"))])
        XCTAssertEqual(sent.timestamp, 1_700_000_000)

        let incoming: SubqueryHistoryElement = try decode("""
        {"id":"t2","timestamp":"bad","address":"\(alice)",
         "transfer":{"amount":"oops","to":"\(alice)","from":"not-an-address","success":false}}
        """)
        let received = AssetTransactionData.createTransaction(from: incoming, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(received.status, .rejected)
        XCTAssertEqual(received.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(received.peerId, "not-an-address", "Unparseable peers keep the raw address")
        XCTAssertEqual(received.amount.decimalValue, 0)
        XCTAssertTrue(received.fees.isEmpty)
        XCTAssertEqual(received.timestamp, 0)

        let reward: SubqueryHistoryElement = try decode("""
        {"id":"r1","timestamp":"1700000100","address":"\(alice)",
         "reward":{"amount":"20000000000","isReward":true,"era":12,"validator":"\(bob)","eventIdx":4}}
        """)
        XCTAssertEqual(reward.label, .rewards)
        XCTAssertEqual(reward.rewardInfo?.eventIdx, "4")
        let rewarded = AssetTransactionData.createTransaction(from: reward, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(rewarded.type, TransactionType.reward.rawValue)
        XCTAssertEqual(rewarded.details, "#12")
        XCTAssertEqual(rewarded.peerFirstName, bob)
        XCTAssertEqual(rewarded.amount.decimalValue, 2)
        XCTAssertEqual(rewarded.reason, "r1")

        let slash: SubqueryHistoryElement = try decode("""
        {"id":"s1","timestamp":"1","address":"\(alice)","reward":{"amount":"10000000000","isReward":false}}
        """)
        let slashed = AssetTransactionData.createTransaction(from: slash, address: "bad-address", chain: chain, asset: asset)
        XCTAssertEqual(slashed.type, TransactionType.slash.rawValue)
        XCTAssertEqual(slashed.details, "#0")
        XCTAssertEqual(slashed.peerId, "bad-address")

        let extrinsic: SubqueryHistoryElement = try decode("""
        {"id":"e1","timestamp":"5","address":"\(alice)",
         "extrinsic":{"hash":"0xabc","module":"staking","call":"bond","fee":"5000000000","success":false}}
        """)
        XCTAssertEqual(extrinsic.label, .extrinsics)
        let call = AssetTransactionData.createTransaction(from: extrinsic, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(call.status, .rejected)
        XCTAssertEqual(call.peerName, "staking bond")
        XCTAssertEqual(call.peerFirstName, "staking")
        XCTAssertEqual(call.peerLastName, "bond")
        XCTAssertEqual(call.reason, "0xabc")
        XCTAssertEqual(call.amount.decimalValue, Decimal(string: "0.5"))
        XCTAssertEqual(call.type, TransactionType.extrinsic.rawValue)

        let unknown: SubqueryHistoryElement = try decode("""
        {"id":"u1","timestamp":"9","address":"\(alice)"}
        """)
        let pending = AssetTransactionData.createTransaction(from: unknown, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(pending.status, .pending)
        XCTAssertEqual(pending.type, "UNKNOWN")
        XCTAssertEqual(pending.timestamp, 9)
    }

    func testLocalHistoryItemsMapTransfersWithEncodedCallsAndExtrinsics() throws {
        let call = RuntimeCall(
            moduleName: "Balances",
            callName: "transfer",
            args: TransferCall(dest: .accoundId(Data(repeating: 7, count: 32)), value: BigUInt(30_000_000_000), currencyId: nil)
        )
        let encoded = try JSONEncoder().encode(call)
        let transfer = TransactionHistoryItem(
            sender: alice, receiver: bob, status: .success, txHash: "0xlocal", timestamp: 77, fee: "2500000000",
            blockNumber: 1, txIndex: 0, callPath: .transfer, call: encoded
        )
        let sent = AssetTransactionData.createTransaction(from: transfer, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(sent.transactionId, "0xlocal")
        XCTAssertEqual(sent.status, .commited)
        XCTAssertEqual(sent.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(sent.peerName, bob)
        XCTAssertEqual(sent.fees.first?.amount.decimalValue, Decimal(string: "0.25"))
        XCTAssertEqual(sent.timestamp, 77)

        let received = TransactionHistoryItem(
            sender: bob, receiver: nil, status: .failed, txHash: "0xin", timestamp: 1, fee: "x",
            blockNumber: nil, txIndex: nil, callPath: .transferKeepAlive, call: Data("junk".utf8)
        )
        let incoming = AssetTransactionData.createTransaction(from: received, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(incoming.status, .rejected)
        XCTAssertEqual(incoming.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(incoming.peerName, bob)
        XCTAssertEqual(incoming.amount.decimalValue, 0, "An undecodable call has no amount")

        let bond = TransactionHistoryItem(
            sender: alice, receiver: nil, status: .pending, txHash: "0xpool", timestamp: 3, fee: "10000000000",
            blockNumber: nil, txIndex: nil, callPath: .poolBondMore, call: nil
        )
        let extrinsic = AssetTransactionData.createTransaction(from: bond, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(extrinsic.status, .pending)
        XCTAssertEqual(extrinsic.type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(extrinsic.peerFirstName, CallCodingPath.poolBondMore.moduleName)
        XCTAssertEqual(extrinsic.peerLastName, CallCodingPath.poolBondMore.callName)
        XCTAssertEqual(extrinsic.amount.decimalValue, 1)
        XCTAssertEqual(extrinsic.peerId, try AddressFactory.accountId(from: alice, chain: chain).toHex())
        XCTAssertEqual(TransactionHistoryItem.Status.success.walletValue, .commited)
    }

    func testSubsquidRecordsUseMillisecondTimestampsAndExtrinsicHashes() throws {
        let transfer: SubsquidHistoryElement = try decode("""
        {"id":"s-t","timestamp":"1700000000000","address":"\(alice)","extrinsicHash":"0xhash",
         "transfer":{"amount":"10000000000","to":"\(alice)","from":"\(bob)","fee":"10000000","success":true}}
        """)
        XCTAssertEqual(transfer.itemTimestamp, 1_700_000_000)
        XCTAssertEqual(transfer.label, .transfers)
        let incoming = transfer.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(incoming.transactionId, "0xhash")
        XCTAssertEqual(incoming.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(incoming.peerName, bob)
        XCTAssertEqual(incoming.amount.decimalValue, 1)
        XCTAssertEqual(incoming.timestamp, 1_700_000_000)
        XCTAssertEqual(incoming.fees.count, 1)

        let failed: SubsquidHistoryElement = try decode("""
        {"id":"s-f","timestamp":"2000","address":"\(alice)",
         "transfer":{"amount":"1","to":"\(bob)","from":"\(alice)","success":false}}
        """)
        let outgoing = AssetTransactionData.createTransaction(from: failed, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(outgoing.transactionId, "s-f")
        XCTAssertEqual(outgoing.status, .rejected)
        XCTAssertEqual(outgoing.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(outgoing.fees.first?.amount.decimalValue, 0)

        let reward: SubsquidHistoryElement = try decode("""
        {"id":"s-r","timestamp":"3000","address":"\(alice)","reward":{"amount":"5000000000","isReward":false,"era":3}}
        """)
        XCTAssertEqual(reward.label, .rewards)
        XCTAssertNotNil(reward.rewardInfo)
        let slash = AssetTransactionData.createTransaction(from: reward, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(slash.type, TransactionType.slash.rawValue)
        XCTAssertEqual(slash.details, "#3")
        XCTAssertEqual(slash.timestamp, 3)

        let extrinsic: SubsquidHistoryElement = try decode("""
        {"id":"s-e","timestamp":"4000","address":"\(alice)",
         "extrinsic":{"hash":"0xe","module":"balances","call":"transfer_all","fee":"20000000000","success":true}}
        """)
        XCTAssertEqual(extrinsic.label, .extrinsics)
        let call = AssetTransactionData.createTransaction(from: extrinsic, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(call.type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(call.status, .commited)
        XCTAssertEqual(call.peerName, "balances transfer_all")

        let unknown: SubsquidHistoryElement = try decode("""
        {"id":"s-u","timestamp":"5000","address":"\(alice)"}
        """)
        XCTAssertEqual(AssetTransactionData.createTransaction(from: unknown, address: alice, chain: chain, asset: asset).status, .pending)
    }

    func testGiantsquidTransfersRewardsBondsAndSlashes() throws {
        let date = "2023-11-14T22:13:20.000000Z"
        let transfer: GiantsquidTransfer = try decode("""
        {"id":"g-t","amount":"25000000000","to":{"id":"\(bob)"},"from":{"id":"\(alice)"},"success":true,"timestamp":"\(date)"}
        """)
        XCTAssertEqual(transfer.identifier, "g-t")
        XCTAssertEqual(transfer.label, .transfers)
        let sent = transfer.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(sent.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(sent.status, .commited)
        XCTAssertEqual(sent.peerName, bob)
        XCTAssertEqual(sent.amount.decimalValue, Decimal(string: "2.5"))
        XCTAssertEqual(sent.timestamp, 1_700_000_000)
        XCTAssertEqual(transfer.timestampInSeconds, 1_700_000_000)

        let anonymous: GiantsquidTransfer = try decode("""
        {"amount":"1","extrinsicHash":"0xg","to":{"id":"\(alice)"},"from":{"id":"\(bob)"},"timestamp":"not a date"}
        """)
        XCTAssertEqual(anonymous.identifier, "0xg")
        let received = AssetTransactionData.createTransaction(transfer: anonymous, address: alice, asset: asset)
        XCTAssertEqual(received.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(received.status, .rejected)
        XCTAssertEqual(received.timestamp, 0)

        let reward: GiantsquidReward = try decode("""
        {"amount":"30000000000","era":8,"accountId":"\(alice)","validator":"\(bob)","timestamp":1700000000}
        """)
        XCTAssertEqual(reward.timestamp, "1700000000", "Numeric timestamps decode as strings")
        XCTAssertEqual(reward.identifier, "17000000003" + "0000000000")
        XCTAssertEqual(reward.address, alice)
        XCTAssertTrue(reward.isReward)
        XCTAssertEqual(reward.stash, alice)
        XCTAssertNil(reward.assetId)
        let rewarded = reward.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(rewarded.type, TransactionType.reward.rawValue)
        XCTAssertEqual(rewarded.details, "#8")
        XCTAssertEqual(rewarded.peerFirstName, bob)
        XCTAssertEqual(rewarded.amount.decimalValue, 3)

        let bond: GiantsquidBond = try decode("""
        {"id":"g-b","accountId":"\(alice)","amount":"40000000000","blockNumber":99,"timestamp":"\(date)","success":true}
        """)
        let bonded = bond.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(bonded.transactionId, "g-b")
        XCTAssertEqual(bonded.details, "#99")
        XCTAssertEqual(bonded.type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(bonded.amount.decimalValue, 4)
        XCTAssertEqual(bonded.timestamp, 1_700_000_000)

        let slash: GiantsquidSlash = try decode("""
        {"id":"g-s","accountId":"\(alice)","amount":"5000000000","blockNumber":7,"era":2,"timestamp":"\(date)"}
        """)
        let slashed = slash.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(slashed.transactionId, "g-s")
        XCTAssertEqual(slashed.amount.decimalValue, Decimal(string: "0.5"))
        XCTAssertEqual(slashed.timestamp, 1_700_000_000)
    }
}

extension CovEHistoryMappingTests {
    func testArrowsquidTransfersRewardsAndUnknownRecords() throws {
        let transfer: ArrowsquidHistoryElement = try decode("""
        {"id":"a-t","timestamp":1700000000,"address":"\(alice)","success":true,
         "transfer":{"amount":"10000000000","to":"\(bob)","from":"\(alice)","fee":"20000000"}}
        """)
        XCTAssertEqual(transfer.itemTimestamp, 1_700_000_000)
        XCTAssertFalse(transfer.timestamp.isEmpty)
        XCTAssertEqual(transfer.label, .transfers)
        let sent = transfer.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(sent.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(sent.peerName, bob)
        XCTAssertEqual(sent.status, .commited)
        XCTAssertEqual(sent.amount.decimalValue, 1)

        let failed: ArrowsquidHistoryElement = try decode("""
        {"id":"a-f","timestamp":1,"address":"\(alice)","success":false,
         "transfer":{"amount":"1","to":"\(alice)","from":"\(bob)"}}
        """)
        let received = AssetTransactionData.createTransaction(from: failed, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(received.status, .rejected)
        XCTAssertEqual(received.type, TransactionType.incoming.rawValue)

        let reward: ArrowsquidHistoryElement = try decode("""
        {"id":"a-r","timestamp":2,"address":"\(alice)","success":true,"reward":{"amount":"20000000000","stash":"\(alice)","era":4}}
        """)
        XCTAssertEqual(reward.label, .rewards)
        XCTAssertEqual(reward.rewardInfo?.isReward, true)
        let rewarded = AssetTransactionData.createTransaction(from: reward, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(rewarded.type, TransactionType.reward.rawValue)
        XCTAssertEqual(rewarded.amount.decimalValue, 2)

        let unknown: ArrowsquidHistoryElement = try decode("""
        {"id":"a-u","timestamp":3,"address":"\(alice)","success":true}
        """)
        let pending = AssetTransactionData.createTransaction(from: unknown, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(pending.status, .pending)
        XCTAssertEqual(pending.timestamp, 3)
    }

    func testSoraSubsquidModulesMapToTransferRewardSwapBridgeAndExtrinsic() throws {
        func element(_ module: String, _ method: String, data: String, success: Bool = true) throws -> SoraSubsquidHistoryElement {
            try decode("""
            {"id":"\(module)-\(method)","address":"\(alice)","module":"\(module)","method":"\(method)",
             "networkFee":"7000000000","timestamp":1700000000,"execution":{"success":\(success)},"data":\(data)}
            """)
        }
        let transfer = try element("assets", "transfer", data: """
        {"from":"\(alice)","to":"\(bob)","assetId":"0x02","amount":"1.25"}
        """)
        XCTAssertEqual(transfer.identifier, "assets-transfer")
        XCTAssertEqual(transfer.itemTimestamp, 1_700_000_000)
        XCTAssertEqual(transfer.label, .extrinsics)
        let sent = transfer.createTransactionForAddress(alice, chain: chain, asset: asset)
        XCTAssertEqual(sent.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(sent.peerName, bob)
        XCTAssertEqual(sent.assetId, "0x02")
        XCTAssertEqual(sent.amount.decimalValue, Decimal(string: "1.25"))
        XCTAssertEqual(sent.fees.first?.amount.decimalValue, Decimal(string: "0.7"))
        XCTAssertEqual(sent.status, .commited)

        let incoming = try element("assets", "transfer", data: """
        {"from":"\(bob)","to":"\(alice)","assetId":"0x02","amount":"2"}
        """, success: false)
        let received = AssetTransactionData.createTransaction(from: incoming, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(received.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(received.peerName, bob)
        XCTAssertEqual(received.status, .rejected)

        let reward = try element("staking", "rewarded", data: """
        {"stash":"\(alice)","amount":"3","era":11}
        """)
        let rewarded = AssetTransactionData.createTransaction(from: reward, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(rewarded.type, TransactionType.reward.rawValue)
        XCTAssertEqual(rewarded.details, "11")
        XCTAssertEqual(rewarded.peerName, alice)

        let swap = try element("liquidityProxy", "swap", data: """
        {"baseAssetId":"0x01","targetAssetId":"0x03","baseAssetAmount":"4","targetAssetAmount":"5"}
        """, success: false)
        let swapped = AssetTransactionData.createTransaction(from: swap, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(swapped.type, TransactionType.swap.rawValue)
        XCTAssertEqual(swapped.status, .rejected, "A failed swap is shown as failed (4c06d1d52)")
        XCTAssertEqual(swapped.assetId, "0x03")
        XCTAssertEqual(swapped.peerId, "0x01")
        XCTAssertEqual(swapped.details, "4")
        XCTAssertEqual(swapped.amount.decimalValue, 5)

        let bridge = try element("bridgeProxy", "transferToSidechain", data: """
        {"assetId":"0x04","amount":"6","sidechainAddress":"0xeth","requestHash":"0xreq"}
        """)
        let bridged = AssetTransactionData.createTransaction(from: bridge, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(bridged.type, TransactionType.bridge.rawValue)
        XCTAssertEqual(bridged.transactionId, "bridgeProxy-transferToSidechain")
        XCTAssertEqual(bridged.status, .commited)
        let failedBridge = try element("bridgeProxy", "transferToSidechain", data: """
        {"assetId":"0x04","amount":"6","sidechainAddress":"0xeth","requestHash":"0xreq"}
        """, success: false)
        let failedBridged = AssetTransactionData.createTransaction(from: failedBridge, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(failedBridged.status, .rejected, "A failed bridge transfer is shown as failed (4c06d1d52)")

        let other = try element("utility", "batch", data: "{}")
        let extrinsic = AssetTransactionData.createTransaction(from: other, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(extrinsic.type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(extrinsic.transactionId, "utility-batch")
        XCTAssertEqual(extrinsic.status, .commited)
        let failedOther = try element("utility", "batch", data: "{}", success: false)
        let failedExtrinsic = AssetTransactionData.createTransaction(from: failedOther, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(failedExtrinsic.status, .rejected, "A failed extrinsic is shown as failed (4c06d1d52)")

        let bare: SoraSubsquidHistoryElement = try decode("""
        {"id":"bare"}
        """)
        XCTAssertEqual(bare.itemTimestamp, 0)
        let mapped = AssetTransactionData.createTransaction(from: bare, address: alice, chain: chain, asset: asset)
        XCTAssertEqual(mapped.type, TransactionType.extrinsic.rawValue)
        XCTAssertEqual(mapped.fees.first?.amount.decimalValue, 0)
    }

    func testEvmExplorerRecordsMapDirectionFeesAndTimestamps() throws {
        let evm = "0x1111111111111111111111111111111111111111"
        let peer = "0x2222222222222222222222222222222222222222"

        let blockscout: BlockscoutItem = try decode("""
        {"timestamp":"2023-11-14T22:13:20.000000Z","from":{"hash":"\(evm.uppercased())"},"to":{"hash":"\(peer)"},
         "fee":{"type":"actual","value":"100000000"},"value":"30000000000","hash":"0xzeta"}
        """)
        let zeta = AssetTransactionData.createTransaction(from: blockscout, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(zeta.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(zeta.peerName, peer)
        XCTAssertEqual(zeta.amount.decimalValue, 3)
        XCTAssertEqual(zeta.transactionId, "0xzeta")
        XCTAssertEqual(zeta.timestamp, 1_700_000_000)
        let token: BlockscoutItem = try decode("""
        {"timestamp":"x","from":{"hash":"\(peer)"},"to":{"hash":"\(evm)"},"total":{"decimals":"10","value":"10000000000"},"txHash":"0xtok"}
        """)
        let zetaIn = AssetTransactionData.createTransaction(from: token, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(zetaIn.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(zetaIn.amount.decimalValue, 1)
        XCTAssertEqual(zetaIn.transactionId, "0xtok")
        XCTAssertEqual(zetaIn.fees.first?.amount.decimalValue, 0)

        let zchain: ZChainHistoryElement = try decode("""
        {"ti":1700000000,"h":"0xz","f":{"a":"\(evm)"},"t":{"a":"\(peer)"},"v":"20000000000","tf":"10000000000"}
        """)
        let mappedZ = AssetTransactionData.createTransaction(from: zchain, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedZ.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(mappedZ.timestamp, 1_700_000_000)
        XCTAssertEqual(mappedZ.amount.decimalValue, 2)
        XCTAssertEqual(zchain.timestampInSeconds, 1_700_000_000)
        let zchainIn: ZChainHistoryElement = try decode("""
        {"f":{"a":"\(peer)"},"v":"0","tf":"0"}
        """)
        let mappedZIn = AssetTransactionData.createTransaction(from: zchainIn, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedZIn.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(mappedZIn.timestamp, 0)
        XCTAssertEqual(mappedZIn.transactionId, "")

        let vicscan: ViscanHistoryElement = try decode("""
        {"timestamp":1700000000,"hash":"0xv","from":"\(peer)","to":"\(evm)","contractAddress":"0xc","value":"10000000000","fee":0.01}
        """)
        let mappedV = AssetTransactionData.createTransaction(from: vicscan, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedV.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(mappedV.peerName, peer)
        XCTAssertEqual(mappedV.assetId, "0xc")
        XCTAssertEqual(mappedV.fees.first?.amount.decimalValue, Decimal(string: "0.01"))
        let vicscanOut: ViscanHistoryElement = try decode("""
        {"from":"\(evm)","to":"\(peer)","value":"0","fee":0}
        """)
        let mappedVOut = AssetTransactionData.createTransaction(from: vicscanOut, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedVOut.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(mappedVOut.timestamp, 0)
        XCTAssertEqual(vicscanOut.timestampInSeconds, 0)

        let fire: FireHistoryTransaction = try decode("""
        {"createdAt":"2023-11-14T22:13:20.000Z","hash":"0xf","fromAddress":"\(evm)","toAddress":"\(peer)",
         "value":"50000000000","gas":"2","gasPrice":"500000000"}
        """)
        let mappedF = AssetTransactionData.createTransaction(from: fire, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedF.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(mappedF.amount.decimalValue, 5)
        XCTAssertEqual(mappedF.fees.first?.amount.decimalValue, Decimal(string: "0.1"))
        XCTAssertEqual(mappedF.timestamp, 1_700_000_000)
        let fireIn: FireHistoryTransaction = try decode("""
        {"fromAddress":"\(peer)","toAddress":"\(evm)","value":"0","gas":"0","gasPrice":"0"}
        """)
        let mappedFIn = AssetTransactionData.createTransaction(from: fireIn, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedFIn.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(mappedFIn.timestamp, 0)
    }

    func testAlchemyOklinkAndKaiaRecords() throws {
        let evm = "0x1111111111111111111111111111111111111111"
        let peer = "0x2222222222222222222222222222222222222222"

        let alchemy: AlchemyHistoryElement = try decode("""
        {"blockNum":"0x1","uniqueId":"u","hash":"0xa","from":"\(evm.uppercased())","to":"\(peer)","value":1.5,"asset":"ETH",
         "category":"external","metadata":{"blockTimestamp":"2023-11-14T22:13:20.000Z"}}
        """)
        let mappedA = try XCTUnwrap(AssetTransactionData.createTransaction(from: alchemy, address: evm))
        XCTAssertEqual(mappedA.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(mappedA.assetId, "ETH")
        XCTAssertEqual(mappedA.amount.decimalValue, Decimal(string: "1.5"))
        XCTAssertEqual(mappedA.timestamp, 1_700_000_000)
        let alchemyIn: AlchemyHistoryElement = try decode("""
        {"blockNum":"0x1","uniqueId":"u","hash":"0xb","from":"\(peer)","value":2,"asset":"ETH","category":"external"}
        """)
        let mappedAIn = try XCTUnwrap(AssetTransactionData.createTransaction(from: alchemyIn, address: evm))
        XCTAssertEqual(mappedAIn.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(mappedAIn.timestamp, 0)
        let noValue: AlchemyHistoryElement = try decode("""
        {"blockNum":"0x1","uniqueId":"u","hash":"0xc","from":"\(peer)","category":"erc721"}
        """)
        XCTAssertNil(AssetTransactionData.createTransaction(from: noValue, address: evm), "Records without value or asset are dropped")

        let oklink: OklinkTransactionItem = try decode("""
        {"txId":"0xo","methodId":"","blockHash":"0x","height":"1","transactionTime":"1700000000000","from":"\(evm)","to":"\(peer)",
         "isFromContract":false,"isToContract":false,"amount":"0.75","transactionSymbol":"OKB","txFee":"0.001","state":"success",
         "tokenId":"","tokenContractAddress":"0xtoken","challengeStatus":"","l1OriginHash":""}
        """)
        let mappedO = AssetTransactionData.createTransaction(from: oklink, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedO.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(mappedO.timestamp, 1_700_000_000)
        XCTAssertEqual(mappedO.assetId, "0xtoken")
        XCTAssertEqual(mappedO.amount.decimalValue, Decimal(string: "0.75"))
        XCTAssertEqual(mappedO.fees.first?.amount.decimalValue, Decimal(string: "0.001"))
        let mappedOIn = AssetTransactionData.createTransaction(from: oklink, address: peer, chain: chain, asset: asset)
        XCTAssertEqual(mappedOIn.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(mappedOIn.peerName, evm)

        let kaia: KaiaHistoryTransaction = try decode("""
        {"transactionHash":"0xk","datetime":"2023-11-14T22:13:20.000Z","from":"\(evm.uppercased())","to":"\(peer)",
         "amount":1.25,"transactionFee":0.002,"status":{"status":"Fail"}}
        """)
        let mappedK = try AssetTransactionData.createTransaction(from: kaia, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedK.type, TransactionType.outgoing.rawValue)
        XCTAssertEqual(mappedK.status, .rejected)
        XCTAssertEqual(mappedK.timestamp, 1_700_000_000)
        XCTAssertEqual(mappedK.fees.first?.amount.decimalValue, Decimal(string: "0.002"))
        XCTAssertEqual(mappedK.assetId, asset.id)
        let kaiaToken: KaiaHistoryTransaction = try decode("""
        {"transactionHash":"0xk2","datetime":"2023-11-14T22:13:20Z","from":"\(peer)","to":"\(evm)","amount":3,
         "contract":{"contractAddress":"0xkt"},"status":{"status":"Success"}}
        """)
        let mappedKT = try AssetTransactionData.createTransaction(from: kaiaToken, address: evm, chain: chain, asset: asset)
        XCTAssertEqual(mappedKT.type, TransactionType.incoming.rawValue)
        XCTAssertEqual(mappedKT.status, .commited)
        XCTAssertTrue(mappedKT.fees.isEmpty, "Token rows carry no network fee")
        XCTAssertEqual(mappedKT.assetId, "0xkt")
        let kaiaBadDate: KaiaHistoryTransaction = try decode("""
        {"transactionHash":"0xk3","datetime":"yesterday","from":"\(peer)","amount":1}
        """)
        XCTAssertThrowsError(try AssetTransactionData.createTransaction(from: kaiaBadDate, address: evm, chain: chain, asset: asset)) {
            XCTAssertEqual($0 as? KaiaHistoryError, .providerRejected)
        }
    }

    private func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
}
