import Foundation
import FearlessUtils

struct SignerConfirmFeeViewModel {
    let fee: BalanceViewModelProtocol
    let total: BalanceViewModelProtocol
}

struct SignerConfirmCallViewModel {
    let accountName: String
    let accountIcon: DrawableIcon
    let moduleName: String
    let callName: String
    let amount: BalanceViewModelProtocol?
    let extrinsicString: String
}
