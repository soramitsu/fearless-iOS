import UIKit
import SoraFoundation

enum StaringIndex {
    case first
    case last(array: [Slide])

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
    private struct Constants {
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

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var learnMoreButton: TriangularedButton!
    @IBOutlet weak var progressBar: StoriesProgressBar!

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
    private func setupProgressBar() {
        progressBar.dataSource = self
        progressBar.delegate = self
    }

    private func configureLongPressRecognizer() {
        let longPressRecognizer: UILongPressGestureRecognizer = .init(target: self,
                                                                      action: #selector(didRecieveLongPressGesture))
        longPressRecognizer.minimumPressDuration = 0.2
        longPressRecognizer.delaysTouchesBegan = true
        view.addGestureRecognizer(longPressRecognizer)
    }

    private func configureSwipeRecognizer() {
        let panRecognizer: UIPanGestureRecognizer = .init(target: self,
                                                          action: #selector(didRecievePanGesture))
        view.addGestureRecognizer(panRecognizer)
    }

    private func configureTapRecognizer() {
        let tapRecognizer: UITapGestureRecognizer = .init(target: self,
                                                          action: #selector(didRecieveTapGesture))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)
    }

    private func setupGestureRecognizers() {
        configureLongPressRecognizer()
        configureSwipeRecognizer()
        configureTapRecognizer()
    }

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

    private func moveView(to touchPoint: CGPoint) {
        switch swipeDirection {
        case .vertical:
            guard touchPoint.y > initialTouchPoint.y else { break }
            view.frame = CGRect(x: 0,
                                y: touchPoint.y - initialTouchPoint.y,
                                width: view.frame.size.width,
                                height: view.frame.size.height)
        case .horizontal:
            break // Add animation here
        default:
            break
        }

    }

    fileprivate func processSwipe(to touchPoint: CGPoint) {
        // If ended || cancelled and threshold is not exceeded, get frame back
        switch swipeDirection {
        case .horizontal:
            if touchPoint.x - initialTouchPoint.x > Constants.moveThreshold {
                progressBar.stop()
                self.presenter.proceedToPreviousStory(startingFrom: .first)
            } else if touchPoint.x - initialTouchPoint.x < -Constants.moveThreshold {
                progressBar.stop()
                self.presenter.proceedToNextStory()
            }

        case .vertical:
            if touchPoint.y - initialTouchPoint.y > Constants.moveThreshold {
                progressBar.stop()
                self.presenter.activateClose()
                break
            }

            restoreViewPosition()
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

    private func restoreViewPosition() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame = CGRect(x: 0,
                                     y: 0,
                                     width: self.view.frame.size.width,
                                     height: self.view.frame.size.height)

        })
    }

    @objc private func didRecieveTapGesture(gesture: UITapGestureRecognizer) {
        guard let size = view.window?.frame.size else { return  }
        guard size.width != 0 else { return }

        let touchPoint = gesture.location(ofTouch: 0, in: view.window)
        print(touchPoint)

        if touchPoint.x <= size.width / 2.0 {
            presenter.proceedToPreviousSlide()
        } else {
            presenter.proceedToNextSlide()
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

    private func bindViewModel() {
        let slideModel = viewModel[currentSlideIndex]

        titleLabel.text = slideModel.title
        contentLabel.text = slideModel.content
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
    func didRecieve(viewModel: [SlideViewModel],
                    startingFrom slide: StaringIndex = .first) {
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

extension StoriesViewController: StoriesProgressViewDataSource {
    func slidesCount() -> Int {
        return viewModel.count
    }
}

extension StoriesViewController: StoriesProgressBarDelegate {
    func didFinishSegmentAnimation() {
        presenter.proceedToNextSlide()
    }
}

extension StoriesViewController: StoriesProgressBarDataSource {
    func segmentDuration() -> TimeInterval {
        return 5.0
    }

    func numberOfSegments() -> Int {
        return viewModel.count
    }
}

extension StoriesViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view != learnMoreButton
    }
}
