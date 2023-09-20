import UIKit
import MediaView
import AVFoundation

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
                DispatchQueue.main.async { [weak self] in
                    self?.setGIF(url: mediaURL.absoluteString)
                    self?.activityIndicator.stopAnimating()
                }
            case .none:
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }

    override func hidePlayIndicator(animated _: Bool = false) {
        super.hidePlayIndicator()
        activityIndicator.stopAnimating()
    }
}
