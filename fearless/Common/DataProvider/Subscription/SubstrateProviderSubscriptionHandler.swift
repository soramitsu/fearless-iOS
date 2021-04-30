import Foundation

protocol SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>)
}

extension SubstrateProviderSubscriptionHandler {
    func handleStashItem(result _: Result<StashItem?, Error>) {}
}
