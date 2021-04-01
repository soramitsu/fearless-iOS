import Foundation

protocol StoriesFactoryProtocol {
    static func createModel() -> StoriesModel
}

final class StoriesFactory { }

extension StoriesFactory: StoriesFactoryProtocol {
    static func createModel() -> StoriesModel {

        // swiftlint:disable line_length
        let slides1 = [
            StorySlide(description: "Staking refers to the process of a Proof-of-Stake (PoS) token-holder locking a tokens in order to participate in the upkeep of the PoS network (e.g. validating transactions; composing new blocks). This increases the security and reliability of the network and is an alternative to mining in Proof-of-Work systems (e.g. Bitcoin). Token-holders who participate in staking are compensated through block rewards and transaction fees.",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-staking"),

            StorySlide(description:
                   "The staking system pays out rewards essentially equally to all validators regardless of stake. Having more stake on a validator does not influence the amount of block rewards it receives. However, there is a probabilistic component to reward calculation (discussed below), so rewards may not be exactly equal for all validators in a given era.",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-staking")
        ]

        let slides2 = [
            StorySlide(description: "Nominators secure the Relay Chain by selecting good validators and staking DOT. You may have an account with DOT and want to earn fresh DOT. You could do so as validator, which requires a node running 24/7. If you do not have such node or do not want to bother, you can still earn DOT by nominating one or more validators. By doing so, you become a nominator for the validator(s) of your choice. Pick your validators carefully - if they do not behave properly, they will get slashed and you will lose DOT as well. However, if they do follow the rules of the network, then you can share in staking rewards that they generate. ",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-nominator")
        ]

        let slides3 = [
            StorySlide(description: "Validators secure the Relay Chain by staking DOT, validating proofs from collators and participating in consensus with other validators. These participants will play a crucial role in adding new blocks to the Relay Chain and, by extension, to all parachains. This allows parties to complete cross-chain transactions via the Relay Chain.",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-validator"),

            StorySlide(description: "Validators perform two functions. First, verifying that the information contained in an assigned set of parachain blocks is valid (such as the identities of the transacting parties and the subject matter of the contract). Their second role is to participate in the consensus mechanism to produce the Relay Chain blocks based on validity statements from other validators. Any instances of non-compliance with the consensus algorithms result in punishment by removal of some or all of the validator’s staked DOT, thereby discouraging bad actors.",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-validator"),

            StorySlide(description: "Good performance, however, will be rewarded, with validators receiving block rewards (including transaction fees) in the form of DOT in exchange for their activities.",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-validator")
        ]

        let slides4 = [
            StorySlide(description: "Polkadot stores up to 84 eras of reward info like maps of era number to validator points, inflationary rewards, and nomination exposures. Rewards will not be claimable more than 84 eras after they were earned. This means that all rewards must be claimed within 84 eras.",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-simple-payouts"),

            StorySlide(description: "Anyone can trigger a payout for any validator, as long as they are willing to pay the transaction fee. Someone must submit a transaction with a validator ID and an era index. Polkadot will automatically calculate that validator's reward, find the top 128 nominators for that era, and distribute the rewards pro rata.",
                  urlString: "https://wiki.polkadot.network/docs/en/learn-simple-payouts")
        ]
        // swiftlint:enable line_length

        let story1 = Story(icon: "💰", title: "What is Staking?", slides: slides1)
        let story2 = Story(icon: "💎", title: "Who is Nominator?", slides: slides2)
        let story3 = Story(icon: "⛏", title: "Who is Validator?", slides: slides3)
        let story4 = Story(icon: "🎁", title: "Claiming Rewards", slides: slides4)

        return StoriesModel(stories: [story1, story2, story3, story4])
    }
}
