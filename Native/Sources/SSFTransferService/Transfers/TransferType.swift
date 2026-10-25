import Foundation

public enum TransferType {
    case substrate(SubstrateTransfer)
    case ethereum(EthereumTransfer)
    case xorless(XorlessTransfer)
}
