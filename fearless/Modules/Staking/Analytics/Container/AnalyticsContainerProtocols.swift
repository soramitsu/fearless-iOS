import SoraFoundation

protocol AnalyticsEmbeddedViewProtocol: ControllerBackedProtocol {
    var localizedTitle: LocalizableResource<String> { get }
}

protocol AnalyticsContainerViewProtocol: ControllerBackedProtocol {
    var embeddedModules: [AnalyticsEmbeddedViewProtocol] { get }
}
