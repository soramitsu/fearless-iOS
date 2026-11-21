@testable import fearless
import Foundation
import TonAPI
import TonSwift
import XCTest

final class CovGTonModelsTests: XCTestCase {
    private let address = "0:" + String(repeating: "11", count: 32)
    private var wallet: [String: Any] {
        ["address": address, "name": "Wallet", "is_scam": false, "is_wallet": true]
    }

    private var jetton: [String: Any] {
        ["address": address, "name": "Token", "symbol": "JET", "decimals": 9, "image": "https://ton.invalid/token", "verification": "whitelist"]
    }

    private var nft: [String: Any] {
        ["address": address, "index": 1, "verified": true, "metadata": [:], "approved_by": []]
    }

    func testAllHistoryActionKindsMapTypedPayloadAndPreview() throws {
        let price: [String: Any] = ["value": "53", "token_name": "TON"]
        let stake: [String: Any] = ["pool": wallet, "staker": wallet, "amount": 53, "implementation": "tf"]
        let cases: [(String, [String: Any])] = [
            ("TonTransfer", ["sender": wallet, "recipient": wallet, "amount": 53, "comment": "memo"]),
            ("ContractDeploy", ["address": address, "interfaces": []]),
            ("JettonTransfer", ["sender": wallet, "recipient": wallet, "senders_wallet": address, "recipients_wallet": address, "amount": "53", "jetton": jetton]),
            ("NftItemTransfer", ["sender": wallet, "recipient": wallet, "nft": address, "comment": "memo", "payload": "payload"]),
            ("Subscribe", ["subscriber": wallet, "beneficiary": wallet, "subscription": address, "amount": 53, "initial": true]),
            ("UnSubscribe", ["subscriber": wallet, "beneficiary": wallet, "subscription": address]),
            ("AuctionBid", ["auction_type": "auction", "amount": price, "nft": nft, "bidder": wallet, "auction": wallet]),
            ("NftPurchase", ["auction_type": "auction", "nft": nft, "seller": wallet, "buyer": wallet, "amount": price]),
            ("DepositStake", stake), ("WithdrawStake", stake), ("WithdrawStakeRequest", stake),
            ("JettonSwap", ["dex": "dex", "amount_in": "53", "amount_out": "54", "ton_in": 1, "ton_out": 0,
                            "user_wallet": wallet, "router": wallet, "jetton_master_in": jetton, "jetton_master_out": jetton]),
            ("JettonMint", ["recipient": wallet, "recipients_wallet": address, "amount": "53", "jetton": jetton]),
            ("JettonBurn", ["sender": wallet, "senders_wallet": address, "amount": "53", "jetton": jetton]),
            ("SmartContractExec", ["executor": wallet, "contract": wallet, "ton_attached": 53, "operation": "call", "payload": "payload"]),
            ("DomainRenew", ["domain": "domain.ton", "contract_address": address, "renewer": wallet]),
        ]
        for (kind, payload) in cases {
            let value = try action(kind, payload: payload)
            XCTAssertEqual(value.status, .ok)
            XCTAssertEqual(value.preview.name, kind)
            XCTAssertEqual(value.preview.description, "Description")
            XCTAssertEqual(value.preview.accounts.count, 1)
            XCTAssertEqual(value.preview.value, "53 TON")
            XCTAssertEqual(value.preview.image?.host, "ton.invalid")
            switch value.type {
            case let .tonTransfer(item): XCTAssertEqual(item.amount, 53); XCTAssertEqual(item.comment, "memo")
            case let .contractDeploy(item): XCTAssertEqual(item.address.toRaw(), address)
            case let .jettonTransfer(item): XCTAssertEqual(item.amount, 53); XCTAssertEqual(item.sender?.name, "Wallet")
            case let .nftItemTransfer(item): XCTAssertEqual(item.nftAddress.toRaw(), address); XCTAssertEqual(item.payload, "payload")
            case let .subscribe(item): XCTAssertEqual(item.amount, 53); XCTAssertTrue(item.isInitial)
            case let .unsubscribe(item): XCTAssertEqual(item.subscriptionAddress.toRaw(), address)
            case let .auctionBid(item): XCTAssertEqual(item.price.amount, 53); XCTAssertNotNil(item.nft)
            case let .nftPurchase(item): XCTAssertEqual(item.price, 53); XCTAssertEqual(item.auctionType, "auction")
            case let .depositStake(item): XCTAssertEqual(item.amount, 53); XCTAssertEqual(item.pool.name, "Wallet")
            case let .withdrawStake(item): XCTAssertEqual(item.amount, 53); XCTAssertEqual(item.staker.name, "Wallet")
            case let .withdrawStakeRequest(item): XCTAssertEqual(item.amount, 53)
            case let .jettonSwap(item):
                XCTAssertEqual(item.amountIn, 53); XCTAssertEqual(item.amountOut, 54); XCTAssertTrue(item.tonIn); XCTAssertFalse(item.tonOut)
                XCTAssertEqual(item.jettonInfoIn?.symbol, "JET"); XCTAssertEqual(item.jettonInfoOut?.symbol, "JET")
            case let .jettonMint(item): XCTAssertEqual(item.amount, 53); XCTAssertEqual(item.recipientsWallet.toRaw(), address)
            case let .jettonBurn(item): XCTAssertEqual(item.amount, 53); XCTAssertEqual(item.senderWallet.toRaw(), address)
            case let .smartContractExec(item): XCTAssertEqual(item.tonAttached, 53); XCTAssertEqual(item.operation, "call")
            case let .domainRenew(item): XCTAssertEqual(item.domain, "domain.ton"); XCTAssertEqual(item.contractAddress.toRaw(), address)
            case .unknown: XCTFail("Unmapped action \(kind)")
            }
        }
    }

