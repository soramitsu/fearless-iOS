import UIKit
import Kingfisher

protocol ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool, cornerRadius: CGFloat, completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?)
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool, cornerRadius: CGFloat)
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool)
    func cancel(on imageView: UIImageView)
}
