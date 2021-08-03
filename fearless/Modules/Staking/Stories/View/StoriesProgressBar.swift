import UIKit
import SoraUI
import SoraFoundation

protocol StoriesProgressBarDataSource: AnyObject {
    func numberOfSegments() -> Int
    func segmentDuration() -> TimeInterval
}

protocol StoriesProgressBarDelegate: AnyObject {
    func didFinishSegmentAnimation()
}

@IBDesignable
extension StoriesProgressBar {
    @IBInspectable
    var padding: CGFloat {
        get {
            stackView.spacing
        }

        set {
            stackView.spacing = newValue
            setNeedsLayout()
        }
    }
}

class StoriesProgressBar: UIView {
    private enum ProgressBarAnimationState {
        case stopped
        case animating
        case paused
        case interrupted
    }

    private(set) var stackView: UIStackView!
    private(set) var currentIndex: Int = 0
    private var timer: CountdownTimerProtocol?
    private var remainingAnimationTime: TimeInterval = 0
    private var animationState: ProgressBarAnimationState = .stopped

    private enum Constants {
        static let height: CGFloat = 2
    }

    private var segments: [ProgressView] = []
    private var animationDuration: TimeInterval = 5

    weak var dataSource: StoriesProgressBarDataSource?
    weak var delegate: StoriesProgressBarDelegate?

    // MARK: - Overrides

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        stackView.frame = bounds
        configureSegmentsLayout()
    }

    // MARK: - Private functions

    private func configure() {
        backgroundColor = .clear

        configureTimer()
        configureStackViewIfNeeded()
        stackView.frame = bounds
    }

    private func configureTimer() {
        timer = CountdownTimer(delegate: self)
    }

    private func configureStackViewIfNeeded() {
        guard stackView == nil else { return }

        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        self.stackView = stackView

        addSubview(stackView)
    }

    private func configureSegmentsLayout() {
        segments.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false

            let heightConstraint = $0.heightAnchor.constraint(equalToConstant: Constants.height)
            heightConstraint.priority = .init(999)
            heightConstraint.isActive = true
        }
    }

    private func clear() {
        segments = []

        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        currentIndex = 0
    }

    private func configureSegments(startingPosition: Int) {
        clear()

        let numberOfSegments = dataSource?.numberOfSegments() ?? 0

        guard numberOfSegments > 0 else { return }
        currentIndex = startingPosition

        for index in 0 ..< numberOfSegments {
            let progressView = ProgressView()

            progressView.setProgress(0, animated: false)
            progressView.fillColor = UIColor(white: 1.0, alpha: 0.4)
            progressView.animationDuration = CGFloat(animationDuration)

            if index < currentIndex {
                progressView.setProgress(1, animated: false)
            }

            stackView.addArrangedSubview(progressView)
            segments.append(progressView)
        }

        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - StoriesProgressAnimatorProtocol

extension StoriesProgressBar: StoriesProgressAnimatorProtocol {
    func redrawSegments(startingPosition: Int) {
        stop()
        configureSegments(startingPosition: startingPosition)
        setCurrentSegment(newIndex: startingPosition)
    }

    func setCurrentSegment(newIndex: Int) {
        guard newIndex < segments.count else { return }

        stop()

        if newIndex > currentIndex {
            segments[currentIndex].setProgress(1, animated: false)
        } else if newIndex < currentIndex {
            segments[currentIndex].setProgress(0, animated: false)
            segments[newIndex].setProgress(0, animated: false)
        }

        currentIndex = newIndex
    }

    func start() {
        timer?.start(with: animationDuration)
    }

    func pause() {
        animationState = .paused
        timer?.stop()
    }

    func resume() {
        timer?.start(with: remainingAnimationTime)
    }

    func stop() {
        guard animationState == .animating else { return }

        animationState = .interrupted
        segments[currentIndex].stop()
        timer?.stop()
    }
}

// MARK: - CountdownTimerDelegate

extension StoriesProgressBar: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        switch animationState {
        case .stopped:
            segments[currentIndex].setProgress(1, animated: true)
        case .paused:
            segments[currentIndex].resume()
        default:
            break
        }

        animationState = .animating
    }

    func didCountdown(remainedInterval _: TimeInterval) {}

    func didStop(with remainedInterval: TimeInterval) {
        switch animationState {
        case .animating: // Timer has expired
            animationState = .stopped
            delegate?.didFinishSegmentAnimation()
        case .paused: // Paused
            segments[currentIndex].pause()
            remainingAnimationTime = remainedInterval
        case .interrupted:
            animationState = .stopped
        default:
            break
        }
    }
}
