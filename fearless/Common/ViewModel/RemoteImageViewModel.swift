import UIKit
import Kingfisher

final class RemoteImageViewModel: NSObject {
    private var url: URL

    init(url: URL) {
        self.url = url
    }
}

extension RemoteImageViewModel: ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool) {
        let processor = DownsamplingImageProcessor(size: targetSize)
            |> RoundCornerImageProcessor(cornerRadius: targetSize.height / 2.0)

        var options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheOriginalImage
        ]

        if animated {
            options.append(.transition(.fade(0.25)))
        }

        imageView.kf.setImage(
            with: url,
            options: options
        )
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask()
    }
}
