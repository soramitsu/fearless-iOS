import Foundation

enum WalletConnectMethod: String, CaseIterable {
    case polkadotSignTransaction = "polkadot_signTransaction"
    case polkadotSignMessage = "polkadot_signMessage"
    case ethereumSignTransaction = "eth_signTransaction"
    case ethereumSendTransaction = "eth_sendTransaction"
    case ethereumPersonalSign = "personal_sign"
    case ethereumSignTypeData = "eth_signTypedData"
    case ethereumSignTypeDataV4 = "eth_signTypedData_v4"
}
