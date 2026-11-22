import SwiftUI

/// The one way a moment is shown in a list or a detail: `2026-03-05 23:14:59`,
/// in local time. Where a row is narrow the date and the time stack
/// (`DateStampText(…, twoRows: true)`).
enum DateStamp {
    static func day(_ date: Date) -> String { dayFormat.string(from: date) }
    static func time(_ date: Date) -> String { timeFormat.string(from: date) }
    static func full(_ date: Date) -> String { day(date) + " " + time(date) }

    /// Seconds since 1970, as the chain records carry them.
    static func full(seconds: some BinaryInteger) -> String {
        full(Date(timeIntervalSince1970: TimeInterval(seconds)))
    }

    /// Milliseconds since 1970, as chat and the servers carry them.
    static func full(millis: some BinaryInteger) -> String {
        full(Date(timeIntervalSince1970: Double(millis) / 1000))
    }

    private static let dayFormat = fixed("yyyy-MM-dd")
    private static let timeFormat = fixed("HH:mm:ss")

    private static func fixed(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }
}

/// A `DateStamp` as text, on one row or with the time under the date.
struct DateStampText: View {
    let date: Date
    var twoRows = false
    /// Which edge the two rows line up on: trailing at the end of a list
    /// row, leading in a detail sheet's field.
    var alignment: HorizontalAlignment = .trailing

    init(_ date: Date, twoRows: Bool = false, alignment: HorizontalAlignment = .trailing) {
        self.date = date
        self.twoRows = twoRows
        self.alignment = alignment
    }

    init(seconds: some BinaryInteger, twoRows: Bool = false, alignment: HorizontalAlignment = .trailing) {
        self.init(Date(timeIntervalSince1970: TimeInterval(seconds)), twoRows: twoRows, alignment: alignment)
    }

    init(millis: some BinaryInteger, twoRows: Bool = false, alignment: HorizontalAlignment = .trailing) {
        self.init(Date(timeIntervalSince1970: Double(millis) / 1000), twoRows: twoRows, alignment: alignment)
    }

    var body: some View {
        if twoRows {
            VStack(alignment: alignment, spacing: 0) {
                Text(DateStamp.day(date))
                Text(DateStamp.time(date))
            }
            .monospacedDigit()
        } else {
            Text(DateStamp.full(date)).monospacedDigit()
        }
    }
}
