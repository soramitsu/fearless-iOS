import XCTest
import UIKit
import SoraFoundation
@testable import fearless

final class CovJMxLanguageOutput: LanguageSelectionInteractorOutputProtocol {
    var languages: [[String]] = []
    var selected: [String] = []
    func didLoad(selectedLanguage: Language) { selected.append(selectedLanguage.code) }
    func didLoad(languages: [Language]) { self.languages.append(languages.map(\.code)) }
}

final class CovJMxLanguageInteractor: LanguageSelectionInteractorInputProtocol {
    var loads = 0
    var selections: [String] = []
    var accepts = true
    func load() { loads += 1 }
    func select(language: Language) -> Bool {
        selections.append(language.code)
        return accepts
    }
}

final class CovJMxLanguageWireframe: LanguageSelectionWireframeProtocol {
    var proceeds = 0
    func proceed(from _: LanguageSelectionViewProtocol?) { proceeds += 1 }
}

final class CovJMxLanguageView: UIViewController, LanguageSelectionViewProtocol {
    var reloads = 0
    func didReload() { reloads += 1 }
    func bind(viewModel _: TextSearchViewModel?) {}
}

final class CovJMxLanguageSelectionTests: XCTestCase {
    func testInteractorLoadsAvailableLanguagesAndSwitchesOnlyToANewOne() throws {
        let manager = try XCTUnwrap(LocalizationManager(localization: "en", availableLocalizations: ["en", "ja", "ru"]))
        let interactor = LanguageSelectionInteractor(localizationManager: manager)
        let output = CovJMxLanguageOutput()
        interactor.presenter = output

        interactor.load()
        XCTAssertEqual(output.languages, [["en", "ja", "ru"]])
        XCTAssertEqual(output.selected, ["en"])

        XCTAssertTrue(interactor.select(language: Language(code: "ja")))
        XCTAssertEqual(manager.selectedLocalization, "ja")
        XCTAssertEqual(output.selected, ["en", "ja"])

        XCTAssertFalse(interactor.select(language: Language(code: "ja")))
        XCTAssertEqual(output.selected, ["en", "ja"])
    }

    func testPresenterBuildsTitlesInTheCurrentLanguageAndSubtitlesInTheirOwn() throws {
        let (presenter, view, interactor, _) = try makePresenter()

        presenter.setup()
        XCTAssertEqual(interactor.loads, 1)

        presenter.didLoad(languages: [Language(code: "en"), Language(code: "ja"), Language(code: "pt-PT")])
        presenter.didLoad(selectedLanguage: Language(code: "ja"))

        XCTAssertEqual(view.reloads, 1)
        XCTAssertEqual(presenter.numberOfItems, 3)
        let items = try (0 ..< 3).map { try XCTUnwrap(presenter.item(at: $0) as? SelectableSubtitleListViewModel) }
        let english = Locale(identifier: "en")
        XCTAssertEqual(items[0].title, english.localizedString(forLanguageCode: "en")?.capitalized)
        XCTAssertEqual(items[1].title, english.localizedString(forLanguageCode: "ja")?.capitalized)
        XCTAssertEqual(items[1].subtitle, Locale(identifier: "ja").localizedString(forLanguageCode: "ja")?.capitalized)
        let portuguese = try XCTUnwrap(english.localizedString(forLanguageCode: "pt")?.capitalized)
        let portugal = try XCTUnwrap(english.localizedString(forRegionCode: "PT"))
        XCTAssertEqual(items[2].title, "\(portuguese) (\(portugal))")
        XCTAssertEqual(items.map(\.isSelected), [false, true, false])

        presenter.didLoad(selectedLanguage: Language(code: "en"))
        XCTAssertEqual(items.map(\.isSelected), [true, false, false])
    }

    func testSelectingProceedsOnlyWhenTheLanguageChanged() throws {
        let (presenter, _, interactor, wireframe) = try makePresenter()
        presenter.didLoad(languages: [Language(code: "en"), Language(code: "ja")])

        presenter.selectItem(at: 1)
        interactor.accepts = false
        presenter.selectItem(at: 0)

        XCTAssertEqual(interactor.selections, ["ja", "en"])
        XCTAssertEqual(wireframe.proceeds, 1)
    }

    func testLocalizationRebuildsOnlyALoadedViewAndWithoutManagerTitlesAreEmpty() throws {
        let (presenter, view, _, _) = try makePresenter()
        presenter.didLoad(languages: [Language(code: "en")])
        XCTAssertEqual(view.reloads, 1)

        presenter.applyLocalization()
        XCTAssertEqual(view.reloads, 1)

        view.loadViewIfNeeded()
        presenter.applyLocalization()
        XCTAssertEqual(view.reloads, 2)

        let bare = LanguageSelectionPresenter()
        bare.didLoad(languages: [Language(code: "ja")])
        let item = try XCTUnwrap(bare.item(at: 0) as? SelectableSubtitleListViewModel)
        XCTAssertEqual(item.title, "")
        XCTAssertEqual(item.subtitle, Locale(identifier: "ja").localizedString(forLanguageCode: "ja")?.capitalized)
    }

    func testFactoryBuildsAListOfEveryAvailableLanguage() throws {
        let view = try XCTUnwrap(LanguageSelectionViewFactory.createView())
        let controller = try XCTUnwrap(view as? LanguageSelectionViewController)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let shared = LocalizationManager.shared

        XCTAssertEqual(controller.title, R.string.localizable.languageTitle(preferredLanguages: shared.preferredLocalizations))
        XCTAssertTrue(controller.presenter is LanguageSelectionPresenter)
        XCTAssertEqual(controller.presenter.numberOfItems, shared.availableLocalizations.count)
        XCTAssertEqual(controller.tableView(controller.tableView, numberOfRowsInSection: 0), shared.availableLocalizations.count)
        let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(cell is SelectionSubtitleTableViewCell)

        controller.applyLocalization()
        XCTAssertEqual(controller.title, R.string.localizable.languageTitle(preferredLanguages: shared.preferredLocalizations))
    }

    func testWireframeNeedsANavigationStackToProceed() {
        let view = CovJMxLanguageView()
        let wireframe = LanguageSelectionWireframe()

        wireframe.proceed(from: nil)
        wireframe.proceed(from: view)

        XCTAssertNil(view.navigationController)
        XCTAssertNil(view.presentedViewController)
    }

    private func makePresenter() throws -> (
        LanguageSelectionPresenter, CovJMxLanguageView, CovJMxLanguageInteractor, CovJMxLanguageWireframe
    ) {
        let presenter = LanguageSelectionPresenter()
        let view = CovJMxLanguageView()
        let interactor = CovJMxLanguageInteractor()
        let wireframe = CovJMxLanguageWireframe()
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        presenter.localizationManager = try XCTUnwrap(LocalizationManager(localization: "en"))
        return (presenter, view, interactor, wireframe)
    }
}
