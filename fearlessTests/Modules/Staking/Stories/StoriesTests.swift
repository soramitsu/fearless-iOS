import XCTest
@testable import fearless
import Cuckoo
import SoraFoundation

class StoriesTests: XCTestCase {
    func testSetup() {
        // given
        let view = MockStoriesViewProtocol()
        let wireframe = MockStoriesWireframeProtocol()

        let locale = LocalizationManager.shared.selectedLocale
        let model = StoriesFactory.createModel().value(for: locale)
        
        let interactor = StoriesInteractor(model: model)
        let selectedIndex = 2

        let storiesViewModelFactory = StoriesViewModelFactory()
        
        let presenter = StoriesPresenter(selectedStoryIndex: selectedIndex,
                                         viewModelFactory: storiesViewModelFactory)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        // when

        let viewModelExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didRecieve(viewModel: any(), startingFrom: any()).then { (viewModel: [SlideViewModel], starting) in
                XCTAssertEqual(viewModel[starting.index].content, model.stories[selectedIndex].slides[starting.index].description)
                viewModelExpectation.fulfill()
            }
        }

        interactor.setup()

        // then

        wait(for: [viewModelExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
