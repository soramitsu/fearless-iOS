import UIKit

public protocol WalletImageViewModelProtocol: AnyObject {
    var image: UIImage? { get }
    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void)
    func cancel()
}
