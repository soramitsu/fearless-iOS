import Foundation
import TonSwift
import TonAPI
import BigInt
import SSFModels

struct TonAccountEvents: Codable {
    let address: TonSwift.Address
    let events: [TonAccountEvent]
    let startFrom: Int64
    let nextFrom: Int64

    func toContext() -> [String: String]? {
        var context: [String: String] = [:]
        context["startFrom"] = String(startFrom)
        context["nextFrom"] = String(nextFrom)
        return context
    }
}

public struct TonAccountEvent: Codable {
    public let eventId: String
    public let timestamp: TimeInterval
    public let account: WalletAccount
    public let isScam: Bool
    public let isInProgress: Bool
    public let fee: Int64
    public let actions: [AccountEventAction]
}

public struct WalletAccount: Equatable, Codable {
    public let address: TonSwift.Address
    public let name: String?
    public let isScam: Bool
    public let isWallet: Bool
}

public struct AccountEventAction: Codable {
    let type: ActionType
    let status: AccountEventStatus
    let preview: SimplePreview

    struct SimplePreview: Codable {
        let name: String
        let description: String
        let image: URL?
        let value: String?
        let valueImage: URL?
        let accounts: [WalletAccount]
    }

    enum ActionType: Codable {
        case tonTransfer(TonTransfer)
        case contractDeploy(ContractDeploy)
        case jettonTransfer(JettonTransfer)
        case nftItemTransfer(NFTItemTransfer)
        case subscribe(Subscription)
        case unsubscribe(Unsubscription)
        case auctionBid(AuctionBid)
        case nftPurchase(NFTPurchase)
        case depositStake(DepositStake)
        case withdrawStake(WithdrawStake)
        case withdrawStakeRequest(WithdrawStakeRequest)
        case jettonSwap(JettonSwap)
        case jettonMint(JettonMint)
        case jettonBurn(JettonBurn)
        case smartContractExec(SmartContractExec)
        case domainRenew(DomainRenew)
        case unknown
    }

    struct TonTransfer: Codable {
        let sender: WalletAccount
        let recipient: WalletAccount
        let amount: Int64
        let comment: String?
    }

    struct ContractDeploy: Codable {
        let address: TonSwift.Address
    }

    struct JettonTransfer: Codable {
        let sender: WalletAccount?
        let recipient: WalletAccount?
        let senderAddress: TonSwift.Address
        let recipientAddress: TonSwift.Address
        let amount: BigUInt
        let jettonInfo: TonJettonInfo
        let comment: String?
    }

    struct NFTItemTransfer: Codable {
        let sender: WalletAccount?
        let recipient: WalletAccount?
        let nftAddress: TonSwift.Address
        let comment: String?
        let payload: String?
    }

    struct Subscription: Codable {
        let subscriber: WalletAccount
        let subscriptionAddress: TonSwift.Address
        let beneficiary: WalletAccount
        let amount: Int64
        let isInitial: Bool
    }

    struct Unsubscription: Codable {
        let subscriber: WalletAccount
        let subscriptionAddress: TonSwift.Address
        let beneficiary: WalletAccount
    }

    struct AuctionBid: Codable {
        let auctionType: String
        let price: Price
        let nft: TonNFT?
        let bidder: WalletAccount
        let auction: WalletAccount
    }

    struct NFTPurchase: Codable {
        let auctionType: String
        let nft: TonNFT
        let seller: WalletAccount
        let buyer: WalletAccount
        let price: BigUInt
    }

    struct DepositStake: Codable {
        let amount: Int64
        let staker: WalletAccount
        let pool: WalletAccount
    }

    struct WithdrawStake: Codable {
        let amount: Int64
        let staker: WalletAccount
        let pool: WalletAccount
    }

    struct WithdrawStakeRequest: Codable {
        let amount: Int64?
        let staker: WalletAccount
        let pool: WalletAccount
    }

    struct RecoverStake: Codable {
        let amount: Int64
        let staker: WalletAccount
    }

    struct JettonSwap: Codable {
        let dex: String
        let amountIn: BigUInt
        let amountOut: BigUInt
        let tonIn: Int64?
        let tonOut: Int64?
        let user: WalletAccount
        let router: WalletAccount
        let jettonInfoIn: TonJettonInfo?
        let jettonInfoOut: TonJettonInfo?
    }

    struct JettonMint: Codable {
        let recipient: WalletAccount
        let recipientsWallet: TonSwift.Address
        let amount: BigUInt
        let jettonInfo: TonJettonInfo
    }

