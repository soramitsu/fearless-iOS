import Foundation
import RobinHood

extension StreamableProviderObserverOptions {
    static func substrateSource(for initSize: Int = 0) -> StreamableProviderObserverOptions {
        StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                          waitsInProgressSyncOnAdd: false,
                                          initialSize: initSize,
                                          refreshWhenEmpty: false)
    }
}
