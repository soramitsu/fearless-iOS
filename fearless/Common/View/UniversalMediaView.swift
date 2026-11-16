import UIKit
import MediaView
import AVFoundation
import ImageIO

final class UniversalMediaView: MediaView {
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupActivityIndicator()
        shouldCacheStreamedMedia = true
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupActivityIndicator()
        shouldCacheStreamedMedia = true
    }

    private func setupActivityIndicator() {
        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        activityIndicator.isHidden = true
    }

    func bind(mediaURL: URL?, animating: Bool) {
        guard let mediaURL = mediaURL else {
            return
        }

        activityIndicator.startAnimating()

        Task {
            let mediaType = await MediaType.mediaType(from: mediaURL)

            switch mediaType {
            case .image:
                DispatchQueue.main.async { [weak self] in
                    self?.setImage(url: mediaURL.absoluteString)
                    self?.activityIndicator.stopAnimating()
                }
            case .video:
                DispatchQueue.main.async { [weak self] in
                    if animating {
                        self?.setVideo(url: mediaURL.absoluteString)
                    } else {
                        self?.setThumbnailImage(url: mediaURL)
                        self?.activityIndicator.stopAnimating()
                    }
                }
            case .gif:
                let data = try? await URLSession.shared.data(from: mediaURL).0
                DispatchQueue.main.async { [weak self] in
                    self?.showGIF(data: data, url: mediaURL)
                    self?.activityIndicator.stopAnimating()
                }
            case .none:
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }

    /// MediaView's GIF decoder crashes on a frame whose delay is zero or missing, so a GIF it cannot decode is shown
    /// as a still image instead.
    func showGIF(data: Data?, url: URL) {
        guard let data = data else {
            setGIF(url: url.absoluteString)
            return
        }

        if MediaViewGIFCompatibility.canDecode(data) {
            setGIF(data: data)
        } else {
            image = UIImage(data: data)
        }
    }

    override func hidePlayIndicator(animated _: Bool = false) {
        super.hidePlayIndicator()
        activityIndicator.stopAnimating()
    }
}

/// The MediaView pod reads every GIF frame's unclamped delay as text and calls `CFStringGetDoubleValue` on the delay
/// when it is zero; ImageIO gives a number, so a zero or missing delay crashes the app (`-[__NSCFNumber length]`).
enum MediaViewGIFCompatibility {
    static func canDecode(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else {
            return false
        }

        return (0 ..< count).allSatisfy { index in
            guard
                CGImageSourceCreateImageAtIndex(source, index, nil) != nil,
                let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
                let delay = gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
            else {
                return false
            }

            return delay.doubleValue > 0
        }
    }
}
