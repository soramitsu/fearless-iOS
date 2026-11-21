import XCTest
import UIKit
import UIKit.UIGestureRecognizerSubclass
import SSFModels
import SoraFoundation
import SoraUI
@testable import fearless

final class CovCStoriesPresenterSpy: StoriesPresenterProtocol {
    var calls: [String] = []
    var previousStoryStart: StaringIndex?

    func setup() { calls.append("setup") }
    func activateClose() { calls.append("close") }
    func activateWeb() { calls.append("web") }
    func proceedToNextStory() { calls.append("nextStory") }
    func proceedToPreviousStory(startingFrom slide: StaringIndex) {
        previousStoryStart = slide
        calls.append("previousStory")
    }

    func proceedToNextSlide() { calls.append("nextSlide") }
    func proceedToPreviousSlide() { calls.append("previousSlide") }
}

final class CovCStoriesViewSpy: UIViewController, StoriesViewProtocol {
    var received: [[SlideViewModel]] = []
    var startIndexes: [Int] = []
    var slideIndexes: [Int] = []

    var localizationManager: LocalizationManagerProtocol?

    func applyLocalization() {}

    func didRecieve(viewModel: [SlideViewModel], startingFrom slide: StaringIndex) {
        received.append(viewModel)
        startIndexes.append(slide.index)
    }

    func didRecieve(newSlideIndex index: Int) {
        slideIndexes.append(index)
    }
}

final class CovCStoriesWireframeSpy: StoriesWireframeProtocol {
    var closed = 0
    var shownURLs: [URL] = []

    func close(view _: StoriesViewProtocol?) {
        closed += 1
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        shownURLs.append(url)
    }
}

final class CovCStoriesProgressSource: StoriesProgressBarDataSource, StoriesProgressBarDelegate {
    var segments = 3
    var finished = 0

    func numberOfSegments() -> Int { segments }
    func segmentDuration() -> TimeInterval { 5 }
    func didFinishSegmentAnimation() { finished += 1 }
}

final class CovCStoriesPan: UIPanGestureRecognizer {
    var point: CGPoint = .zero
    var forcedState: UIGestureRecognizer.State = .possible

    override var state: UIGestureRecognizer.State {
        get { forcedState }
        set { forcedState = newValue }
    }

    override func location(in _: UIView?) -> CGPoint { point }
}

final class CovCStoriesTap: UITapGestureRecognizer {
    var point: CGPoint = .zero

    override func location(ofTouch _: Int, in _: UIView?) -> CGPoint { point }
}

final class CovCStoriesLongPress: UILongPressGestureRecognizer {
    var forcedState: UIGestureRecognizer.State = .possible

    override var state: UIGestureRecognizer.State {
        get { forcedState }
        set { forcedState = newValue }
    }
}

final class CovCStoriesTests: XCTestCase {
    private var window: UIWindow?
    private var hostedController: StoriesViewController?

