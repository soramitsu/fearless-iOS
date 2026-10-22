import Foundation
import SSFModels
import FearlessWalletConnect

struct WalletConnectConfirmationInputData {
    let signingRequest: WalletConnectSigningRequest
    let session: Session
    let verification: WalletConnectVerification
}
