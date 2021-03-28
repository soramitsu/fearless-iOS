import UIKit

final class SlideProgressIndicatorView: UIView, ViewAnimator {
    //    public var storyId: String?
    //    public var snapIndex: Int?
    //    public var story: Story!
    public var widthConstraint: NSLayoutConstraint?
    public var state: ProgressorState = .notStarted
}

final class SlideProgressOutlineView: UIView {
    public var widthConstraint: NSLayoutConstraint?
    public var leftConstraint: NSLayoutConstraint?
    public var rightConstraint: NSLayoutConstraint?
}

protocol ViewAnimator {
    func start(with duration: TimeInterval,
               holderView: UIView,
               completion: @escaping (_ storyIdentifier: String, _ snapIndex: Int, _ isCancelledAbruptly: Bool) -> Void)
    func resume()
    func pause()
    func stop()
    func reset()
}

extension ViewAnimator where Self: SlideProgressIndicatorView {
    func start(with duration: TimeInterval, holderView: UIView, completion: @escaping (_ storyIdentifier: String,
                                                                                       _ snapIndex: Int,
                                                                                       _ isCancelledAbruptly: Bool) -> Void) {

        // Modifying the existing widthConstraint and setting the width equalTo holderView's widthAchor
        self.state = .running
        self.widthConstraint?.isActive = false
        self.widthConstraint = self.widthAnchor.constraint(equalToConstant: 0)
        self.widthConstraint?.isActive = true
        self.widthConstraint?.constant = holderView.safeAreaLayoutGuide.layoutFrame.width

        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveLinear], animations: {[weak self] in
            if let strongSelf = self {
                strongSelf.superview?.layoutIfNeeded()
            }
        }) { [weak self] (finished) in
            //            self?.story.isCancelledAbruptly = !finished
            self?.state = .finished
            if finished == true {
                if let strongSelf = self {
                    //                    return completion(strongSelf.storyId!, strongSelf.snapIndex!, strongSelf.story.isCancelledAbruptly)
                }
            } else {
                //                return completion(self?.storyId ?? "Unknown", self?.snapIndex ?? 0, self?.story.isCancelledAbruptly ?? true)
            }
        }
    }
    func resume() {
        let pausedTime = layer.timeOffset
        layer.speed = 1.0
        layer.timeOffset = 0.0
        layer.beginTime = 0.0
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        layer.beginTime = timeSincePause
        state = .running
    }
    func pause() {
        let pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0.0
        layer.timeOffset = pausedTime
        state = .paused
    }
    func stop() {
        resume()
        layer.removeAllAnimations()
        state = .finished
    }
    func reset() {
        state = .notStarted
        //        self.story.isCancelledAbruptly = true
        self.widthConstraint?.isActive = false
        self.widthConstraint = self.widthAnchor.constraint(equalToConstant: 0)
        self.widthConstraint?.isActive = true
    }
}

enum ProgressorState {
    case notStarted
    case paused
    case running
    case finished
}

final class StoryProgressView: UIView {
    let slidesCount: Int = 4
    private struct Constants {
        static let padding: CGFloat = 8
        static let height: CGFloat = 3
        static let progressIndicatorViewTag = 88
        static let progressViewTag = 99
    }

    private var progressOutlineViews: [SlideProgressOutlineView] = []
    private var progressIndicatorViews: [SlideProgressIndicatorView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = frame
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        createProgressOutlines()
        createProgressIndicators()
    }

    // TODO: Refactor this
    private func applyProperties<T: UIView>(_ view: T, with tag: Int? = nil, alpha: CGFloat = 1.0) -> T {
        view.layer.cornerRadius = 1
        view.layer.masksToBounds = true
        view.backgroundColor = UIColor.white.withAlphaComponent(alpha)
        if let tagValue = tag {
            view.tag = tagValue
        }
        return view
    }

    private func createProgressOutlines() {
        for index in 0..<slidesCount {
            let outlineView = SlideProgressOutlineView()
            outlineView.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(applyProperties(outlineView, with: index + Constants.progressIndicatorViewTag, alpha: 0.2))
            progressOutlineViews.append(outlineView)
        }

        // Setting Constraints for all progressView indicators
        for index in 0..<progressOutlineViews.count {
            let outlineView = progressOutlineViews[index]
            if index == 0 {
                outlineView.leftConstraint = outlineView.safeAreaLayoutGuide.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor,
                                                                                                   constant: Constants.padding)
                NSLayoutConstraint.activate([
                    outlineView.leftConstraint!,
                    outlineView.safeAreaLayoutGuide.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
                    outlineView.heightAnchor.constraint(equalToConstant: Constants.height)
                ])
                if progressOutlineViews.count == 1 {
                    outlineView.rightConstraint = safeAreaLayoutGuide.rightAnchor.constraint(equalTo: outlineView.safeAreaLayoutGuide.rightAnchor,
                                                                                             constant: Constants.padding)
                    outlineView.rightConstraint!.isActive = true
                }
            } else {
                let prePVIndicator = progressOutlineViews[index - 1]
                outlineView.widthConstraint = outlineView.widthAnchor.constraint(equalTo: prePVIndicator.widthAnchor,
                                                                                 multiplier: 1.0)
                outlineView.leftConstraint = outlineView.safeAreaLayoutGuide.leftAnchor.constraint(equalTo: prePVIndicator.safeAreaLayoutGuide.rightAnchor,
                                                                                                   constant: Constants.padding)
                NSLayoutConstraint.activate([
                    outlineView.leftConstraint!,
                    outlineView.safeAreaLayoutGuide.centerYAnchor.constraint(equalTo: prePVIndicator.safeAreaLayoutGuide.centerYAnchor),
                    outlineView.heightAnchor.constraint(equalToConstant: Constants.height),
                    outlineView.widthConstraint!
                ])
                if index == progressOutlineViews.count - 1 {
                    outlineView.rightConstraint = self.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: outlineView.safeAreaLayoutGuide.rightAnchor,
                                                                                                  constant: Constants.padding)
                    outlineView.rightConstraint!.isActive = true
                }
            }
        }
    }

    private func createProgressIndicators() {
        progressOutlineViews.forEach { outlineView in
            let progressIndicator = SlideProgressIndicatorView()
            progressIndicator.translatesAutoresizingMaskIntoConstraints = false
            outlineView.addSubview(applyProperties(progressIndicator))
            progressIndicatorViews.append(progressIndicator)

            progressIndicator.widthConstraint = progressIndicator.widthAnchor.constraint(equalToConstant: 0)
            NSLayoutConstraint.activate([
                progressIndicator.safeAreaLayoutGuide.leftAnchor.constraint(equalTo: outlineView.safeAreaLayoutGuide.leftAnchor),
                progressIndicator.heightAnchor.constraint(equalTo: outlineView.heightAnchor),
                progressIndicator.safeAreaLayoutGuide.topAnchor.constraint(equalTo: outlineView.safeAreaLayoutGuide.topAnchor),
                progressIndicator.widthConstraint!
            ])
        }
    }
}
