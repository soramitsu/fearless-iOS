import Foundation
import BigInt

struct CrossChainConfirmationData {
    let wallet: MetaAccountModel
    let originChainAsset: ChainAsset
    let destChainModel: ChainModel
    let amount: BigUInt
    let displayAmount: String
    let originChainFee: BalanceViewModelProtocol
    let destChainFee: BalanceViewModelProtocol
    let destChainFeeDecimal: Decimal
    let recipientAddress: String
}
