import Foundation

protocol ScreenAuthorizationWireframeProtocol: AnyObject {
    func showAuthorizationCompletion(with result: Bool)
}
