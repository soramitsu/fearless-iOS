import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol TimeFormatterProtocol {
    func string(from timeInterval: TimeInterval) throws -> String
}

public struct MinuteSecondFormatter: TimeFormatterProtocol {

    public init() {}

    public func string(from timeInterval: TimeInterval) throws -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60

        let minutesString = minutes < 10 ? "0\(minutes)" : String(minutes)
        let secondsString = seconds < 10 ? "0\(seconds)" : String(seconds)

        return "\(minutesString):\(secondsString)"
    }
}

public struct HourMinuteFormatter: TimeFormatterProtocol {

    public init() {}

    public func string(from timeInterval: TimeInterval) throws -> String {
        var currentInterval = Int(timeInterval)

        let hours = currentInterval / 3600

        currentInterval = currentInterval % 3600

        let minutes = currentInterval / 60

        let hoursString = hours < 10 ? "0\(hours)" : String(hours)
        let minutesString = minutes < 10 ? "0\(minutes)" : String(minutes)

        return "\(hoursString):\(minutesString)"
    }
}

public struct TotalTimeFormatter: TimeFormatterProtocol {

    public init() {}

    public func string(from timeInterval: TimeInterval) throws -> String {
        var timeComponents: [Int] = []

        var currentInterval = Int(timeInterval)

        let hours = currentInterval / 3600
        timeComponents.append(hours)

        currentInterval = currentInterval % 3600

        let minutes = currentInterval / 60
        timeComponents.append(minutes)

        let seconds = currentInterval % 60
        timeComponents.append(seconds)

        let timeComponentStrings: [String] = timeComponents.map { component in
            if component < 10 {
                return "0\(component)"
            } else {
                return "\(component)"
            }
        }

        return timeComponentStrings.joined(separator: ":")
    }
}
