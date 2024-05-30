import Foundation
import UIKit

public protocol AccessoryViewModelProtocol {
    var title: String { get }
    var icon: UIImage? { get }
    var action: String { get }
    var numberOfLines: Int { get }
    var shouldAllowAction: Bool { get }
}

public struct AccessoryViewModel: AccessoryViewModelProtocol {
    public var title: String
    public var icon: UIImage?
    public var action: String
    public var numberOfLines: Int
    public var shouldAllowAction: Bool

    public init(
        title: String,
        action: String,
        icon: UIImage? = nil,
        numberOfLines: Int = 1,
        shouldAllowAction: Bool = true
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.numberOfLines = numberOfLines
        self.shouldAllowAction = shouldAllowAction
    }
}
