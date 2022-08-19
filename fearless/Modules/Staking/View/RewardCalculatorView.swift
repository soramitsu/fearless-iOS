import UIKit
import SoraUI

class StakingRewardCalculatorView: UIView {
     var backgroundView: TriangularedBlurView!
     var amountInputView: AmountInputView!

     var estimateWidgetTitleLabel: UILabel!

     var monthlyTitleLabel: UILabel!
     var monthlyAmountLabel: UILabel!
     var monthlyFiatAmountLabel: UILabel!

    var yearlyTitleLabel: UILabel = {
        
    }()
     var yearlyAmountLabel: UILabel!
     var yearlyFiatAmountLabel: UILabel!

     private var infoButton: RoundedButton!
}
