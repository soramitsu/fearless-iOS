import Foundation
import SoraUI

/// Extension of the TriangularedView to support design through Interface Builder
extension TriangularedView {
    @IBInspectable
    private var _cornerCut: UInt8 {
        get {
            cornerCut.rawValue
        }

        set {
            cornerCut = TriangularedCorners(rawValue: newValue)
        }
    }
}
