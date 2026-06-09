// swiftlint:disable file_length

import Foundation
import TonSwift
import TonAPI
import BigInt
import SSFModels
import SSFUtils

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

    struct Price: Codable {
        let amount: BigUInt
        let tokenName: String
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
        let pool: WalletAccount
        let staker: WalletAccount
        let amount: Int64
    }

    struct WithdrawStake: Codable {
        let pool: WalletAccount
        let staker: WalletAccount
        let amount: Int64
    }

    struct WithdrawStakeRequest: Codable {
        let pool: WalletAccount
        let staker: WalletAccount
        let amount: Int64
    }

    struct JettonSwap: Codable {
        let dex: String?
        let amountIn: BigUInt
        let amountOut: BigUInt
        let tonIn: Bool
        let tonOut: Bool
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
        let operation: String?
        let payload: String?
    }

    struct DomainRenew: Codable {
        let domain: String
        let contractAddress: TonSwift.Address
        let renewer: WalletAccount
    }

    struct UnknownAction: Codable {}
}

extension AccountEventAction.SimplePreview {
    init(simplePreview: Components.Schemas.ActionSimplePreview) {
        name = simplePreview.name
        description = simplePreview.description
        image = simplePreview.action_image.flatMap { URL(string: $0) }
        value = simplePreview.value
        valueImage = simplePreview.value_image.flatMap { URL(string: $0) }
        accounts = simplePreview.accounts.compactMap { try? WalletAccount(accountAddress: $0) }
    }
}

public enum AccountEventStatus: String, Codable {
    case ok
    case failed
    case unknown
}

extension AccountEventStatus {
    init(statusPayload: Components.Schemas.Action.statusPayload) {
        switch statusPayload {
        case .ok:
            self = .ok
        case .failed:
            self = .failed
        }
    }
}

public struct TonJettonBalance: Codable {
    public let item: TonJettonItem
    public let quantity: BigUInt
    public let priceData: [PriceData]
}

public struct TonJettonItem: Codable {
    public let jettonInfo: TonJettonInfo
    public let walletAddress: TonSwift.Address
}

public struct TonJettonInfo: Codable {
    public let address: TonSwift.Address
    public let name: String
    public let symbol: String?
    public let imageURL: URL?
    public let description: String?
    public let verification: String?
    public let capabilities: [String]?
    public let fractionDigits: Int

    init(jettonPreview: Components.Schemas.JettonPreview) throws {
        address = try TonSwift.Address.parse(jettonPreview.address)
        name = jettonPreview.name
        symbol = jettonPreview.symbol.isEmpty ? nil : jettonPreview.symbol
        imageURL = URL(string: jettonPreview.image)
        description = nil
        verification = jettonPreview.verification.rawValue
        capabilities = nil
        fractionDigits = jettonPreview.decimals
    }
}

public struct TonNFT: Codable {
    public struct Attribute: Codable {
        public let key: String
        public let value: String
    }

    public struct Preview: Codable {
        public let size5: URL?
        public let size100: URL?
        public let size500: URL?
        public let size1500: URL?
    }

    public struct TonNFTCollection: Codable {
        public let address: TonSwift.Address
        public let name: String?
        public let description: String?
    }

    public struct Sale: Codable {
        public let address: TonSwift.Address
        public let market: WalletAccount
        public let owner: WalletAccount?
    }

    public let address: TonSwift.Address
    public let owner: WalletAccount?
    public let name: String?
    public let imageURL: URL?
    public let description: String?
    public let attributes: [Attribute]
    public let preview: Preview
    public let collection: TonNFTCollection?
    public let dns: String?
    public let sale: Sale?
    public let isHidden: Bool
}

public struct TonPriceResponse: Codable {
    public let rates: [String: Components.Schemas.TokenRates]
}

extension WalletAccount {
    init(accountAddress: Components.Schemas.AccountAddress) throws {
        address = try TonSwift.Address.parse(accountAddress.address)
        name = accountAddress.name
        isScam = accountAddress.is_scam
        isWallet = accountAddress.is_wallet
    }

    init(address: AccountAddress) throws {
        let accountAddress = Components.Schemas.AccountAddress(
            address: try addressToTonAddress(address: address),
            name: nil,
            is_scam: false,
            icon: nil,
            is_wallet: true
        )
        self = try WalletAccount(accountAddress: accountAddress)
    }
}

