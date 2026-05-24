import UIKit
import AVFoundation
import Kingfisher
import SnapKit

final class UniversalMediaView: UIImageView {
    var allowLooping = false
    var shouldHidePlayButton = true
    var shouldAutoPlayAfterPresentation = false

    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerEndObserver: NSObjectProtocol?

    deinit {
        cleanupVideo()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupActivityIndicator()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupActivityIndicator()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    private func setupActivityIndicator() {
        clipsToBounds = true
        contentMode = .scaleAspectFill
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
                    self?.setRemoteImage(url: mediaURL)
                }
            case .video:
                DispatchQueue.main.async { [weak self] in
                    if animating || self?.shouldAutoPlayAfterPresentation == true {
                        self?.setVideo(url: mediaURL)
                    } else {
                        self?.setVideoThumbnail(url: mediaURL)
                    }
                }
            case .gif:
                DispatchQueue.main.async { [weak self] in
                    self?.setRemoteImage(url: mediaURL)
                }
            case .none:
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }

    func hidePlayIndicator(animated _: Bool = false) {
        activityIndicator.stopAnimating()
    }

    private func setRemoteImage(url: URL) {
        cleanupVideo()
        kf.setImage(with: url) { [weak self] _ in
            self?.activityIndicator.stopAnimating()
        }
    }

    private func setVideo(url: URL) {
        cleanupVideo()
        image = nil

        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = bounds
        layer.insertSublayer(playerLayer, at: 0)

        if allowLooping {
            playerEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        self.player = player
        self.playerLayer = playerLayer
        activityIndicator.stopAnimating()
        player.play()
    }

    private func setVideoThumbnail(url: URL) {
        cleanupVideo()

        Task.detached(priority: .userInitiated) {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let image = try? generator.copyCGImage(
                at: CMTime(seconds: 0, preferredTimescale: 600),
                actualTime: nil
            )

            await MainActor.run { [weak self] in
                if let image {
                    self?.image = UIImage(cgImage: image)
                }
                self?.activityIndicator.stopAnimating()
            }
        }
    }

    private func cleanupVideo() {
        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil

        if let playerEndObserver {
            NotificationCenter.default.removeObserver(playerEndObserver)
            self.playerEndObserver = nil
        }
    }
}
