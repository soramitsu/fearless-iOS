import UIKit
import Kingfisher

final class BundleImageViewModel: NSObject {
    let image: UIImage?

    init(image: UIImage?) {
        self.image = image
    }
}

extension BundleImageViewModel: ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize _: CGSize, animated _: Bool, cornerRadius _: CGFloat, completionHandler _: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) {
        imageView.image = image
    }

    func loadImage(on imageView: UIImageView, targetSize _: CGSize, animated _: Bool, cornerRadius _: CGFloat) {
        imageView.image = image
    }

    func loadImage(on imageView: UIImageView, targetSize _: CGSize, animated _: Bool) {
        imageView.image = image
    }

    func cancel(on imageView: UIImageView) {
        imageView.image = nil
    }
}
