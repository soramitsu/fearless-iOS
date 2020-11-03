protocol AccountExportPasswordViewProtocol: class {}

protocol AccountExportPasswordPresenterProtocol: class {
    func setup()
}

protocol AccountExportPasswordInteractorInputProtocol: class {}

protocol AccountExportPasswordInteractorOutputProtocol: class {}

protocol AccountExportPasswordWireframeProtocol: class {}

protocol AccountExportPasswordViewFactoryProtocol: class {
	static func createView() -> AccountExportPasswordViewProtocol?
}