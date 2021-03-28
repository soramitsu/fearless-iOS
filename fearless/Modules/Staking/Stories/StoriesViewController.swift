import UIKit
import SoraFoundation

enum SwipeDirection {
    case none
    //    case swipeUp
    //    case swipeDown
    //    case swipeLeft
    //    case swipeRight
    case horizontal
    case vertical
}

final class StoriesViewController: UIViewController, ControllerBackedProtocol {
    var presenter: StoriesPresenterProtocol!
    private var currentStoryIndex = 0

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var progressView: StoryProgressView!

    //    private var model = StoriesFactory.createModel()
    private var story: Story?

    private var initialTouchPoint: CGPoint = .init(x: 0, y: 0)
    private var swipeDirection: SwipeDirection = .none

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureGestureRecognizers()
        presenter.setup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    @IBAction func closeButtonTouched() {
        presenter.activateClose()
    }

    @IBAction func learMoreButtonTouched() {
        presenter.activateWeb(slideIndex: currentStoryIndex)
    }

    // MARK: - Private functions
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
        view.addGestureRecognizer(tapRecognizer)
    }

    private func configureGestureRecognizers() {
        configureLongPressRecognizer()
        configureSwipeRecognizer()
        configureTapRecognizer()
    }

    @objc private func didRecieveLongPressGesture(gesture: UILongPressGestureRecognizer) {

    }

    private func moveView(to touchPoint: CGPoint) {
        switch swipeDirection {
        case .horizontal:
            view.frame = CGRect(x: touchPoint.x - initialTouchPoint.x,
                                y: 0,
                                width: view.frame.size.width,
                                height: view.frame.size.height)

        case .vertical:
            guard touchPoint.y > initialTouchPoint.y else { break }

            view.frame = CGRect(x: 0,
                                y: touchPoint.y - initialTouchPoint.y,
                                width: view.frame.size.width,
                                height: view.frame.size.height)

        default:
            break
        }

    }

    @objc private func didRecievePanGesture(gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: self.view.window)

        // If everything has just began, remember initial touch point
        switch gesture.state {
        case .began:
            initialTouchPoint = touchPoint
        // TODO: Pause timer

        case .changed:
            if swipeDirection == .none {
                swipeDirection = detectSwipeDirection(by: initialTouchPoint, and: touchPoint)
            }

            moveView(to: touchPoint)

        case .ended,
             .cancelled:
            swipeDirection = .none
            // If ended || cancelled and threshold is not exceeded, get frame back
            if touchPoint.y - initialTouchPoint.y > 150 {
                // TODO: Stop timer completely
                self.presenter.activateClose()
            } else {

                // Perform action
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame = CGRect(x: 0,
                                             y: 0,
                                             width: self.view.frame.size.width,
                                             height: self.view.frame.size.height)
                    // TODO: Resume timer
                })
            }
        default:
            break
        }
    }

    @objc private func didRecieveTapGesture(gesture: UITapGestureRecognizer) {

    }

    private func detectSwipeDirection(by firstPoint: CGPoint, and secondPoint: CGPoint) -> SwipeDirection {
        guard firstPoint != secondPoint else { return .none }
        let deltaX = firstPoint.x - secondPoint.x
        let deltaY = firstPoint.y - secondPoint.y

        guard let size = view.window?.frame.size else { return .none }
        guard size.width != 0, size.height != 0 else { return .none}

        if abs(deltaX) / size.width >= abs(deltaY) / size.height {
            return .horizontal
        }

        return .vertical
    }

    private func setupInitialSlide() {
        guard let story = self.story,
              let slide = self.story?.slides[0] else {return }

        self.titleLabel.text = "\(story.icon) \(story.title)"
        self.contentLabel.text = slide.description
        currentStoryIndex = 0
    }
}

extension StoriesViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        // Localize static UI elements here
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StoriesViewController: StoriesViewProtocol {
    func didRecieve(story: Story) {
        self.story = story
        setupInitialSlide()

        // setup progress view

        // start progress view
    }
}

extension StoriesViewController: StoriesProgressViewDataSource {
    func slidesCount() -> Int {
        return story?.slides.count ?? 0
    }
}
