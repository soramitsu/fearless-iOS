import UIKit

/// The wallet home's page (iPhone, and the iPad column): the wallet header and, below it, the asset list scroll as
/// one page, so no part of the header ever rests under the list, whatever the text size. The list keeps its own
/// scrolling: a drag on it first scrolls the header away and then the list's rows; back down, the list returns to its
/// top first and then the header comes back.
final class WalletHomePageScrollView: UIScrollView, UIGestureRecognizerDelegate {
    /// The list that scrolls inside the page. Its drags also move the page.
    weak var nestedScrollView: UIScrollView?

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === panGestureRecognizer
            && otherGestureRecognizer === nestedScrollView?.panGestureRecognizer
    }
}

/// Which of the two scroll positions may move. One drag moves both scroll views, so after every move one of them is
/// held where it was.
enum WalletHomeScrollChain {
    struct Offsets: Equatable {
        /// How far the header has scrolled away: 0 shows all of it, `pageMax` none of it.
        var page: CGFloat
        /// How far the list has scrolled from its top; negative while it is pulled down (pull to refresh).
        var list: CGFloat
    }

    enum Move {
        /// The page moved: a drag (on the header or the list) or its deceleration.
        case page
        /// The list moved under a finger or while decelerating.
        case list
        /// The list was scrolled by the app (for example to show a row).
        case listProgrammatically
    }

    private static let tolerance: CGFloat = 0.5

    static func resolve(_ offsets: Offsets, pageMax: CGFloat, moved: Move) -> Offsets {
        var resolved = offsets
        let headerShown = offsets.page < pageMax - tolerance
        switch moved {
        case .page:
            // The list is in its rows: the header waits until the list is back at its top.
            if offsets.list > tolerance, headerShown {
                resolved.page = pageMax
            }
        case .list:
            if offsets.list > tolerance, headerShown {
                // The header is still on screen: the page scrolls, the list stays at its top.
                resolved.list = 0
            } else if offsets.list < -tolerance, offsets.page > tolerance {
                // Pulling down with the header away: the page brings the header back; pull to refresh waits for it.
                resolved.list = 0
            }
        case .listProgrammatically:
            // Rows the app scrolled to are shown: the header makes way.
            if offsets.list > tolerance, headerShown {
                resolved.page = pageMax
            }
        }
        return resolved
    }

    enum ScrollToTopTarget: Equatable {
        case page
        case list
    }

    /// Which of the two takes the status-bar tap. UIKit offers the tap only to a scroll view that can still move up
    /// (and prefers an inner one), so exactly one of them may take it. The page does whenever it has scrolled: its
    /// request brings the list to its top first. Only while the page rests at its top above scrolled rows (folded for
    /// a search, the page cannot scroll) does the list take it.
    static func scrollToTopTarget(_ offsets: Offsets) -> ScrollToTopTarget {
        offsets.page <= tolerance && offsets.list > tolerance ? .list : .page
    }
}

/// A page of the wallet home that can change the list it scrolls (an empty state over the list, another appearance)
/// without a layout pass of the home, which follows the list on screen for the scroll chain and the status-bar tap.
protocol WalletHomeListChanging: AnyObject {
    var onListChange: (() -> Void)? { get set }
}
