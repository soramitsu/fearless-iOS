import UIKit

public final class SoramitsuShimmerViewConfiguration<Type: SoramitsuShimmerView>: SoramitsuViewConfiguration<Type> {
    
    public enum Position {
        case diagonally
        case vertical
        case horizontal
    }
    
    public enum Direction {
        case direct
        case reverse
    }
    
    public var mainShimmerColor: SoramitsuColor = .custom(uiColor: .lightGray) {
        didSet {
            owner?.updateColors()
        }
    }
    
    public var secondShimmerColor: SoramitsuColor = .custom(uiColor: .white) {
        didSet {
            owner?.updateColors()
        }
    }
    
    public var position: Position = .diagonally {
        didSet {
            owner?.updateDirections()
        }
    }
    
    public var direction: Direction = .direct {
        didSet {
            owner?.updateDirections()
        }
    }
    
    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)
        
        if options.contains(.palette) {
            retrigger(self, \.mainShimmerColor)
            retrigger(self, \.secondShimmerColor)
        }
    }
    
    override func configureOwner() {
        super.configureOwner()
        
        retrigger(self, \.mainShimmerColor)
        retrigger(self, \.secondShimmerColor)
        retrigger(self, \.position)
        retrigger(self, \.direction)
    }
    
    func startShimmering() {
        owner?.startAnimation()
    }
    
    func stopShimmering() {
        owner?.stopAnimation()
    }
}