    func testMissingOptionalWalletsTokensAndStakeAmountsHaveDocumentedDefaults() throws {
        let transfer = try action("JettonTransfer", payload: ["senders_wallet": address, "recipients_wallet": address, "amount": "53", "jetton": jetton])
        guard case let .jettonTransfer(item) = transfer.type else { return XCTFail("Missing jetton transfer") }
        XCTAssertNil(item.sender); XCTAssertNil(item.recipient)
        let nftTransfer = try action("NftItemTransfer", payload: ["nft": address])
        guard case let .nftItemTransfer(nft) = nftTransfer.type else { return XCTFail("Missing NFT transfer") }
        XCTAssertNil(nft.sender); XCTAssertNil(nft.recipient)
        let swap = try action("JettonSwap", payload: ["dex": "dex", "amount_in": "1", "amount_out": "2", "user_wallet": wallet, "router": wallet])
        guard case let .jettonSwap(value) = swap.type else { return XCTFail("Missing swap") }
        XCTAssertNil(value.jettonInfoIn); XCTAssertNil(value.jettonInfoOut)
        XCTAssertFalse(value.tonIn); XCTAssertFalse(value.tonOut)
        let stake = try action("WithdrawStakeRequest", payload: ["pool": wallet, "staker": wallet, "implementation": "tf"])
        guard case let .withdrawStakeRequest(request) = stake.type else { return XCTFail("Missing withdrawal") }
        XCTAssertEqual(request.amount, 0)
        let auction = try action("AuctionBid", payload: ["auction_type": "auction", "amount": ["value": "1", "token_name": "TON"], "bidder": wallet, "auction": wallet])
        guard case let .auctionBid(bid) = auction.type else { return XCTFail("Missing bid") }
        XCTAssertNil(bid.nft)
        let unknown = try action("Unknown", payload: nil, status: "failed")
        guard case .unknown = unknown.type else { return XCTFail("Expected unknown") }
        XCTAssertEqual(unknown.status, .failed)
    }

