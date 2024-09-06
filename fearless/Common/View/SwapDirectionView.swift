import UIKit

final class SwapDirectionView: UIView {
    private let balancePriceView = BalancePriceHorizontalView()
    private let chainView = IconDetailsView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
