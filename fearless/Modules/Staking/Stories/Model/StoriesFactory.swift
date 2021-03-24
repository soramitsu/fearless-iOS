import Foundation

protocol StoriesFactoryProtocol {
    static func createModel() -> StoriesModel
}

final class StoriesFactory { }

extension StoriesFactory: StoriesFactoryProtocol {
    static func createModel() -> StoriesModel {

        // swiftlint:disable line_length
        let slides1 = [
            Slide(id: 1,
                   title: "Yiran Ding",
                   description: "",
                   imageName: "1" ),

            Slide(id: 2,
                   title: "Chris Yang",
                   description:
                   "On August, I spent about two weeks in Iceland and Greenland. This glacier was the first astonishment as we arrived in Iceland. The first time in my life sitting so close to the glacier and touch the cold water. Not just cold but extremely freezing. Still, an unbelievably beautiful scenery with no doubt.",
                   imageName: "2")
        ]

        let slides2 = [
            Slide(id: 3,
                   title: "Kyle Johnson",
                   description: "Iceland ",
                   imageName: "3")
        ]

        let slides3 = [
            Slide(id: 4,
                   title: "Puneeth Shetty",
                   description: "A hiker with his dog. On top of Untersberg in Salzburg, Austria.",
                   buttonText: "Show photos with same theme",
                   buttonColor: .systemBlue,
                   buttonLink: URL(string: "https://unsplash.com/s/photos/arctic"),
                   imageName: "4"),

            Slide(id: 5,
                  title: "Madeline Pere",
                  description: "White Sands National Monument in New Mexico, USA has been on my wishlist for years. Seeing photographers take some of the most stunning images I have ever seen, I knew when I had the chance I had to visit.",
                  imageName: "5")
        ]

        let slides4 = [
            Slide(id: 6,
                  title: "Annie Spratt",
                  titleColor: .brown,
                  description: "Aerial (drone) view of Arctic Icebergs",
                  descColor: .brown,
                  imageName: "6")
        ]
        // swiftlint:enable line_length

        let story1 = Story(icon: "💰", title: "What is Staking?", slides: slides1)
        let story2 = Story(icon: "💎", title: "Who is Nominator?", slides: slides2)
        let story3 = Story(icon: "⛏", title: "Who is Validator?", slides: slides3)
        let story4 = Story(icon: "🎁", title: "What is Staking 2?", slides: slides4)

        return StoriesModel(stories: [story1, story2, story3, story4])
    }
}
