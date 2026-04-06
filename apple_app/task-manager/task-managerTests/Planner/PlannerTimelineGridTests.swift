import CoreGraphics
import Foundation
import Testing
@testable import task_manager

struct PlannerTimelineGridTests {
    private let calendar = makeUTCGregorianCalendar()
    private let day = Date(timeIntervalSince1970: 1_710_000_000)
    private let metrics = PlannerDayTimelineMetrics()

    @Test func slotIndexRoundsDownToQuarterHour() {
        let date = calendar.date(
            bySettingHour: 9,
            minute: 37,
            second: 42,
            of: calendar.startOfDay(for: day)
        )!

        let slotIndex = PlannerTimelineGrid.slotIndex(
            for: date,
            on: day,
            calendar: calendar
        )

        #expect(slotIndex == 38)
    }

    @Test func singleSlotSelectionCreatesQuarterHourRange() throws {
        let selection = PlannerTimelineGrid.selectedRange(
            anchorSlotIndex: 20,
            currentSlotIndex: 20,
            on: day,
            calendar: calendar
        )

        let start = calendar.date(
            bySettingHour: 5,
            minute: 0,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!
        let end = calendar.date(
            bySettingHour: 5,
            minute: 15,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!

        let expectedSelection = try #require(PlannerSelectedTimeRange(start: start, end: end))
        #expect(selection == expectedSelection)
    }

    @Test func dragSelectionExpandsAcrossQuarterHourSlots() throws {
        let selection = PlannerTimelineGrid.selectedRange(
            anchorSlotIndex: 41,
            currentSlotIndex: 45,
            on: day,
            calendar: calendar
        )

        let start = calendar.date(
            bySettingHour: 10,
            minute: 15,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!
        let end = calendar.date(
            bySettingHour: 11,
            minute: 30,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!

        let expectedSelection = try #require(PlannerSelectedTimeRange(start: start, end: end))
        #expect(selection == expectedSelection)
    }

    @Test func clickLocationConvertsToExpectedQuarterHourSelection() throws {
        let size = CGSize(width: 320, height: metrics.totalHeight)
        let point = CGPoint(
            x: metrics.contentStartX + 24,
            y: metrics.topInset + metrics.slotHeight * 10 + 1
        )

        let selection = try #require(
            PlannerTimelineGrid.selectedRange(
                anchorPoint: point,
                currentPoint: point,
                in: size,
                metrics: metrics,
                day: day,
                calendar: calendar,
                occupiedIntervals: []
            )
        )

        let expectedStart = calendar.date(
            bySettingHour: 2,
            minute: 30,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!
        let expectedEnd = calendar.date(
            bySettingHour: 2,
            minute: 45,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!

        let expectedSelection = try #require(
            PlannerSelectedTimeRange(start: expectedStart, end: expectedEnd)
        )
        #expect(selection == expectedSelection)
    }

    @Test func occupiedIntervalsPreventSelectionOnBusyTime() {
        let size = CGSize(width: 320, height: metrics.totalHeight)
        let point = CGPoint(
            x: metrics.contentStartX + 18,
            y: metrics.topInset + metrics.slotHeight * 16 + 2
        )
        let busyStart = calendar.date(
            bySettingHour: 4,
            minute: 0,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!
        let busyEnd = calendar.date(
            bySettingHour: 4,
            minute: 30,
            second: 0,
            of: calendar.startOfDay(for: day)
        )!

        let selection = PlannerTimelineGrid.selectedRange(
            anchorPoint: point,
            currentPoint: point,
            in: size,
            metrics: metrics,
            day: day,
            calendar: calendar,
            occupiedIntervals: [DateInterval(start: busyStart, end: busyEnd)]
        )

        #expect(selection == nil)
    }
}

private func makeUTCGregorianCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}