    struct JettonBurn: Codable {
        let sender: WalletAccount
        let senderWallet: TonSwift.Address
        let amount: BigUInt
        let jettonInfo: TonJettonInfo
    }

    struct SmartContractExec: Codable {
        let executor: WalletAccount
        let contract: WalletAccount
        let tonAttached: Int64
        let operation: String
        let payload: String?
    }

    struct DomainRenew: Codable {
        let domain: String
        let contractAddress: String
        let renewer: WalletAccount
    }

    struct Price: Codable {
        let amount: BigUInt
        let tokenName: String
    }
}

enum AccountEventStatus: Codable {
    case ok
    case failed
    case unknown(String)

    var rawValue: String? {
        switch self {
        case .ok: return nil
        case .failed: return "Failed"
        case let .unknown(value):
            return value
        }
    }

    init(rawValue: String) {
        switch rawValue {
        case "ok": self = .ok
        case "failed": self = .failed
        default: self = .unknown(rawValue)
        }
    }
}

public struct TonNFT: Codable {
    public let address: TonSwift.Address
    public let owner: WalletAccount?
    public let name: String?
    public let imageURL: URL?
    public let preview: Preview
    public let description: String?
    public let attributes: [Attribute]
    public let collection: TonNFTCollection?
    public let dns: String?
    public let sale: Sale?
    public let isHidden: Bool

    public struct Marketplace {
        public let name: String
        public let url: URL?
    }

    public struct Attribute: Codable {
        public let key: String
        public let value: String
    }

    public enum Trust {
        public struct Approval {
            let name: String
        }

        case approvedBy([Approval])
    }

    public struct Preview: Codable {
        public let size5: URL?
        public let size100: URL?
        public let size500: URL?
        public let size1500: URL?
    }

    public struct Sale: Codable {
        public let address: TonSwift.Address
        public let market: WalletAccount
        public let owner: WalletAccount?
    }
}

public struct TonNFTCollection: Codable {
    public let address: TonSwift.Address
    public let name: String?
    public let description: String?
}

// MARK: - Inits

extension TonAccountEvent {
    init(accountEvent: Components.Schemas.AccountEvent) throws {
        eventId = accountEvent.event_id
        timestamp = TimeInterval(accountEvent.timestamp)
        account = try WalletAccount(accountAddress: accountEvent.account)
        isScam = accountEvent.is_scam
        isInProgress = accountEvent.in_progress
        fee = accountEvent.extra
        actions = accountEvent.actions.compactMap { action -> AccountEventAction? in
            do {
                let actionType: AccountEventAction.ActionType
                if let tonTransfer = action.TonTransfer {
                    actionType = .tonTransfer(try .init(tonTransfer: tonTransfer))
                } else if let jettonTransfer = action.JettonTransfer {
                    actionType = .jettonTransfer(try .init(jettonTransfer: jettonTransfer))
                } else if let contractDeploy = action.ContractDeploy {
                    actionType = .contractDeploy(try .init(contractDeploy: contractDeploy))
                } else if let nftItemTransfer = action.NftItemTransfer {
                    actionType = .nftItemTransfer(try .init(nftItemTransfer: nftItemTransfer))
                } else if let subscribe = action.Subscribe {
                    actionType = .subscribe(try .init(subscription: subscribe))
                } else if let unsubscribe = action.UnSubscribe {
                    actionType = .unsubscribe(try .init(unsubscription: unsubscribe))
                } else if let auctionBid = action.AuctionBid {
                    actionType = .auctionBid(try .init(auctionBid: auctionBid))
                } else if let nftPurchase = action.NftPurchase {
                    actionType = .nftPurchase(try .init(nftPurchase: nftPurchase))
                } else if let depositStake = action.DepositStake {
                    actionType = .depositStake(try .init(depositStake: depositStake))
                } else if let withdrawStake = action.WithdrawStake {
                    actionType = .withdrawStake(try .init(withdrawStake: withdrawStake))
                } else if let withdrawStakeRequest = action.WithdrawStakeRequest {
                    actionType = .withdrawStakeRequest(try .init(withdrawStakeRequest: withdrawStakeRequest))
                } else if let jettonSwap = action.JettonSwap {
                    actionType = .jettonSwap(try .init(jettonSwap: jettonSwap))
                } else if let jettonMint = action.JettonMint {
                    actionType = .jettonMint(try .init(jettonMint: jettonMint))
                } else if let jettonBurn = action.JettonBurn {
                    actionType = .jettonBurn(try .init(jettonBurn: jettonBurn))
                } else if let smartContractExec = action.SmartContractExec {
                    actionType = .smartContractExec(try .init(smartContractExec: smartContractExec))
                } else if let domainRenew = action.DomainRenew {
                    actionType = .domainRenew(try .init(domainRenew: domainRenew))
                } else {
                    actionType = .unknown
                }

                let status = AccountEventStatus(rawValue: action.status.rawValue)
                return AccountEventAction(type: actionType, status: status, preview: try .init(simplePreview: action.simple_preview))
            } catch {
                return nil
            }
        }
    }
}

