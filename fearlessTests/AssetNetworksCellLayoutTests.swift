import XCTest
@testable import fearless

/// The asset networks row is 80 pt high and its background is inset 4 pt top and bottom (72 pt). The network icon
/// asked for 48 pt plus 16 pt above and below (80 pt), so Auto Layout broke one of those constraints on every row and
/// the icon ended up squeezed or off centre.
final class AssetNetworksCellLayoutTests: XCTestCase {
    func testTheIconKeepsItsSizeCentredInTheRowBackground() {
        let cell = AssetNetworksTableCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 358, height: 80)
        cell.contentView.frame = cell.bounds
        cell.layoutIfNeeded()

        let background = cell.triangularedBackgroundView
        let icon = cell.networkIconImageView
        XCTAssertEqual(background.frame.height, 72, accuracy: 0.5)
        XCTAssertEqual(icon.frame.width, 48, accuracy: 0.5)
        XCTAssertEqual(icon.frame.height, 48, accuracy: 0.5)
        XCTAssertEqual(icon.frame.midY, background.bounds.midY, accuracy: 0.5)
        XCTAssertEqual(icon.frame.minX, 8, accuracy: 0.5)
    }
}