    func testNFTMetadataAttributesPreviewsCollectionAndSaleArePreserved() throws {
        var payload = nft
        payload["owner"] = wallet
        payload["metadata"] = ["name": "Collectible", "image": "https://ton.invalid/original", "description": "Description", "render_type": "hidden",
                               "attributes": [["trait_type": "Text", "value": "gold"], ["trait_type": "Count", "value": 7],
                                              ["trait_type": "Ratio", "value": 1.5], ["trait_type": "Object", "value": ["x": 1]], ["trait_type": "Missing"], ["value": 1]]]
        payload["collection"] = ["address": address, "name": "Collection", "description": "Series"]
        payload["previews"] = ["5x5", "100x100", "500x500", "1500x1500", "custom"].map { ["resolution": $0, "url": "https://ton.invalid/\($0)"] }
        payload["sale"] = ["address": address, "market": wallet, "owner": wallet, "price": ["value": "1", "token_name": "TON"]]
        payload["dns"] = "domain.ton"
        let decoded = try JSONDecoder().decode(Components.Schemas.NftItem.self, from: JSONSerialization.data(withJSONObject: payload))
        let model = try TonNFT(nftItem: decoded)
        XCTAssertEqual(model.name, "Collectible")
        XCTAssertEqual(model.imageURL?.lastPathComponent, "original")
        XCTAssertEqual(model.description, "Description")
        XCTAssertEqual(model.attributes.map(\.key), ["Text", "Count", "Ratio", "Object"])
        XCTAssertEqual(model.attributes.map(\.value), ["gold", "7", "1.5", "-"])
        XCTAssertEqual(model.preview.size5?.lastPathComponent, "5x5")
        XCTAssertEqual(model.preview.size100?.lastPathComponent, "100x100")
        XCTAssertEqual(model.preview.size500?.lastPathComponent, "500x500")
        XCTAssertEqual(model.preview.size1500?.lastPathComponent, "1500x1500")
        XCTAssertEqual(model.collection?.name, "Collection")
        XCTAssertEqual(model.sale?.market.name, "Wallet")
        XCTAssertEqual(model.sale?.owner?.name, "Wallet")
        XCTAssertTrue(model.isHidden)
        XCTAssertEqual(model.dns, "domain.ton")
    }

    func testWalletAddressAndEventPaginationConversions() throws {
        let raw = try WalletAccount(address: address)
        let hex = try WalletAccount(address: "0x" + String(repeating: "11", count: 32))
        XCTAssertEqual(raw.address, hex.address)
        XCTAssertTrue(raw.isWallet)
        XCTAssertFalse(raw.isScam)
        XCTAssertThrowsError(try WalletAccount(address: "invalid"))
        let events = TonAccountEvents(address: raw.address, events: [], startFrom: 12, nextFrom: 34)
        XCTAssertEqual(events.toContext(), ["startFrom": "12", "nextFrom": "34"])
        var preview = jetton
        preview["symbol"] = ""
        let model = try TonJettonInfo(jettonPreview: JSONDecoder().decode(Components.Schemas.JettonPreview.self, from: JSONSerialization.data(withJSONObject: preview)))
        XCTAssertNil(model.symbol)
        XCTAssertEqual(model.fractionDigits, 9)
        XCTAssertEqual(model.verification, "whitelist")
    }

    private func action(_ kind: String, payload: [String: Any]?, status: String = "ok") throws -> AccountEventAction {
        var json: [String: Any] = ["type": kind, "status": status, "simple_preview": [
            "name": kind, "description": "Description", "accounts": [wallet], "value": "53 TON",
            "action_image": "https://ton.invalid/image", "value_image": "https://ton.invalid/value",
        ]]
        if let payload {
            json[kind] = payload
        }
        let api = try JSONDecoder().decode(Components.Schemas.Action.self, from: JSONSerialization.data(withJSONObject: json))
        return try AccountEventAction(action: api)
    }
}
