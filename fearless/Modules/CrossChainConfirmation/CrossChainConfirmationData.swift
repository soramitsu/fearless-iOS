import Foundation
import BigInt

struct CrossChainConfirmationData {
    let wallet: MetaAccountModel
    let originalChainAsset: ChainAsset
    let destChainModel: ChainModel
    let amount: BigUInt
    let amountViewModel: BalanceViewModelProtocol
    let originalChainFee: BalanceViewModelProtocol
    let destChainFee: BalanceViewModelProtocol
}
