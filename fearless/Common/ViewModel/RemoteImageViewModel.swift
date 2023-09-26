import UIKit
import Kingfisher
import SVGKit

final class RemoteImageViewModel: NSObject {
    let url: URL

    init(url: URL) {
        self.url = url
    }
}

extension RemoteImageViewModel: ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool, cornerRadius: CGFloat) {
        loadImage(on: imageView, targetSize: targetSize, animated: animated, cornerRadius: cornerRadius, completionHandler: nil)
    }

    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool, cornerRadius: CGFloat, additionalOptions: KingfisherOptionsInfo) {
        let processor = SVGProcessor()
            |> DownsamplingImageProcessor(size: targetSize)
            |> RoundCornerImageProcessor(cornerRadius: cornerRadius)

        var options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteSerializer.shared),
            .cacheOriginalImage,
            .diskCacheExpiration(.days(1))
        ] + additionalOptions

        if animated {
            options.append(.transition(.fade(0.25)))
        }

        imageView.kf.setImage(
            with: url,
            options: options
        )
    }

    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool, cornerRadius: CGFloat, completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) {
        let processor = SVGProcessor()
            |> DownsamplingImageProcessor(size: targetSize)
            |> RoundCornerImageProcessor(cornerRadius: cornerRadius)

        var options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteSerializer.shared),
            .cacheOriginalImage,
            .diskCacheExpiration(.days(1))
        ]

        if animated {
            options.append(.transition(.fade(0.25)))
        }

        imageView.kf.setImage(
            with: url,
            options: options,
            completionHandler: completionHandler
        )
    }

    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool) {
        loadImage(on: imageView, targetSize: targetSize, animated: animated, cornerRadius: targetSize.height / 2.0)
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask()
    }
}

private final class RemoteSerializer: CacheSerializer {
    static let shared = RemoteSerializer()

    func data(with _: KFCrossPlatformImage, original: Data?) -> Data? {
        original
    }

    func image(with data: Data, options _: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        if let uiImage = UIImage(data: data) {
            return uiImage
        } else {
            let imsvg = SVGKImage(data: data)
            return imsvg?.uiImage ?? UIImage()
        }
    }
}

private final class SVGProcessor: ImageProcessor {
    let identifier: String = "jp.co.soramitsu.fearless.kf.svg.processor"

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            return image
        case let .data(data):
            return RemoteSerializer.shared.image(with: data, options: options)
        }
    }
}
