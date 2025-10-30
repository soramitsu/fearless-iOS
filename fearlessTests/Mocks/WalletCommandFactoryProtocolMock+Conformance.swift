import UIKit
@testable import fearless

// Bridge the hand-written test mock to the protocol used by the app shims
extension WalletCommandFactoryProtocolMock: WalletCommandFactoryProtocol {}

