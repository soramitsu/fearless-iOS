import Foundation
import UIKit

public protocol DrawableIcon {
    func drawInContext(_ context: CGContext, fillColor: UIColor, size: CGSize)
}

public protocol IconGenerating {
    func generateFromAddress(_ address: String) throws -> DrawableIcon
}
