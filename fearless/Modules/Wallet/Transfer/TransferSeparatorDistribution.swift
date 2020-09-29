import Foundation
import CommonWallet
import SoraUI

struct TransferSeparatorDistribution: OperationDefinitionSeparatorsDistributionProtocol {
    var assetBorderType: BorderType { .bottom }

    var receiverBorderType: BorderType { .bottom }

    var amountWithFeeBorderType: BorderType { .none }

    var amountWithoutFeeBorderType: BorderType { .bottom }

    var firstFeeBorderType: BorderType { .bottom }

    var middleFeeBorderType: BorderType { .bottom }

    var lastFeeBorderType: BorderType { .bottom }

    var singleFeeBorderType: BorderType { .bottom }

    var descriptionBorderType: BorderType { .none }
}
