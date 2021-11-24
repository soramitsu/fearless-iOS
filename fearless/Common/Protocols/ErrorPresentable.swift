import Foundation

protocol ErrorPresentable: AnyObject {
    @discardableResult
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool
}
