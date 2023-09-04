import UIKit
import Kingfisher

protocol ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool, cornerRadius: CGFloat)
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool)
    func loadImage(on imageView: UIImageView, placholder: Placeholder?, targetSize: CGSize, animated: Bool)
    func cancel(on imageView: UIImageView)
}
