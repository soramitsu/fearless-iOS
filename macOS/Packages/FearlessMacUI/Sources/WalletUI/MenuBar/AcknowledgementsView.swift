import DesignSystem
import SwiftUI

/// Credits for what the app bundles, with the licence text of the fonts.
struct AcknowledgementsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    CrestBadge(size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fearless Wallet")
                            .font(.brandDisplay(20, weight: .bold))
                        Text("Open source under the Apache License 2.0.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Figtree").font(.headline)
                    Text("Headings are set in Figtree by Erik Kennedy, used under the SIL Open Font License 1.1.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(BrandFont.licenceText ?? "The licence file is missing from this build.")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Network and token icons").font(.headline)
                    Text("Icons come from the Fearless Wallet chain catalog in this repository. The marks belong to their networks.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}