extension AccountEventAction {
    init(action: Components.Schemas.Action) throws {
        status = AccountEventStatus(statusPayload: action.status)

        if let tonTransfer = action.TonTransfer {
            type = .tonTransfer(try TonTransfer(tonTransfer: tonTransfer))
        } else if let contractDeploy = action.ContractDeploy {
            type = .contractDeploy(try ContractDeploy(contractDeploy: contractDeploy))
        } else if let jettonTransfer = action.JettonTransfer {
            type = .jettonTransfer(try JettonTransfer(jettonTransfer: jettonTransfer))
        } else if let nftItemTransfer = action.NftItemTransfer {
            type = .nftItemTransfer(try NFTItemTransfer(nftItemTransfer: nftItemTransfer))
        } else if let subscription = action.Subscribe {
            type = .subscribe(try Subscription(subscription: subscription))
        } else if let unsubscribe = action.UnSubscribe {
            type = .unsubscribe(try Unsubscription(unsubscription: unsubscribe))
        } else if let auctionBid = action.AuctionBid {
            type = .auctionBid(try AuctionBid(auctionBid: auctionBid))
        } else if let nftPurchase = action.NftPurchase {
            type = .nftPurchase(try NFTPurchase(nftPurchase: nftPurchase))
        } else if let depositStake = action.DepositStake {
            type = .depositStake(try DepositStake(depositStake: depositStake))
        } else if let withdrawStake = action.WithdrawStake {
            type = .withdrawStake(try WithdrawStake(withdrawStake: withdrawStake))
        } else if let withdrawStakeRequest = action.WithdrawStakeRequest {
            type = .withdrawStakeRequest(try WithdrawStakeRequest(withdrawStakeRequest: withdrawStakeRequest))
        } else if let jettonSwap = action.JettonSwap {
            type = .jettonSwap(try JettonSwap(jettonSwap: jettonSwap))
        } else if let jettonMint = action.JettonMint {
            type = .jettonMint(try JettonMint(jettonMint: jettonMint))
        } else if let jettonBurn = action.JettonBurn {
            type = .jettonBurn(try JettonBurn(jettonBurn: jettonBurn))
        } else if let smartContractExec = action.SmartContractExec {
            type = .smartContractExec(try SmartContractExec(smartContractExec: smartContractExec))
        } else if let domainRenew = action.DomainRenew {
            type = .domainRenew(try DomainRenew(domainRenew: domainRenew))
        } else {
            type = .unknown
        }

        preview = SimplePreview(simplePreview: action.simple_preview)
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
        pool = try WalletAccount(accountAddress: depositStake.pool)
        staker = try WalletAccount(accountAddress: depositStake.staker)
        amount = depositStake.amount
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
        amount = withdrawStakeRequest.amount ?? 0
        staker = try WalletAccount(accountAddress: withdrawStakeRequest.staker)
        pool = try WalletAccount(accountAddress: withdrawStakeRequest.pool)
    }
}

extension AccountEventAction.JettonSwap {
    init(jettonSwap: Components.Schemas.JettonSwapAction) throws {
        dex = jettonSwap.dex
        amountIn = BigUInt(stringLiteral: jettonSwap.amount_in)
        amountOut = BigUInt(stringLiteral: jettonSwap.amount_out)
        tonIn = (jettonSwap.ton_in ?? 0) != 0
        tonOut = (jettonSwap.ton_out ?? 0) != 0
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
        contractAddress = try TonSwift.Address.parse(domainRenew.contract_address)
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

    // swiftlint:disable:next function_body_length
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

        let metadata = nftItem.metadata.additionalProperties.value
        name = metadata["name"] as? String
        imageURL = (metadata["image"] as? String).flatMap { URL(string: $0) }
        description = metadata["description"] as? String
        isHidden = (metadata["render_type"] as? String) == "hidden"

        var attributes = [Attribute]()
        if let attributesValue = metadata["attributes"] as? [Any?] {
            attributes = attributesValue
                .compactMap { $0 as? [String: Any] }
                .compactMap { attributeObject -> Attribute? in
                    guard let key = attributeObject["trait_type"] as? String else { return nil }
                    let attributeValue: String
                    switch attributeObject["value"] {
                    case .none:
                        return nil
                    case let .some(value):
                        switch value {
                        case let stringValue as String:
                            attributeValue = stringValue
                        case let intValue as Int:
                            attributeValue = String(intValue)
                        case let doubleValue as Double:
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

        if imageURL == nil {
            imageURL = Self.mapFallbackImageURL(from: nftItem.previews)
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

    private static func mapFallbackImageURL(from previews: [Components.Schemas.ImagePreview]?) -> URL? {
        guard let previews else {
            return nil
        }

        let preferredSizes: [PreviewSize] = [.size500, .size1500, .size100, .size5]

        for size in preferredSizes {
            if let preview = previews.first(where: { PreviewSize(rawValue: $0.resolution) == size }),
               let url = URL(string: preview.url) {
                return url
            }
        }

        return previews.compactMap { URL(string: $0.url) }.first
    }
}

private func addressToTonAddress(address: AccountAddress) throws -> String {
    if let tonAddress = try? TonSwift.Address.parse(address) {
        return tonAddress.toRaw()
    }
    guard address.count == 66 else {
        throw ConvenienceError(error: "Wrong TON address")
    }
    let decoded = try Data(hexStringSSF: address)
    if decoded.count == 32 {
        let tonAddress = try TonSwift.Address.parse(accountId: decoded, workchainId: 0)
        return tonAddress.toRaw()
    }
    let tonAddress = try TonSwift.Address.parse(accountId: decoded.tail(32), workchainId: 0)
    return tonAddress.toRaw()
}
