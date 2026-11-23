import Foundation
import WalletCore

/// The sections of the sidebar.
enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case portfolio
    case assets
    case activity
    case networks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portfolio: return "Portfolio"
        case .assets: return "Assets"
        case .activity: return "Activity"
        case .networks: return "Networks"
        }
    }

    var symbol: String {
        switch self {
        case .portfolio: return "chart.pie"
        case .assets: return "circle.hexagongrid"
        case .activity: return "clock.arrow.circlepath"
        case .networks: return "point.3.connected.trianglepath.dotted"
        }
    }
}

/// What the main window shows as a whole.
enum RootRoute: Equatable {
    case launching
    case onboarding
    case locked
    case main
}

/// A sheet over the main window.
enum SheetRoute: Identifiable {
    case send(SendModel)
    case receive(ReceiveModel)
    case addWallet(OnboardingModel)
    case backup(WalletsSettingsModel)

    var id: String {
        switch self {
        case .send(let model): return "send-\(model.id)"
        case .receive(let model): return "receive-\(model.id)"
        case .addWallet(let model): return "add-\(model.id)"
        case .backup: return "backup"
        }
    }
}

/// A short confirmation shown at the bottom of the window ("Address copied").
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let symbol: String
}
