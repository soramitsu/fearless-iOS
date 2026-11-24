import UIKit
import XCTest
@testable import fearless

@MainActor
final class WalletTransactionDetailsTests: XCTestCase {
    func testTransferDetailsKeepAmountsReadableAndShowPendingSettledAndFailedStates() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.overrideUserInterfaceStyle = .dark
        let controller = UIViewController()
        let layout = WalletTransactionDetailsViewLayout()
        layout.locale = Locale(identifier: "en")
        layout.navigationTitleLabel.text = "Transfer details"
        controller.view = layout
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let cases: [(AssetTransactionStatus, FWTxStatusView.Status, String)] = [
            (.pending, .pending, "Pending"), (.commited, .success, "Completed"), (.rejected, .failed, "Failed")
        ]
        for (status, ring, title) in cases {
            let transaction = AssetTransactionData(
                transactionId: "synthetic-transfer", status: status, assetId: "ETH", peerId: "synthetic-peer",
                peerFirstName: nil, peerLastName: nil, peerName: nil, details: "",
                amount: AmountDecimal(value: 1.25), fees: [], timestamp: 1_793_836_800,
                type: TransactionType.outgoing.rawValue, reason: nil, context: nil
            )
            layout.bind(to: TransferTransactionDetailsViewModel(
                transaction: transaction, transactionType: .outgoing,
                extrinsicHash: "0x1234567890abcdef1234567890abcdef", status: title,
                dateString: "8 Nov 2026, 09:41", from: "0x1234567890abcdef1234567890abcdef12345678",
                to: "0xabcdef1234567890abcdef1234567890abcdef12",
                amount: "1.25 ETH", fee: "0.0001 ETH", total: "1.2501 ETH",
                statusIcon: UIImage(systemName: "circle")
            ))
            window.layoutIfNeeded()
            layout.layoutIfNeeded()
            XCTAssertEqual(layout.statusView.valueLabel.text, title)
            XCTAssertEqual(layout.sunlitParts.ring.status, ring)
            XCTAssertEqual(layout.amountView.valueLabel.text, "1.25 ETH")
            XCTAssertGreaterThanOrEqual(layout.amountView.valueLabel.textColor.cgColor.alpha, 0.9)
            XCTAssertEqual(layout.sunlitParts.ring.bounds.size, CGSize(width: 20, height: 20))
            XCTAssertTrue(layout.sunlitParts.card.bounds.contains(
                layout.sunlitParts.ring.convert(layout.sunlitParts.ring.bounds, to: layout.sunlitParts.card)
            ))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "sunlit-transfer-" + title.lowercased()
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
