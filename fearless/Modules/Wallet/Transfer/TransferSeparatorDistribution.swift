import Foundation
import CommonWallet
import SoraUI

struct TransferSeparatorDistribution: OperationDefinitionSeparatorsDistributionProtocol {
    var assetBorderType: BorderType { .none }

    var receiverBorderType: BorderType { .none }

    var amountWithFeeBorderType: BorderType { .none }

    var amountWithoutFeeBorderType: BorderType { .none }

    var firstFeeBorderType: BorderType { .bottom }

    var middleFeeBorderType: BorderType { .bottom }

    var lastFeeBorderType: BorderType { .bottom }

    var singleFeeBorderType: BorderType { .bottom }

    var descriptionBorderType: BorderType { .none }
}
