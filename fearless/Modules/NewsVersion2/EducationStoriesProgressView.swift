import UIKit

protocol EducationStoriesProgressViewDelegate: AnyObject {
    func storiesProgressViewChanged(index: Int)
    func storiesProgressViewFinished()
}

final class EducationStoriesProgressView: UIStackView {
    weak var delegate: EducationStoriesProgressViewDelegate?

    // MARK: - Constants

    private enum Constants {
        static let duration: TimeInterval = 10.0
        static let animationDelayLong: TimeInterval = 0.2
        static let animationDelayShort: TimeInterval = 0.1
    }

    // MARK: - Private properties

    private var currentAnimationIndex = 0
    private lazy var animator = UIViewPropertyAnimator()
    private var isValid: Bool {
        currentAnimationIndex < arrangedSubviews.count
    }

    // MARK: - Constructor

    init() {
        super.init(frame: CGRect.zero)
        setup()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public func

    func configure(segmentsCount: Int) {
        for _ in 0 ..< segmentsCount {
            addArrangedSubview(createProgressView())
        }
        startAnimation()
    }

    func startAnimation() {
        next()
    }

    func pauseAnimation() {
        animator.pauseAnimation()
    }

    func continueAnimation() {
        animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
    }

    func skip() {
        if currentAnimationIndex <= arrangedSubviews.count, currentAnimationIndex > 0 {
            if let currentSegment = arrangedSubviews[currentAnimationIndex - 1] as? UIProgressView {
                stopAnimation(for: currentSegment, progress: 1)
                next()
            }
        } else {
            next()
        }
    }

    func back() {
        stopPreviusSegmentAnimation()
        stopPreviusSegmentAnimation()

        let catchedIndex = currentAnimationIndex
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.animationDelayLong
        ) { [weak self] in
            guard let self = self else { return }
            if catchedIndex == self.currentAnimationIndex {
                self.next()
            }
        }
    }

    // MARK: - Private methods

    private func stopPreviusSegmentAnimation() {
        if currentAnimationIndex > 0 {
            currentAnimationIndex -= 1

            if let currentSegment = arrangedSubviews[currentAnimationIndex] as? UIProgressView {
                stopAnimation(for: currentSegment, progress: 0)
            }
        }
    }

    private func stopAnimation(
        for currentSegment: UIProgressView,
        progress: Float
    ) {
        animator.stopAnimation(true)
        currentSegment.setProgress(progress, animated: false)
        currentSegment.layer.removeAllAnimations()
    }

    private func handleProgress(_ progressView: UIProgressView) {
        let catchedIndex = currentAnimationIndex
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.animationDelayShort
        ) { [weak self] in
            guard let strongSelf = self else { return }
            if catchedIndex == strongSelf.currentAnimationIndex {
                strongSelf.currentAnimationIndex += 1

                strongSelf.animator = UIViewPropertyAnimator.runningPropertyAnimator(
                    withDuration: Constants.duration,
                    delay: 0,
                    options: .curveEaseInOut
                ) {
                    progressView.setProgress(1, animated: true)
                } completion: { [weak self] _ in
                    self?.next()
                }
                strongSelf.animator.startAnimation()
            }
        }
    }

    private func next() {
        if isValid {
            if let progressView = arrangedSubviews[currentAnimationIndex] as? UIProgressView {
                delegate?.storiesProgressViewChanged(index: currentAnimationIndex)
                handleProgress(progressView)
            }
        } else {
            delegate?.storiesProgressViewFinished()
        }
    }

    private func createProgressView() -> UIProgressView {
        let progressView = UIProgressView()
        progressView.progressImage = R.image.progressImage()
        progressView.trackImage = R.image.trackImage()
        progressView.setProgress(0, animated: true)
        return progressView
    }

    private func setup() {
        axis = .horizontal
        distribution = .fillEqually
        alignment = .fill
        spacing = 7
    }
}
