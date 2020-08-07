protocol AccountImportViewProtocol: class {}

protocol AccountImportPresenterProtocol: class {
    func setup()
}

protocol AccountImportInteractorInputProtocol: class {}

protocol AccountImportInteractorOutputProtocol: class {}

protocol AccountImportWireframeProtocol: class {}

protocol AccountImportViewFactoryProtocol: class {
	static func createView() -> AccountImportViewProtocol?
}