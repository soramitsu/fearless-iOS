import UIKit
import SoraFoundation

final class StoriesViewController: UIViewController, ControllerBackedProtocol {
    var presenter: StoriesPresenterProtocol!
    private var currentStoryIndex = 0

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var progressView: StoryProgressView!

//    private var model = StoriesFactory.createModel()
    private var story: Story?

    private var initialTouchPoint: CGPoint = .init(x: 0, y: 0)

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
    private func configureGestureRecognizers() {
        let longRecognizer: UILongPressGestureRecognizer = .init(target: self,
                                                                 action: #selector(panGestureRecognizerHandler))
        longRecognizer.minimumPressDuration = 0.2
        longRecognizer.delaysTouchesBegan = true
        view.addGestureRecognizer(longRecognizer)

        let swipeRecognizer: UIPanGestureRecognizer = .init(target: self,
                                                            action: #selector(panGestureRecognizerHandler))
        view.addGestureRecognizer(swipeRecognizer)
    }

    @objc func panGestureRecognizerHandler(gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: self.view?.window)
        if gesture.state == .began {
            initialTouchPoint = touchPoint
            // TODO: Pause timer
        } else if gesture.state == .changed {
            if touchPoint.y - initialTouchPoint.y > 0 {
                view.frame = CGRect(x: 0,
                                    y: touchPoint.y - initialTouchPoint.y,
                                    width: view.frame.size.width,
                                    height: view.frame.size.height)
            }
        } else if gesture.state == .ended || gesture.state == .cancelled {
            if touchPoint.y - initialTouchPoint.y > 150 {
                // TODO: Stop timer completely
                self.presenter.activateClose()
            } else {
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.frame = CGRect(x: 0,
                                             y: 0,
                                             width: self.view.frame.size.width,
                                             height: self.view.frame.size.height)
                    // TODO: Resume timer
                })
            }
        }
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
