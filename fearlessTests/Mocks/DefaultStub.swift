import Foundation
@testable import fearless
import Cuckoo
import RobinHood

extension MockEventCenterProtocol {
    func applyingDefaultStub() -> MockEventCenterProtocol {
        stub(self) { stub in
            stub.add(observer: any(), dispatchIn: any()).thenDoNothing()
            stub.notify(with: any()).thenDoNothing()
            stub.remove(observer: any()).thenDoNothing()
        }

        return self
    }
}

extension MockCrowdloanRemoteSubscriptionServiceProtocol {
    func applyDefaultStub() -> MockCrowdloanRemoteSubscriptionServiceProtocol {
        stub(self) { stub in
            stub.attach(
                for: any(),
                runningCompletionIn: any(),
                completion: any()
            ).then { chainId, maybeQueue, maybeClosure in

                if let closure = maybeClosure {
                    let queue = maybeQueue ?? DispatchQueue.main

                    queue.async {
                        closure(.success(()))
                    }
                }

                return UUID()
            }

            stub.detach(
                for: any(),
                chainId: any(),
                runningCompletionIn: any(),
                completion: any()).then { subscriptionId, chainId, maybeQueue, maybeClosure in
                    if let closure = maybeClosure {
                        let queue = maybeQueue ?? DispatchQueue.main

                        queue.async {
                            closure(.success(()))
                        }
                    }
                }
        }

        return self
    }
}

extension MockRuntimeProviderProtocol {
    func applyDefault(for chainId: ChainModel.Id) -> MockRuntimeProviderProtocol {
        let codingFactory = try! RuntimeCodingServiceStub.createWestendCodingFactory(
            specVersion: 9010,
            txVersion: 5
        )

        stub(self) { stub in
            stub.fetchCoderFactoryOperation().then {
                BaseOperation.createWithResult(codingFactory)
            }

            stub.chainId.get.thenReturn(chainId)

            stub.cleanup().thenDoNothing()
            stub.setup().thenDoNothing()
            stub.replaceTypesUsage(any()).thenDoNothing()
        }

        return self
    }
}

extension MockStakingRemoteSubscriptionServiceProtocol {
    func applyDefault() -> MockStakingRemoteSubscriptionServiceProtocol {
        stub(self) { stub in
            stub.attachToGlobalData(
                for: any(),
                queue: any(),
                closure: any()
            ).then { chainId, maybeQueue, maybeClosure in

                if let closure = maybeClosure {
                    let queue = maybeQueue ?? DispatchQueue.main

                    queue.async {
                        closure(.success(()))
                    }
                }

                return UUID()
            }

            stub.detachFromGlobalData(
                for: any(),
                chainId: any(),
                queue: any(),
                closure: any()
            ).then { subscriptionId, chainId, maybeQueue, maybeClosure in
                if let closure = maybeClosure {
                    let queue = maybeQueue ?? DispatchQueue.main

                    queue.async {
                        closure(.success(()))
                    }
                }
            }
        }

        return self
    }
}

extension MockStakingAccountUpdatingServiceProtocol {
    func applyDefault() -> MockStakingAccountUpdatingServiceProtocol {
        stub(self) { stub in
            stub.setupSubscription(for: any(), chainId: any(), chainFormat: any()).thenDoNothing()
            stub.clearSubscription().thenDoNothing()
        }

        return self
    }
}
