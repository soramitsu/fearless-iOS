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
        RemoteSVGFilter.image(from: data)
    }
}

/// SVGKit parses remote bytes with libxml2 inside the wallet process, including dApp-chosen
/// and NFT images, and fetches `<image>` and stylesheet links synchronously, which tells
/// their server the user's IP address. Only a small, self-contained document reaches it.
/// Anything else returns nil, so Kingfisher keeps the placeholder or fallback image.
enum RemoteSVGFilter {
    /// Large enough for the biggest shipped token icon (APE.svg, 3.3 MB); the structural
    /// rules below, not the size, are what keep active content out.
    static let maximumByteCount = 4 * 1024 * 1024

    /// The image for downloaded bytes, or nil when they are refused.
    static func image(from data: Data) -> UIImage? {
        if let uiImage = UIImage(data: data) {
            return uiImage
        }
        guard isAllowed(data) else {
            return nil
        }
        let svgImage = SVGKImage(data: data)
        return svgImage?.uiImage ?? UIImage()
    }

    static func isAllowed(_ data: Data) -> Bool {
        // A NUL byte never occurs in XML; it would let libxml2 read UTF-16 or UTF-32 text
        // that these checks see with a NUL between every character.
        guard data.count <= maximumByteCount, !data.contains(0), isValidUTF8(data),
              let rules = forbidden, let references = referenceAttribute, let declaration = xmlDeclaration
        else {
            return false
        }
        let text = String(decoding: data, as: UTF8.self)
        let range = NSRange(text.startIndex..., in: text)
        guard !rules.contains(where: { $0.firstMatch(in: text, options: [], range: range) != nil }) else {
            return false
        }
        let declaredEncodings = declaration.matches(in: text, options: [], range: range).compactMap {
            Range($0.range(at: 1), in: text).map { text[$0].lowercased() }
        }
        guard declaredEncodings.allSatisfy({ $0 == "utf-8" || $0 == "utf8" }) else {
            return false
        }
        return references.matches(in: text, options: [], range: range).allSatisfy { match in
            // An unquoted or unterminated value has no capture in groups 1 and 2.
            guard let valueRange = [1, 2].compactMap({ Range(match.range(at: $0), in: text) }).first else {
                return false
            }
            let value = text[valueRange]
            return value.hasPrefix("#") || isRasterDataURI(value)
        }
    }

    private static func isValidUTF8(_ data: Data) -> Bool {
        var iterator = data.makeIterator()
        var decoder = UTF8()
        while true {
            switch decoder.decode(&iterator) {
            case .scalarValue:
                continue
            case .emptyInput:
                return true
            case .error:
                return false
            }
        }
    }

    /// SVGKit decodes a `data:` link itself and parses whatever UIKit cannot decode as a nested
    /// SVG document that this filter never sees. Only base64 PNG, JPEG, GIF or WebP passes.
    private static func isRasterDataURI(_ value: Substring) -> Bool {
        guard let comma = value.firstIndex(of: ",") else {
            return false
        }
        let header = value[..<comma].lowercased()
        // SVGKit strips every whitespace character before it decodes the payload.
        var payload = ""
        for scalar in value[value.index(after: comma)...].unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }
            guard base64Alphabet.contains(scalar) else {
                return false
            }
            payload.unicodeScalars.append(scalar)
        }
        guard header.hasPrefix("data:image/"), header.hasSuffix(";base64"),
              let bytes = Data(base64Encoded: payload), !bytes.isEmpty
        else {
            return false
        }
        let signatures: [[UInt8]] = [
            [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
            [0xFF, 0xD8, 0xFF],
            Array("GIF8".utf8)
        ]
        let isWebP = bytes.count >= 12 && Array(bytes.prefix(4)) == Array("RIFF".utf8)
            && Array(bytes.dropFirst(8).prefix(4)) == Array("WEBP".utf8)
        return isWebP || signatures.contains { bytes.starts(with: $0) }
    }

    private static let base64Alphabet = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    )

    /// Each pattern refuses the document. A pattern that fails to compile refuses everything.
    private static let forbidden: [NSRegularExpression]? = compile([
        // DOCTYPE, ENTITY and every other markup declaration; comments and CDATA stay.
        #"<!(?!--|\[CDATA\[)"#,
        // Processing instructions other than the XML declaration, such as xml-stylesheet.
        #"<\?(?!xml\s)"#,
        // Active content, with or without a namespace prefix.
        #"<\s*(?:[a-z_][\w.:\-]*:)?(?:script|foreignobject|iframe|embed|object)\b"#,
        // Event-handler attributes such as onload= or ev:onclick=.
        #"(?<![\w.\-])on[a-z][\w.\-]*\s*="#,
        // A CSS url( that does not point at a #fragment of this document.
        #"url\s*\((?!\s*["']?#)"#,
        #"@import"#
    ])

    /// Every href, xlink:href (any prefix) or src value; group 1 or 2 holds a quoted value.
    private static let referenceAttribute: NSRegularExpression? = compile([
        #"(?:href|src)\s*=\s*(?:"([^"]*)"|'([^']*)'|[^\s>]*)"#
    ])?.first

    /// The encoding the XML declaration names; libxml2 would switch to it, UTF-7 included.
    private static let xmlDeclaration: NSRegularExpression? = compile([
        #"<\?xml\s[^>]*?encoding\s*=\s*["']([^"']*)["']"#
    ])?.first

    private static func compile(_ patterns: [String]) -> [NSRegularExpression]? {
        let compiled = patterns.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
        return compiled.count == patterns.count ? compiled : nil
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
