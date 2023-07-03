import Foundation

enum ContentVerticalAlignment {
    case top
    case center
    case bottom
}

enum ContentHorizontalAlignment {
    case left
    case center
    case right
}

struct ContentAlignment {
    let vertical: ContentVerticalAlignment
    let horizontal: ContentHorizontalAlignment

    init(
        vertical: ContentVerticalAlignment = .top,
        horizontal: ContentHorizontalAlignment = .left
    ) {
        self.vertical = vertical
        self.horizontal = horizontal
    }
}