    override func tearDown() {
        // Finish UIKit's deferred appearance before stopping its story timer.
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        hostedController?.progressBar.stop()
        hostedController?.progressBar.delegate = nil
        hostedController?.view.removeFromSuperview()
        hostedController = nil
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeModel() -> StoriesModel {
        StoriesModel(stories: [
            Story(icon: "A", title: "First", slides: [
                StorySlide(description: "one", urlString: "https://example.org/one"),
                StorySlide(description: "two", urlString: nil)
            ]),
            Story(icon: "B", title: "Second", slides: [
                StorySlide(description: "three", urlString: "https://example.org/three")
            ])
        ])
    }

    private func makePresenter(index: Int = 0) -> (StoriesPresenter, CovCStoriesViewSpy, CovCStoriesWireframeSpy) {
        let presenter = StoriesPresenter(selectedStoryIndex: index, viewModelFactory: StoriesViewModelFactory())
        let view = CovCStoriesViewSpy()
        let wireframe = CovCStoriesWireframeSpy()
        presenter.view = view
        presenter.wireframe = wireframe
        let interactor = StoriesInteractor(model: makeModel())
        interactor.presenter = presenter
        presenter.interactor = interactor
        return (presenter, view, wireframe)
    }

    private func makeController() -> (StoriesViewController, CovCStoriesPresenterSpy) {
        let controller = StoriesViewController(nib: R.nib.storiesViewController)
        let presenter = CovCStoriesPresenterSpy()
        controller.presenter = presenter
        controller.localizationManager = LocalizationManager.shared
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        self.window = window
        controller.loadViewIfNeeded()
        // A real presenter supplies slides during setup. The spy must supply them
        // before UIKit's deferred viewDidAppear starts the progress timer.
        controller.didRecieve(viewModel: slides(), startingFrom: .first)
        hostedController = controller
        controller.view.frame = window.bounds
        window.addSubview(controller.view)
        controller.view.layoutIfNeeded()
        // Attaching to a window may already deliver viewWillAppear (and so setup); tests start from a clean record.
        presenter.calls.removeAll()
        return (controller, presenter)
    }

    private func slides() -> [SlideViewModel] {
        [
            SlideViewModel(title: "T1", content: "C1"),
            SlideViewModel(title: "T2", content: "C2"),
            SlideViewModel(title: "T3", content: nil)
        ]
    }

    // MARK: - Presenter

    func testPresenterSetupDeliversFirstStory() {
        let (presenter, view, _) = makePresenter()

        presenter.setup()

        XCTAssertEqual(view.received.count, 1)
        XCTAssertEqual(view.received.first?.map(\.title), ["A First", "A First"])
        XCTAssertEqual(view.received.first?.map(\.content), ["one", "two"])
        XCTAssertEqual(view.startIndexes, [0])
    }

    func testPresenterSlideNavigationAcrossStories() {
        let (presenter, view, wireframe) = makePresenter()
        presenter.setup()

        presenter.proceedToNextSlide()
        XCTAssertEqual(view.slideIndexes, [1])

        presenter.proceedToNextSlide()
        XCTAssertEqual(view.received.count, 2)
        XCTAssertEqual(view.received.last?.map(\.title), ["B Second"])

        presenter.proceedToPreviousSlide()
        XCTAssertEqual(view.received.count, 3)
        XCTAssertEqual(view.startIndexes.last, 1, "going back starts from the last slide of the previous story")

        presenter.proceedToPreviousSlide()
        XCTAssertEqual(view.slideIndexes, [1, 0])

        presenter.proceedToPreviousSlide()
        XCTAssertEqual(wireframe.closed, 1, "going back from the very first slide closes the stories")
    }

    func testPresenterNextStoryPastTheEndCloses() {
        let (presenter, view, wireframe) = makePresenter(index: 1)
        presenter.setup()
        XCTAssertEqual(view.received.first?.map(\.title), ["B Second"])

        presenter.proceedToNextStory()
        XCTAssertEqual(wireframe.closed, 1)

        presenter.proceedToPreviousStory(startingFrom: .first)
        XCTAssertEqual(view.received.last?.map(\.title), ["A First", "A First"])
    }

    func testPresenterActivateWebOpensSlideURLOnlyWhenPresent() {
        let (presenter, view, wireframe) = makePresenter()
        presenter.activateWeb()
        XCTAssertTrue(wireframe.shownURLs.isEmpty, "no model yet")

        presenter.setup()
        presenter.activateWeb()
        XCTAssertEqual(wireframe.shownURLs, [URL(string: "https://example.org/one")].compactMap { $0 })

        presenter.proceedToNextSlide()
        presenter.activateWeb()
        XCTAssertEqual(wireframe.shownURLs.count, 1, "the second slide has no link")

        presenter.activateClose()
        XCTAssertEqual(wireframe.closed, 1)
        withExtendedLifetime(view) {}
    }

    func testPresenterWithoutModelIgnoresNavigation() {
        let (presenter, view, wireframe) = makePresenter()

        presenter.proceedToNextSlide()
        presenter.proceedToNextStory()
        presenter.proceedToPreviousSlide()

        XCTAssertTrue(view.received.isEmpty)
        XCTAssertTrue(view.slideIndexes.isEmpty)
        XCTAssertEqual(wireframe.closed, 0)
    }

    func testStaringIndexValues() {
        XCTAssertEqual(StaringIndex.first.index, 0)
        let array = [StorySlide(description: "a", urlString: nil), StorySlide(description: "b", urlString: nil)]
        XCTAssertEqual(StaringIndex.last(array: array).index, 1)
    }

}

extension CovCStoriesTests {
    // MARK: - View factory and wireframe