extension WalletAccount {
    init(accountAddress: Components.Schemas.AccountAddress) throws {
        address = try TonSwift.Address.parse(accountAddress.address)
        name = accountAddress.name
        isScam = accountAddress.is_scam
        isWallet = accountAddress.is_wallet
    }
}

extension AccountEventAction.SimplePreview {
    init(simplePreview: Components.Schemas.ActionSimplePreview) throws {
        name = simplePreview.name
        description = simplePreview.description
        value = simplePreview.value

        var image: URL?
        if let actionImage = simplePreview.action_image {
            image = URL(string: actionImage)
        }
        self.image = image

        var valueImage: URL?
        if let valueImageString = simplePreview.value_image {
            valueImage = URL(string: valueImageString)
        }
        self.valueImage = valueImage

        accounts = simplePreview.accounts.compactMap { account in
            guard let walletAccount = try? WalletAccount(accountAddress: account) else { return nil }
            return walletAccount
        }
    }
}

extension AccountEventAction.TonTransfer {
    init(tonTransfer: Components.Schemas.TonTransferAction) throws {
        sender = try WalletAccount(accountAddress: tonTransfer.sender)
        recipient = try WalletAccount(accountAddress: tonTransfer.recipient)
        amount = tonTransfer.amount
        comment = tonTransfer.comment
    }
}

extension AccountEventAction.JettonTransfer {
    init(jettonTransfer: Components.Schemas.JettonTransferAction) throws {
        var sender: WalletAccount?
        var recipient: WalletAccount?
        if let senderAccountAddress = jettonTransfer.sender {
            sender = try? WalletAccount(accountAddress: senderAccountAddress)
        }
        if let recipientAccountAddress = jettonTransfer.recipient {
            recipient = try? WalletAccount(accountAddress: recipientAccountAddress)
        }

        self.sender = sender
        self.recipient = recipient
        senderAddress = try TonSwift.Address.parse(jettonTransfer.senders_wallet)
        recipientAddress = try TonSwift.Address.parse(jettonTransfer.recipients_wallet)
        amount = BigUInt(stringLiteral: jettonTransfer.amount)
        jettonInfo = try TonJettonInfo(jettonPreview: jettonTransfer.jetton)
        comment = jettonTransfer.comment
    }
}

extension AccountEventAction.ContractDeploy {
    init(contractDeploy: Components.Schemas.ContractDeployAction) throws {
        address = try TonSwift.Address.parse(contractDeploy.address)
    }
}

extension AccountEventAction.NFTItemTransfer {
    init(nftItemTransfer: Components.Schemas.NftItemTransferAction) throws {
        var sender: WalletAccount?
        var recipient: WalletAccount?
        if let senderAccountAddress = nftItemTransfer.sender {
            sender = try? WalletAccount(accountAddress: senderAccountAddress)
        }
        if let recipientAccountAddress = nftItemTransfer.recipient {
            recipient = try? WalletAccount(accountAddress: recipientAccountAddress)
        }

        self.sender = sender
        self.recipient = recipient
        nftAddress = try TonSwift.Address.parse(nftItemTransfer.nft)
        comment = nftItemTransfer.comment
        payload = nftItemTransfer.payload
    }
}

extension AccountEventAction.Subscription {
    init(subscription: Components.Schemas.SubscriptionAction) throws {
        subscriber = try WalletAccount(accountAddress: subscription.subscriber)
        subscriptionAddress = try TonSwift.Address.parse(subscription.subscription)
        beneficiary = try WalletAccount(accountAddress: subscription.beneficiary)
        amount = subscription.amount
        isInitial = subscription.initial
    }
}

