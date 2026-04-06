import CoreGraphics
import Foundation

struct PlannerSelectedTimeRange: Equatable, Sendable {
    let start: Date
    let end: Date

    init?(
        start: Date,
        end: Date
    ) {
        guard end > start else {
            return nil
        }

        self.start = start
        self.end = end
    }

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

struct PlannerDayTimelineMetrics: Equatable, Sendable {
    let hourHeight: CGFloat
    let timeColumnWidth: CGFloat
    let contentLeadingInset: CGFloat
    let topInset: CGFloat
    let laneSpacing: CGFloat

    init(
        hourHeight: CGFloat = 56,
        timeColumnWidth: CGFloat = 52,
        contentLeadingInset: CGFloat = 12,
        topInset: CGFloat = 8,
        laneSpacing: CGFloat = 6
    ) {
        self.hourHeight = hourHeight
        self.timeColumnWidth = timeColumnWidth
        self.contentLeadingInset = contentLeadingInset
        self.topInset = topInset
        self.laneSpacing = laneSpacing
    }

    var slotHeight: CGFloat {
        hourHeight / CGFloat(PlannerTimelineGrid.slotsPerHour)
    }

    var timedAreaHeight: CGFloat {
        hourHeight * 24
    }

    var totalHeight: CGFloat {
        topInset + timedAreaHeight
    }

    var contentStartX: CGFloat {
        timeColumnWidth + contentLeadingInset
    }

    func containsAnchorPoint(
        _ point: CGPoint,
        in size: CGSize
    ) -> Bool {
        point.x >= contentStartX
            && point.x <= size.width
            && point.y >= topInset
            && point.y <= totalHeight
    }
}

enum PlannerTimelineGrid {
    static let slotMinutes = TaskDurationRules.minutesIncrement
    static let slotsPerHour = 60 / slotMinutes
    static let slotsPerDay = 24 * slotsPerHour

    static func slotIndex(
        for date: Date,
        on day: Date,
        calendar: Calendar
    ) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(86_400)

        if date <= dayStart {
            return 0
        }

        if date >= dayEnd {
            return slotsPerDay - 1
        }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = min(max(components.hour ?? 0, 0), 23)
        let minute = min(max(components.minute ?? 0, 0), 59)
        let totalMinutes = hour * 60 + minute
        return min(totalMinutes / slotMinutes, slotsPerDay - 1)
    }

    static func anchorSlotIndex(
        for point: CGPoint,
        in size: CGSize,
        metrics: PlannerDayTimelineMetrics
    ) -> Int? {
        guard metrics.containsAnchorPoint(point, in: size) else {
            return nil
        }

        return dragSlotIndex(
            for: point,
            in: size,
            metrics: metrics
        )
    }

    static func dragSlotIndex(
        for point: CGPoint,
        in size: CGSize,
        metrics: PlannerDayTimelineMetrics
    ) -> Int {
        let clampedY = min(
            max(point.y - metrics.topInset, 0),
            max(metrics.timedAreaHeight - 0.001, 0)
        )

        return min(
            max(Int(clampedY / metrics.slotHeight), 0),
            slotsPerDay - 1
        )
    }

    static func boundaryDate(
        forSlotBoundaryIndex slotBoundaryIndex: Int,
        on day: Date,
        calendar: Calendar
    ) -> Date {
        let clampedBoundary = min(max(slotBoundaryIndex, 0), slotsPerDay)
        let dayStart = calendar.startOfDay(for: day)

        return calendar.date(byAdding: .minute, value: clampedBoundary * slotMinutes, to: dayStart)
            ?? dayStart.addingTimeInterval(TimeInterval(clampedBoundary * slotMinutes * 60))
    }

    static func selectedRange(
        anchorSlotIndex: Int,
        currentSlotIndex: Int,
        on day: Date,
        calendar: Calendar
    ) -> PlannerSelectedTimeRange {
        let lowerBound = min(anchorSlotIndex, currentSlotIndex)
        let upperBound = max(anchorSlotIndex, currentSlotIndex)
        let start = boundaryDate(
            forSlotBoundaryIndex: lowerBound,
            on: day,
            calendar: calendar
        )
        let end = boundaryDate(
            forSlotBoundaryIndex: upperBound + 1,
            on: day,
            calendar: calendar
        )

        return PlannerSelectedTimeRange(start: start, end: end)
            ?? PlannerSelectedTimeRange(
                start: start,
                end: start.addingTimeInterval(TimeInterval(slotMinutes * 60))
            )!
    }

    static func selectedRange(
        anchorPoint: CGPoint,
        currentPoint: CGPoint,
        in size: CGSize,
        metrics: PlannerDayTimelineMetrics,
        day: Date,
        calendar: Calendar,
        occupiedIntervals: [DateInterval]
    ) -> PlannerSelectedTimeRange? {
        guard let anchorSlotIndex = anchorSlotIndex(
            for: anchorPoint,
            in: size,
            metrics: metrics
        ) else {
            return nil
        }

        let selection = selectedRange(
            anchorSlotIndex: anchorSlotIndex,
            currentSlotIndex: dragSlotIndex(
                for: currentPoint,
                in: size,
                metrics: metrics
            ),
            on: day,
            calendar: calendar
        )

        guard occupiedIntervals.contains(where: { $0.overlaps(selection.interval) }) == false else {
            return nil
        }

        return selection
    }
}

private extension DateInterval {
    func overlaps(_ other: DateInterval) -> Bool {
        end > other.start && start < other.end
    }
}