    func testViewFactoryBuildsRelaychainStories() throws {
        let asset = AssetModel(
            id: "dot",
            name: "DOT",
            symbol: "dot",
            precision: 10,
            icon: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        chain.assets = [asset]
        let view = try XCTUnwrap(StoriesViewFactory.createView(with: 0, chainAsset: ChainAsset(chain: chain, asset: asset)))
        let controller = try XCTUnwrap(view.controller as? StoriesViewController)
        XCTAssertNotNil(controller.presenter)

        let noStaking = ChainModelGenerator.generateAssetWithId("x", symbol: "X")
        XCTAssertNil(StoriesViewFactory.createView(with: 0, chainAsset: ChainAsset(chain: chain, asset: noStaking)))
    }

    func testWireframeCloseWithoutPresenterDoesNothing() {
        let view = CovCStoriesViewSpy()
        StoriesWireframe().close(view: view)
        XCTAssertNil(view.presentingViewController)
    }

    // MARK: - View controller

    func testControllerLifecycleAndBinding() throws {
        let (controller, presenter) = makeController()

        controller.viewWillAppear(false)
        XCTAssertEqual(presenter.calls, ["setup"])

        controller.didRecieve(viewModel: slides(), startingFrom: .first)
        XCTAssertEqual(controller.titleLabel.text, "T1")
        XCTAssertEqual(controller.contentLabel.text, "C1")
        XCTAssertEqual(controller.numberOfSegments(), 3)
        XCTAssertEqual(controller.segmentDuration(), 5.0)
        XCTAssertEqual(controller.progressBar.stackView.arrangedSubviews.count, 3)

        controller.viewDidAppear(false)
        controller.didRecieve(newSlideIndex: 2)
        XCTAssertEqual(controller.titleLabel.text, "T3")
        XCTAssertNil(controller.contentLabel.text)
        XCTAssertEqual(controller.progressBar.currentIndex, 2)

        controller.viewWillAppear(false)
        XCTAssertEqual(presenter.calls, ["setup"], "setup happens once")
        controller.viewDidAppear(false)
        controller.viewDidDisappear(false)

        controller.didRecieve(viewModel: slides(), startingFrom: .last(array: [
            StorySlide(description: "a", urlString: nil), StorySlide(description: "b", urlString: nil)
        ]))
        XCTAssertEqual(controller.titleLabel.text, "T2")
        XCTAssertEqual(controller.progressBar.currentIndex, 1)
    }

    func testControllerButtonsAndLocalization() {
        let (controller, presenter) = makeController()

        controller.closeButtonTouched()
        controller.learnMoreButtonTouched()
        controller.didFinishSegmentAnimation()
        XCTAssertEqual(presenter.calls, ["close", "web", "nextSlide"])

        controller.applyLocalization()
        XCTAssertEqual(
            controller.learnMoreButton.imageWithTitleView?.title,
            R.string.localizable.commonLearnMore(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        )
        XCTAssertEqual(controller.view.gestureRecognizers?.count, 3)
    }

    func testControllerTapGestureSplitsScreenHalves() {
        let (controller, presenter) = makeController()
        let selector = NSSelectorFromString("didRecieveTapGestureWithGesture:")
        XCTAssertTrue(controller.responds(to: selector))

        let tap = CovCStoriesTap()
        tap.point = CGPoint(x: 10, y: 400)
        controller.perform(selector, with: tap)
        tap.point = CGPoint(x: 380, y: 400)
        controller.perform(selector, with: tap)

        XCTAssertEqual(presenter.calls, ["previousSlide", "nextSlide"])
    }

    func testControllerHorizontalSwipesChangeStory() {
        let (controller, presenter) = makeController()
        controller.didRecieve(viewModel: slides(), startingFrom: .first)
        controller.progressBar.start()
        let selector = NSSelectorFromString("didRecievePanGestureWithGesture:")
        XCTAssertTrue(controller.responds(to: selector))

        swipe(controller, selector: selector, from: CGPoint(x: 50, y: 400), to: CGPoint(x: 300, y: 410))
        XCTAssertEqual(presenter.calls, ["previousStory"])
        XCTAssertEqual(presenter.previousStoryStart?.index, 0)

        swipe(controller, selector: selector, from: CGPoint(x: 300, y: 400), to: CGPoint(x: 50, y: 405))
        XCTAssertEqual(presenter.calls, ["previousStory", "nextStory"])

        swipe(controller, selector: selector, from: CGPoint(x: 100, y: 400), to: CGPoint(x: 150, y: 401))
        XCTAssertEqual(presenter.calls.count, 2, "a short swipe does nothing")
    }

    func testControllerVerticalSwipeClosesOrRestores() {
        let (controller, presenter) = makeController()
        controller.didRecieve(viewModel: slides(), startingFrom: .first)
        controller.progressBar.start()
        let selector = NSSelectorFromString("didRecievePanGestureWithGesture:")

        swipe(controller, selector: selector, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 102, y: 180))
        XCTAssertTrue(presenter.calls.isEmpty, "a short drag restores the position")

        swipe(controller, selector: selector, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 101, y: 500))
        XCTAssertEqual(presenter.calls, ["close"])
    }

