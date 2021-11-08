import Foundation
import FearlessUtils

class MoonbeamContributionSetupInteractor: CrowdloanContributionSetupInteractor {
    override func makeMemoCall(memo: String?) -> RuntimeCall<CrowdloanAddMemo>? {
        guard let memo = memo, !memo.isEmpty,
              let memoData = try? Data(hexString: memo.lowercased()),
              self.settings.referralEthereumAddressForSelectedAccount() != memo
        else {
            return nil
        }

        return callFactory.addMemo(to: paraId, memo: memoData)
    }

    override func fetchReferralAccountAddress() {
        if let referralEthereumAccountAddress = settings.referralEthereumAddressForSelectedAccount() {
            presenter.didReceiveReferralEthereumAddress(address: referralEthereumAccountAddress)
        }
    }
}
