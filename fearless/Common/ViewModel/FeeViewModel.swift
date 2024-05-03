import Foundation

public protocol FeeViewModelProtocol {
    var title: String { get }
    var details: String { get }
    var isLoading: Bool { get }
    var allowsEditing: Bool { get }
}

public struct FeeViewModel: FeeViewModelProtocol {
    public let title: String
    public let details: String
    public let isLoading: Bool
    public let allowsEditing: Bool

    public init(title: String, details: String, isLoading: Bool, allowsEditing: Bool) {
        self.title = title
        self.details = details
        self.isLoading = isLoading
        self.allowsEditing = allowsEditing
    }
}