    func testControllerLongPressPausesAndResumes() {
        let (controller, presenter) = makeController()
        controller.didRecieve(viewModel: slides(), startingFrom: .first)
        controller.progressBar.start()
        let selector = NSSelectorFromString("didRecieveLongPressGestureWithGesture:")
        XCTAssertTrue(controller.responds(to: selector))

        let press = CovCStoriesLongPress()
        for state in [UIGestureRecognizer.State.began, .ended, .began, .cancelled, .possible] {
            press.forcedState = state
            controller.perform(selector, with: press)
        }

        XCTAssertTrue(presenter.calls.isEmpty)
        XCTAssertEqual(controller.progressBar.stackView.arrangedSubviews.count, 3)
    }

    private func swipe(_ controller: StoriesViewController, selector: Selector, from start: CGPoint, to end: CGPoint) {
        let pan = CovCStoriesPan()
        pan.point = start
        pan.forcedState = .began
        controller.perform(selector, with: pan)
        pan.point = end
        pan.forcedState = .changed
        controller.perform(selector, with: pan)
        pan.forcedState = .ended
        controller.perform(selector, with: pan)
    }

    // MARK: - Progress bar

    func testProgressBarSegmentsAndTimerCallbacks() {
        let bar = StoriesProgressBar(frame: CGRect(x: 0, y: 0, width: 300, height: 10))
        let source = CovCStoriesProgressSource()
        bar.dataSource = source
        bar.delegate = source
        bar.padding = 4
        XCTAssertEqual(bar.padding, 4)

        bar.redrawSegments(startingPosition: 1)
        bar.layoutIfNeeded()
        XCTAssertEqual(bar.stackView.arrangedSubviews.count, 3)
        XCTAssertEqual(bar.currentIndex, 1)

        bar.setCurrentSegment(newIndex: 2)
        XCTAssertEqual(bar.currentIndex, 2)
        bar.setCurrentSegment(newIndex: 0)
        XCTAssertEqual(bar.currentIndex, 0)
        bar.setCurrentSegment(newIndex: 7)
        XCTAssertEqual(bar.currentIndex, 0, "out of range index is ignored")

        bar.didStart(with: 5)
        bar.didCountdown(remainedInterval: 4)
        bar.didStop(with: 0)
        XCTAssertEqual(source.finished, 1, "an expired segment reports the end of its animation")

        bar.pause()
        bar.didStart(with: 3)
        bar.didStop(with: 2)
        XCTAssertEqual(source.finished, 2)

        bar.pause()
        bar.didStop(with: 2)
        bar.resume()
        bar.didStart(with: 2)
        bar.stop()
        bar.didStop(with: 1)
        XCTAssertEqual(source.finished, 2, "an interrupted segment does not report completion")

        source.segments = 0
        bar.redrawSegments(startingPosition: 0)
        XCTAssertTrue(bar.stackView.arrangedSubviews.isEmpty)
        bar.prepareForInterfaceBuilder()
        XCTAssertEqual(bar.backgroundColor, .clear)
    }

    func testProgressViewPauseResumeStop() {
        let progress = ProgressView(frame: CGRect(x: 0, y: 0, width: 100, height: 2))
        progress.animationDuration = 1
        progress.setProgress(1, animated: true)
        let layer = progress.layer.sublayers?.last

        progress.pause()
        XCTAssertEqual(layer?.speed, 0)
        progress.resume()
        XCTAssertEqual(layer?.speed, 1)
        XCTAssertEqual(layer?.timeOffset, 0)
        progress.stop()
        XCTAssertNil(layer?.animationKeys())

        let empty = UIView()
        XCTAssertNil(empty.layer.sublayers)
    }
}
