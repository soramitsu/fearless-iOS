import DesignSystem
import SwiftUI
import WalletCore

/// Every scene of Fearless Wallet for macOS: the main window, Settings, the
/// optional menu bar extra, the acknowledgements window and the menu
/// commands. The app target creates it with the wallet services:
///
///     FearlessScenes(services: services)
public struct FearlessScenes: Scene {
    /// Identifier of the main window, for `openWindow(id:)`.
    public static let mainWindowID = "main"
    static let acknowledgementsWindowID = "acknowledgements"

    @State private var store: SceneModelStore

    /// Creating the scenes is free of side effects: the app model (which
    /// reads UserDefaults) is built once, when the first scene needs it.
    /// SwiftUI calls this initializer again whenever the app's body is
    /// re-evaluated; building a model each time made launch loop.
    public init(services: WalletServices) {
        _store = State(initialValue: SceneModelStore { AppModel(services: services) })
    }

    /// For the demo and tests: scenes over an existing model.
    public init(model: AppModel) {
        _store = State(initialValue: SceneModelStore { model })
    }

    private var app: AppModel { store.model }

    public var body: some Scene {
        Window("Fearless Wallet", id: Self.mainWindowID) {
            RootView(app: app)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { app.start() }
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            FearlessCommands(app: app)
        }

        Settings {
            SettingsView(app: app)
        }

        MenuBarExtra(isInserted: menuBarExtraInserted) {
            MenuBarPanel(app: app)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Window("Acknowledgements", id: Self.acknowledgementsWindowID) {
            AcknowledgementsView()
        }
        .defaultSize(width: 560, height: 520)
        .windowResizability(.contentSize)
    }

    private var menuBarExtraInserted: Binding<Bool> {
        let settings = app.settings
        return Binding(
            get: { settings.menuBarExtraEnabled },
            set: { settings.menuBarExtraEnabled = $0 }
        )
    }
}

/// Holds the app model for the scenes and builds it on first use.
@MainActor
final class SceneModelStore {
    private let make: () -> AppModel
    private var built: AppModel?

    init(make: @escaping () -> AppModel) {
        self.make = make
    }

    var model: AppModel {
        if let built { return built }
        let model = make()
        built = model
        return model
    }
}
