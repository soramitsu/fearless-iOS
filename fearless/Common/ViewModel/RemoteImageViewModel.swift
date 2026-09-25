import UIKit
import Kingfisher
import SVGKit

final class RemoteImageViewModel: NSObject {
    private static let bundledBitcoinLogoCacheKey = "fearless.bundle.bitcoin-logo.bitcoinorg-f7931a-v1"
    private static let bundledBitcoinLogo = UIImage(named: "bitcoinLogo")
    private static let bundledBitcoinLogoData = bundledBitcoinLogo?.pngData()

    let url: URL
    let fallbackImage: UIImage?
    let imageSource: Source

    init(url: URL) {
        self.url = url
        fallbackImage = Self.fallbackImage(for: url)
        imageSource = Self.imageSource(for: url)
    }

    init?(url: URL?) {
        guard let url = url else {
            return nil
        }
        self.url = url
        fallbackImage = Self.fallbackImage(for: url)
        imageSource = Self.imageSource(for: url)
    }

    init?(string: String?) {
        guard
            let string = string,
            let url = URL(string: string)
        else {
            return nil
        }
        self.url = url
        fallbackImage = Self.fallbackImage(for: url)
        imageSource = Self.imageSource(for: url)
    }

    private static func fallbackImage(for url: URL) -> UIImage? {
        UniversalWalletRegistry.isBitcoinIconURL(url) ? bundledBitcoinLogo : nil
    }

    private static func imageSource(for url: URL) -> Source {
        if UniversalWalletRegistry.isBitcoinIconURL(url),
           let data = bundledBitcoinLogoData {
            return .provider(
                RawImageDataProvider(
                    data: data,
                    cacheKey: bundledBitcoinLogoCacheKey
                )
            )
        }

        return .network(url)
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
            with: imageSource,
            placeholder: fallbackImage,
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
            with: imageSource,
            placeholder: fallbackImage,
            options: options,
            completionHandler: completionHandler
        )
    }

    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool) {
        loadImage(on: imageView, targetSize: targetSize, animated: animated, cornerRadius: targetSize.height / 2.0)
    }

    func loadImage(on imageView: UIImageView, placholder: Placeholder?, targetSize: CGSize, animated: Bool) {
        let processor = SVGProcessor()
            |> DownsamplingImageProcessor(size: targetSize)
            |> RoundCornerImageProcessor(cornerRadius: targetSize.height / 2.0)

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
            with: imageSource,
            placeholder: placholder ?? fallbackImage,
            options: options
        )
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
