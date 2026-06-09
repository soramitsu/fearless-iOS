import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public typealias CompoundDateFormatterItemBlock = (Date) -> Bool

public protocol CompoundDateFormatterItemProtocol {
    var locale: Locale? { get set }
    func canApply(to date: Date) -> Bool
    func apply(to date: Date) -> String
}

public final class CompoundDateFormatterConstantItem: CompoundDateFormatterItemProtocol {
    public var locale: Locale?

    public private(set) var title: LocalizableResource<String>
    public private(set) var checkBlock: CompoundDateFormatterItemBlock

    public init(title: LocalizableResource<String>, checkBlock: @escaping CompoundDateFormatterItemBlock) {
        self.title = title
        self.checkBlock = checkBlock
    }

    public func canApply(to date: Date) -> Bool {
        return checkBlock(date)
    }

    public func apply(to date: Date) -> String {
        return title.value(for: locale ?? Locale.current)
    }
}

public final class CompoundDateFormatterItem: CompoundDateFormatterItemProtocol {
    public var locale: Locale?

    public let dateFormatter: LocalizableResource<DateFormatter>
    public let checkBlock: CompoundDateFormatterItemBlock

    public init(dateFormatter: LocalizableResource<DateFormatter>, checkBlock: @escaping CompoundDateFormatterItemBlock) {
        self.dateFormatter = dateFormatter
        self.checkBlock = checkBlock
    }

    public func canApply(to date: Date) -> Bool {
        return checkBlock(date)
    }

    public func apply(to date: Date) -> String {
        return dateFormatter.value(for: locale ?? Locale.current).string(from: date)
    }
}

public final class CompoundDateFormatter: DateFormatter, @unchecked Sendable {
    public private(set) var items: [CompoundDateFormatterItemProtocol] = []

    public init(items: [CompoundDateFormatterItemProtocol]) {
        self.items = items

        super.init()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override var locale: Locale! {
        didSet {
            for index in 0..<items.count {
                items[index].locale = locale
            }
        }
    }

    public override func string(from date: Date) -> String {
        for item in items {
            if item.canApply(to: date) {
                return item.apply(to: date)
            }
        }

        return super.string(from: date)
    }
}

public protocol CompoundDateFormatterBuilderProtocol {
    func withToday(title: LocalizableResource<String>) -> Self
    func withYesterday(title: LocalizableResource<String>) -> Self
    func withThisYear(dateFormatter: LocalizableResource<DateFormatter>) -> Self
    func build(defaultFormat: String?) -> CompoundDateFormatter
}

public final class CompoundDateFormatterBuilder: CompoundDateFormatterBuilderProtocol {
    public let baseDate: Date
    public let calendar: Calendar

    private var items: [CompoundDateFormatterItemProtocol] = []

    public init(baseDate: Date = Date(), calendar: Calendar = Calendar.current) {
        self.baseDate = baseDate
        self.calendar = calendar
    }

    public func withToday(title: LocalizableResource<String>) -> Self {
        let currentCalendar = calendar
        let baseBaseDate = baseDate

        let checkBlock: CompoundDateFormatterItemBlock = { (date) in
            return currentCalendar.compare(baseBaseDate, to: date, toGranularity: .day) == .orderedSame
        }

        let item = CompoundDateFormatterConstantItem(title: title,
                                                     checkBlock: checkBlock)
        items.append(item)

        return self
    }

    public func withYesterday(title: LocalizableResource<String>) -> Self {
        let currentCalendar = calendar
        let baseBaseDate = baseDate

        let checkBlock: CompoundDateFormatterItemBlock = { (date) in
            guard let nextDate = currentCalendar.date(byAdding: .day, value: 1, to: date) else {
                return false
            }

            return currentCalendar.compare(baseBaseDate, to: nextDate, toGranularity: .day) == .orderedSame
        }

        let item = CompoundDateFormatterConstantItem(title: title,
                                                     checkBlock: checkBlock)
        items.append(item)

        return self
    }

    public func withThisYear(dateFormatter: LocalizableResource<DateFormatter>) -> Self {
        let currentCalendar = calendar
        let baseYear = currentCalendar.component(.year, from: baseDate)

        let checkBlock: CompoundDateFormatterItemBlock = { (date) in
            let year = currentCalendar.component(.year, from: date)
            return baseYear == year
        }

        let item = CompoundDateFormatterItem(dateFormatter: dateFormatter,
                                             checkBlock: checkBlock)
        items.append(item)

        return self
    }

    public func build(defaultFormat: String?) -> CompoundDateFormatter {
        let formatter = CompoundDateFormatter(items: items)
        formatter.timeZone = calendar.timeZone

        if let dateFormat = defaultFormat {
            formatter.dateFormat = dateFormat
        }

        return formatter
    }
}
