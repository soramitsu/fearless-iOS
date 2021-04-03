import Foundation

protocol ErrorPresentable: AnyObject {
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool
}
