import Foundation
import Testing
@testable import task_manager

struct ViceModelTests {
    @Test func viceValidationAndNormalization() {
        #expect(Vice(newName: "  ", unitLabel: "Hits") == nil)
        #expect(Vice(newName: "Dab Pen", unitLabel: " ") == nil)

        let vice = Vice(name: "  Dab Pen  ", unitLabel: "  Hits ")

        #expect(vice.name == "Dab Pen")
        #expect(vice.unitLabel == "Hits")
    }

    @Test func viceLogAmountIsAtLeastOne() {
        let viceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let log = ViceLog(
            viceID: viceID,
            timestamp: Date(timeIntervalSince1970: 100),
            amount: 0
        )

        #expect(log.amount == 1)
    }

    @Test func homeVicesSummaryTracksTodayCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 12))!
        let vice = Vice(name: "Dab Pen", unitLabel: "Hits")
        let todaysLog = ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-120))
        let oldLog = ViceLog(viceID: vice.id, timestamp: now.addingTimeInterval(-90_000))
        let summary = HomeVicesSummary(
            vices: [vice],
            logs: [todaysLog, oldLog],
            now: now,
            calendar: calendar
        )

        #expect(summary.activeViceCount == 1)
        #expect(summary.totalTodayCount == 1)
        #expect(summary.detail == "1 logged today")
    }
}
