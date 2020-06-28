import Foundation

enum NavigationBarSeparatorStyle {
    case dark
    case light
    case empty
}

protocol DesignableNavigationBarProtocol {
    var separatorStyle: NavigationBarSeparatorStyle { get }
}
