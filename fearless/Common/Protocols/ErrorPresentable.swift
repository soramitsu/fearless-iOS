import Foundation

protocol ErrorPresentable: class {
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool
}
