import UIKit
import SoraFoundation

enum StaringIndex {
    case first
    case last(array: [StorySlide])

    var index: Int {
        switch self {
        case .first:
            return 0
        case let .last(value):
            return value.count - 1
        }
    }
}

final class StoriesViewController: UIViewController, ControllerBackedProtocol {
    private enum Constants {
        static let moveThreshold: CGFloat = 150.0
    }

    private enum PanDirection {
        case none
        case horizontal
        case vertical
    }

    private var currentStoryIndex = 0
    private var currentSlideIndex = 0
    private var uiIsSetUp: Bool = false
    private var viewModel: [SlideViewModel] = []
    private var initialTouchPoint: CGPoint = .init(x: 0, y: 0)
    private var swipeDirection: PanDirection = .none

    var presenter: StoriesPresenterProtocol!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var contentLabel: UILabel!
    @IBOutlet var learnMoreButton: TriangularedButton!
    @IBOutlet var progressBar: StoriesProgressBar!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupProgressBar()
        setupLocalization()
        setupGestureRecognizers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard !uiIsSetUp else { return }
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !uiIsSetUp else {
            progressBar.resume()
            return
        }

        setupContentVerticalFreeze()
        progressBar.start()
        uiIsSetUp = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        progressBar.pause()
    }

    @IBAction func closeButtonTouched() {
        presenter.activateClose()
    }

    @IBAction func learnMoreButtonTouched() {
        presenter.activateWeb()
    }

    // MARK: - Private functions

    private func bindViewModel() {
        let slideModel = viewModel[currentSlideIndex]

        titleLabel.text = slideModel.title
        contentLabel.text = slideModel.content
    }

    private func setupProgressBar() {
        progressBar.dataSource = self
        progressBar.delegate = self
    }

    private func setupContentVerticalFreeze() {
        progressBar.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: progressBar.frame.origin.y
        ).isActive = true
    }

    // MARK: - Gesture recognizers setup

    private func setupLongPressRecognizer() {
        let longPressRecognizer: UILongPressGestureRecognizer = .init(
            target: self,
            action: #selector(didRecieveLongPressGesture)
        )
        longPressRecognizer.minimumPressDuration = 0.2
        longPressRecognizer.delaysTouchesBegan = true
        view.addGestureRecognizer(longPressRecognizer)
    }

    private func setupSwipeRecognizer() {
        let panRecognizer: UIPanGestureRecognizer = .init(
            target: self,
            action: #selector(didRecievePanGesture)
        )
        view.addGestureRecognizer(panRecognizer)
    }

    private func setupTapRecognizer() {
        let tapRecognizer: UITapGestureRecognizer = .init(
            target: self,
            action: #selector(didRecieveTapGesture)
        )
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)
    }

    private func setupGestureRecognizers() {
        setupLongPressRecognizer()
        setupSwipeRecognizer()
        setupTapRecognizer()
    }

    // MARK: - Gesture actions

    @objc private func didRecieveLongPressGesture(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            progressBar.pause()
        case .ended, .cancelled:
            progressBar.resume()
        default:
            break
        }
    }

    @objc private func didRecievePanGesture(gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: view.window)

        // If everything has just began, remember initial touch point
        switch gesture.state {
        case .began:
            initialTouchPoint = touchPoint
            progressBar.pause()

        case .changed:
            if swipeDirection == .none {
                swipeDirection = detectSwipeDirection(by: initialTouchPoint, and: touchPoint)
            }

            moveView(to: touchPoint)

        case .ended,
             .cancelled:
            progressBar.resume()
            processSwipe(to: touchPoint)

            swipeDirection = .none
            initialTouchPoint = CGPoint(x: 0, y: 0)

        default:
            break
        }
    }

    @objc private func didRecieveTapGesture(gesture: UITapGestureRecognizer) {
        guard let size = view.window?.frame.size else { return }
        guard size.width != 0 else { return }

        let touchPoint = gesture.location(ofTouch: 0, in: view.window)

        if touchPoint.x <= size.width / 2.0 {
            presenter.proceedToPreviousSlide()
        } else {
            presenter.proceedToNextSlide()
        }
    }

    // MARK: - Recognizers accessory functions

    private func moveView(to touchPoint: CGPoint) {
        switch swipeDirection {
        case .vertical:
            guard touchPoint.y > initialTouchPoint.y else { break }
            view.frame = CGRect(
                x: 0,
                y: touchPoint.y - initialTouchPoint.y,
                width: view.frame.size.width,
                height: view.frame.size.height
            )
        case .horizontal, .none:
            break // Add animation here in future
        }
    }

    private func restoreViewPosition() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame = CGRect(
                x: 0,
                y: 0,
                width: self.view.frame.size.width,
                height: self.view.frame.size.height
            )

        })
    }

    private func processSwipe(to touchPoint: CGPoint) {
        switch swipeDirection {
        case .horizontal:
            if touchPoint.x - initialTouchPoint.x > Constants.moveThreshold {
                progressBar.stop()
                presenter.proceedToPreviousStory(startingFrom: .first)
            } else if touchPoint.x - initialTouchPoint.x < -Constants.moveThreshold {
                progressBar.stop()
                presenter.proceedToNextStory()
            }

        case .vertical:
            if touchPoint.y - initialTouchPoint.y > Constants.moveThreshold {
                progressBar.stop()
                presenter.activateClose()
                break
            }

            restoreViewPosition()
        default:
            break
        }
    }

    private func detectSwipeDirection(by firstPoint: CGPoint, and secondPoint: CGPoint) -> PanDirection {
        guard firstPoint != secondPoint else { return .none }
        guard let size = view.window?.frame.size else { return .none }
        guard size.width != 0, size.height != 0 else { return .none }

        let deltaX = firstPoint.x - secondPoint.x
        let deltaY = firstPoint.y - secondPoint.y

        if abs(deltaX) / size.width >= abs(deltaY) / size.height {
            return .horizontal
        }

        return .vertical
    }
}

extension StoriesViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        learnMoreButton.imageWithTitleView?.title = R.string.localizable
            .commonLearnMore(preferredLanguages: languages)
        learnMoreButton.imageWithTitleView?.titleFont = .h5Title
        learnMoreButton.imageWithTitleView?.iconImage = nil
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

// MARK: - StoriesViewProtocol

extension StoriesViewController: StoriesViewProtocol {
    func didRecieve(
        viewModel: [SlideViewModel],
        startingFrom slide: StaringIndex = .first
    ) {
        self.viewModel = viewModel
        currentSlideIndex = slide.index
        bindViewModel()

        progressBar.redrawSegments(startingPosition: currentSlideIndex)

        guard uiIsSetUp else { return }
        progressBar.start()
    }

    func didRecieve(newSlideIndex index: Int) {
        currentSlideIndex = index
        bindViewModel()
        progressBar.setCurrentSegment(newIndex: index)
        progressBar.start()
    }
}

extension StoriesViewController: StoriesProgressBarDelegate {
    func didFinishSegmentAnimation() {
        presenter.proceedToNextSlide()
    }
}

extension StoriesViewController: StoriesProgressBarDataSource {
    func segmentDuration() -> TimeInterval {
        5.0
    }

    func numberOfSegments() -> Int {
        viewModel.count
    }
}

extension StoriesViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view != learnMoreButton
    }
}
