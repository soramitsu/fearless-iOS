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
                if animating {
                    setVideo(url: mediaURL.absoluteString)
                } else {
                    setThumbnailImage(url: mediaURL)
                    activityIndicator.stopAnimating()
                }
            case .gif:
                setGIF(url: mediaURL.absoluteString)
                activityIndicator.stopAnimating()
            case .none:
                activityIndicator.stopAnimating()
            }
        }
    }

    override func hidePlayIndicator(animated _: Bool = false) {
        super.hidePlayIndicator()
        activityIndicator.stopAnimating()
    }
}