extension AccountEventAction.Unsubscription {
    init(unsubscription: Components.Schemas.UnSubscriptionAction) throws {
        subscriber = try WalletAccount(accountAddress: unsubscription.subscriber)
        subscriptionAddress = try TonSwift.Address.parse(unsubscription.subscription)
        beneficiary = try WalletAccount(accountAddress: unsubscription.beneficiary)
    }
}

extension AccountEventAction.AuctionBid {
    init(auctionBid: Components.Schemas.AuctionBidAction) throws {
        auctionType = auctionBid.auction_type
        price = AccountEventAction.Price(price: auctionBid.amount)
        bidder = try WalletAccount(accountAddress: auctionBid.bidder)
        auction = try WalletAccount(accountAddress: auctionBid.auction)

        var nft: TonNFT?
        if let auctionBidNft = auctionBid.nft {
            nft = try TonNFT(nftItem: auctionBidNft)
        }
        self.nft = nft
    }
}

extension AccountEventAction.NFTPurchase {
    init(nftPurchase: Components.Schemas.NftPurchaseAction) throws {
        auctionType = nftPurchase.auction_type
        nft = try TonNFT(nftItem: nftPurchase.nft)
        seller = try WalletAccount(accountAddress: nftPurchase.seller)
        buyer = try WalletAccount(accountAddress: nftPurchase.buyer)
        price = BigUInt(stringLiteral: nftPurchase.amount.value)
    }
}

extension AccountEventAction.DepositStake {
    init(depositStake: Components.Schemas.DepositStakeAction) throws {
        amount = depositStake.amount
        staker = try WalletAccount(accountAddress: depositStake.staker)
        pool = try WalletAccount(accountAddress: depositStake.pool)
    }
}

extension AccountEventAction.WithdrawStake {
    init(withdrawStake: Components.Schemas.WithdrawStakeAction) throws {
        amount = withdrawStake.amount
        staker = try WalletAccount(accountAddress: withdrawStake.staker)
        pool = try WalletAccount(accountAddress: withdrawStake.pool)
    }
}

extension AccountEventAction.WithdrawStakeRequest {
    init(withdrawStakeRequest: Components.Schemas.WithdrawStakeRequestAction) throws {
        amount = withdrawStakeRequest.amount
        staker = try WalletAccount(accountAddress: withdrawStakeRequest.staker)
        pool = try WalletAccount(accountAddress: withdrawStakeRequest.pool)
    }
}

extension AccountEventAction.RecoverStake {
    init(recoverStake: Components.Schemas.ElectionsRecoverStakeAction) throws {
        amount = recoverStake.amount
        staker = try WalletAccount(accountAddress: recoverStake.staker)
    }
}

extension AccountEventAction.JettonSwap {
    init(jettonSwap: Components.Schemas.JettonSwapAction) throws {
        dex = jettonSwap.dex
        amountIn = BigUInt(stringLiteral: jettonSwap.amount_in)
        amountOut = BigUInt(stringLiteral: jettonSwap.amount_out)
        tonIn = jettonSwap.ton_in
        tonOut = jettonSwap.ton_out
        user = try WalletAccount(accountAddress: jettonSwap.user_wallet)
        router = try WalletAccount(accountAddress: jettonSwap.router)
        if let jettonMasterIn = jettonSwap.jetton_master_in {
            jettonInfoIn = try TonJettonInfo(jettonPreview: jettonMasterIn)
        } else {
            jettonInfoIn = nil
        }
        if let jettonMasterOut = jettonSwap.jetton_master_out {
            jettonInfoOut = try TonJettonInfo(jettonPreview: jettonMasterOut)
        } else {
            jettonInfoOut = nil
        }
    }
}

extension AccountEventAction.JettonMint {
    init(jettonMint: Components.Schemas.JettonMintAction) throws {
        recipient = try WalletAccount(accountAddress: jettonMint.recipient)
        recipientsWallet = try TonSwift.Address.parse(jettonMint.recipients_wallet)
        amount = BigUInt(stringLiteral: jettonMint.amount)
        jettonInfo = try TonJettonInfo(jettonPreview: jettonMint.jetton)
    }
}

extension AccountEventAction.JettonBurn {
    init(jettonBurn: Components.Schemas.JettonBurnAction) throws {
        sender = try WalletAccount(accountAddress: jettonBurn.sender)
        senderWallet = try TonSwift.Address.parse(jettonBurn.senders_wallet)
        amount = BigUInt(stringLiteral: jettonBurn.amount)
        jettonInfo = try TonJettonInfo(jettonPreview: jettonBurn.jetton)
    }
}

