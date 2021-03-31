import UIKit
import SoraUI
import SoraFoundation

protocol StoriesProgressBarDataSource: class {
    func numberOfSegments() -> Int
    func segmentDuration() -> TimeInterval
}

protocol StoriesProgressBarDelegate: class {
    func didFinishAnimation(index: Int)
}

@IBDesignable
extension StoriesProgressBar {
    @IBInspectable
    var padding: CGFloat {
        get {
            return stackView.spacing
        }

        set {
            stackView.spacing = newValue
            setNeedsLayout()
        }
    }
}

class StoriesProgressBar: UIView {
    private(set) var stackView: UIStackView!
    private(set) var currentIndex: Int = 0
    private var timer: CountdownTimerProtocol?

    private struct Constants {
        static let padding: CGFloat = 8
        static let height: CGFloat = 2
    }

    private var segments: [ProgressView] = []
    private var animationDuration: TimeInterval = 5

    weak var dataSource: StoriesProgressBarDataSource?

    // MARK: - Overrides
    public override init(frame: CGRect) {
        print("Init [frame]")
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        print("Init [coder]")
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    public override func layoutSubviews() {
        print("layoutSubviews")
        super.layoutSubviews()

        stackView.frame = bounds
        configureSegmentsLayout()
    }

    // MARK: - Private functions
    private func configure() {
        print("configure")
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
        stackView.axis = .horizontal
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

    private func configureSegments(startingPosition: Int) {
        clear()

        let numberOfSegments = self.dataSource?.numberOfSegments() ?? 0

        guard numberOfSegments > 0 else { return }
        currentIndex = startingPosition

        for index in 0..<numberOfSegments {
            let progressView = ProgressView()

            progressView.fillColor = UIColor.init(white: 1.0, alpha: 0.4)
            progressView.animationDuration = CGFloat(animationDuration)

            if index < currentIndex {
                progressView.setProgress(1, animated: false)
            }

            stackView.addArrangedSubview(progressView)
            segments.append(progressView)
        }
    }

    private func clear() {
        segments = []

        stackView.arrangedSubviews.forEach({
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        })

        currentIndex = 0
    }
}

extension StoriesProgressBar: StoriesProgressAnimatorProtocol {
    func setCurrentIndex(newIndex: Int) {
        guard newIndex < segments.count else { return }

        // segments[currentIndex].setProgress(1, animated: false)
        // TODO: This is for case when animation is in progress
//        segments[newIndex].setProgress(0, animated: false)
//        segments[newIndex].setProgress(1, animated: true)
        // newIndex > currentIndex
        // If we are moving forward, fill current segment
        // newIndex < currentIndex
        // If we are moving backward, empty current segment

        stop()
        if newIndex > currentIndex {
            segments[currentIndex].setProgress(1, animated: false)
        } else {
            segments[currentIndex].setProgress(0, animated: false)
            segments[newIndex].setProgress(0, animated: false)
        }
        currentIndex = newIndex
    }

    func redrawSegments(startingPosition: Int) {
        configureSegments(startingPosition: startingPosition)
        setNeedsLayout()
        layoutIfNeeded()
    }

    func start() {
        segments[currentIndex].setProgress(1, animated: true)
    }

    func pause() {
        segments[currentIndex].pause()
    }

    func resume() {
        segments[currentIndex].resume()
    }

    func stop() {
        segments[currentIndex].stop()
    }

    func reset() {

    }
}

extension StoriesProgressBar: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {

    }

    func didCountdown(remainedInterval: TimeInterval) {

    }

    func didStop(with remainedInterval: TimeInterval) {

    }
}

extension ProgressView {
    func stop() {
        guard let pLayer = self.layer.sublayers?.last else { return }

        pLayer.removeAllAnimations()
    }

    func pause() {
        guard let pLayer = self.layer.sublayers?.last else { return }

        let pausedTime: CFTimeInterval = pLayer.convertTime(CACurrentMediaTime(), from: nil)
        pLayer.speed = 0.0
        pLayer.timeOffset = pausedTime

    }

    func resume() {
        guard let pLayer = self.layer.sublayers?.last else { return }

        let pausedTime = pLayer.timeOffset
        pLayer.speed = 1.0
        pLayer.timeOffset = 0.0
        pLayer.beginTime = 0.0
        let timeSincePause = pLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        pLayer.beginTime = timeSincePause
    }
}