extension AccountEventAction.SmartContractExec {
    init(smartContractExec: Components.Schemas.SmartContractAction) throws {
        executor = try WalletAccount(accountAddress: smartContractExec.executor)
        contract = try WalletAccount(accountAddress: smartContractExec.contract)
        tonAttached = smartContractExec.ton_attached
        operation = smartContractExec.operation
        payload = smartContractExec.payload
    }
}

extension AccountEventAction.DomainRenew {
    init(domainRenew: Components.Schemas.DomainRenewAction) throws {
        domain = domainRenew.domain
        contractAddress = domainRenew.contract_address
        renewer = try WalletAccount(accountAddress: domainRenew.renewer)
    }
}

extension AccountEventAction.Price {
    init(price: Components.Schemas.Price) {
        amount = BigUInt(stringLiteral: price.value)
        tokenName = price.token_name
    }
}

extension TonNFT {
    private enum PreviewSize: String {
        case size5 = "5x5"
        case size100 = "100x100"
        case size500 = "500x500"
        case size1500 = "1500x1500"
    }

    init(nftItem: Components.Schemas.NftItem) throws {
        let address = try TonSwift.Address.parse(nftItem.address)
        var owner: WalletAccount?
        var name: String?
        var imageURL: URL?
        var description: String?
        var collection: TonNFTCollection?
        var isHidden = false

        if let ownerAccountAddress = nftItem.owner,
           let ownerWalletAccount = try? WalletAccount(accountAddress: ownerAccountAddress) {
            owner = ownerWalletAccount
        }

        let metadata = nftItem.metadata.additionalProperties.value as [String: AnyObject]
        name = metadata["name"] as? String
        imageURL = (metadata["image"] as? String).flatMap { URL(string: $0) }
        description = metadata["description"] as? String
        isHidden = (metadata["render_type"] as? String) == "hidden"

        var attributes = [Attribute]()
        if let attributesValue = (metadata["attributes"] as? [AnyObject]) {
            attributes = attributesValue
                .compactMap { $0 as? [String: AnyObject] }
                .compactMap { attributeObject -> Attribute? in
                    guard let key = attributeObject["trait_type"] as? String else { return nil }
                    let attributeValue: String
                    switch attributeObject["value"] {
                    case .none: return nil
                    case let .some(value):
                        switch value {
                        case let stringValue as String:
                            attributeValue = stringValue
                        case let intValue as Int:
                            attributeValue = String(intValue)
                        case let doubleValue as Int:
                            attributeValue = String(doubleValue)
                        default:
                            attributeValue = "-"
                        }
                    }
                    return Attribute(key: key, value: attributeValue)
                }
        }

        if let nftCollection = nftItem.collection,
           let address = try? TonSwift.Address.parse(nftCollection.address) {
            collection = TonNFTCollection(address: address, name: nftCollection.name, description: nftCollection.description)
        }

        if imageURL == nil,
           let previewURLString = nftItem.previews?[2].url,
           let previewURL = URL(string: previewURLString) {
            imageURL = previewURL
        }

        var sale: Sale?
        if let nftSale = nftItem.sale {
            let address = try TonSwift.Address.parse(nftSale.address)
            let market = try WalletAccount(accountAddress: nftSale.market)
            var ownerWalletAccount: WalletAccount?
            if let nftSaleOwner = nftItem.owner {
                ownerWalletAccount = try WalletAccount(accountAddress: nftSaleOwner)
            }
            sale = Sale(address: address, market: market, owner: ownerWalletAccount)
        }

        self.address = address
        self.owner = owner
        self.name = name
        self.imageURL = imageURL
        self.description = description
        self.attributes = attributes
        preview = Self.mapPreviews(nftItem.previews)
        self.collection = collection
        dns = nftItem.dns
        self.sale = sale
        self.isHidden = isHidden
    }

    private static func mapPreviews(_ previews: [Components.Schemas.ImagePreview]?) -> Preview {
        var size5: URL?
        var size100: URL?
        var size500: URL?
        var size1500: URL?

        previews?.forEach { preview in
            guard let previewSize = PreviewSize(rawValue: preview.resolution) else { return }
            switch previewSize {
            case .size5:
                size5 = URL(string: preview.url)
            case .size100:
                size100 = URL(string: preview.url)
            case .size500:
                size500 = URL(string: preview.url)
            case .size1500:
                size1500 = URL(string: preview.url)
            }
        }
        return Preview(size5: size5, size100: size100, size500: size500, size1500: size1500)
    }
}
