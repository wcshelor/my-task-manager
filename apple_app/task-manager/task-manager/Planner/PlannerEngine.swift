import Foundation

struct PlannerEngine: Sendable {
    nonisolated init() {}

    nonisolated func makePlan(
        tasks: [MyTask],
        calendarEvents: [CalendarEventSnapshot],
        scheduledBlocks: [ScheduledBlock],
        constraints: PlannerConstraints,
        rejectedSuggestions: Set<SuggestionFingerprint> = []
    ) -> PlannerOutput {
        let busyIntervals = mergedBusyIntervals(
            calendarEvents: calendarEvents,
            scheduledBlocks: scheduledBlocks,
            within: constraints.planningWindow
        )
        let freeGaps = freeGaps(
            within: constraints.planningWindow,
            around: busyIntervals,
            minimumGapMinutes: constraints.minimumGapMinutes
        )
        let suggestions = rankedSuggestions(
            for: freeGaps,
            tasks: eligibleTasks(from: tasks, scheduledBlocks: scheduledBlocks),
            constraints: constraints,
            rejectedSuggestions: rejectedSuggestions
        )

        return PlannerOutput(
            busyIntervals: busyIntervals,
            freeGaps: freeGaps,
            suggestions: suggestions
        )
    }

    nonisolated func mergedBusyIntervals(
        calendarEvents: [CalendarEventSnapshot],
        scheduledBlocks: [ScheduledBlock],
        within planningWindow: DateInterval
    ) -> [BusyInterval] {
        let calendarBusy = calendarEvents.map { event in
            BusyInterval(
                start: event.start,
                end: event.end,
                source: .calendarEvent(identifier: event.identifier)
            )
        }
        let scheduledBusy = scheduledBlocks
            .filter(\.isActivelyScheduled)
            .map { block in
                BusyInterval(
                    start: block.start,
                    end: block.end,
                    source: .scheduledBlock(blockID: block.id)
                )
            }

        return mergeBusyIntervals(calendarBusy + scheduledBusy, within: planningWindow)
    }

    nonisolated func mergeBusyIntervals(
        _ busyIntervals: [BusyInterval],
        within planningWindow: DateInterval
    ) -> [BusyInterval] {
        let clippedIntervals = busyIntervals.compactMap { interval in
            clippedBusyInterval(interval, to: planningWindow)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }

            if lhs.end != rhs.end {
                return lhs.end < rhs.end
            }

            return lhs.sources.count < rhs.sources.count
        }

        guard let firstInterval = clippedIntervals.first else {
            return []
        }

        var mergedIntervals = [firstInterval]

        for interval in clippedIntervals.dropFirst() {
            guard let lastInterval = mergedIntervals.last else {
                mergedIntervals.append(interval)
                continue
            }

            if interval.start <= lastInterval.end {
                let mergedSources = mergedSourcesPreservingOrder(
                    lhs: lastInterval.sources,
                    rhs: interval.sources
                )
                mergedIntervals[mergedIntervals.count - 1] = BusyInterval(
                    start: lastInterval.start,
                    end: max(lastInterval.end, interval.end),
                    sources: mergedSources
                )
            } else {
                mergedIntervals.append(interval)
            }
        }

        return mergedIntervals
    }

    nonisolated func freeGaps(
        within planningWindow: DateInterval,
        around busyIntervals: [BusyInterval],
        minimumGapMinutes: Int
    ) -> [FreeGap] {
        let minimumGapSeconds = TimeInterval(max(1, minimumGapMinutes) * 60)
        var gaps: [FreeGap] = []
        var cursor = planningWindow.start

        for busyInterval in busyIntervals {
            if busyInterval.start.timeIntervalSince(cursor) >= minimumGapSeconds {
                gaps.append(FreeGap(start: cursor, end: busyInterval.start))
            }

            cursor = max(cursor, busyInterval.end)
        }

        if planningWindow.end.timeIntervalSince(cursor) >= minimumGapSeconds {
            gaps.append(FreeGap(start: cursor, end: planningWindow.end))
        }

        return gaps
    }

    nonisolated func rankedSuggestions(
        for freeGaps: [FreeGap],
        tasks: [MyTask],
        constraints: PlannerConstraints,
        rejectedSuggestions: Set<SuggestionFingerprint>
    ) -> [SuggestionCandidate] {
        guard constraints.suggestionCap > 0 else {
            return []
        }

        var remainingTasks = tasks
        var suggestions: [SuggestionCandidate] = []

        for freeGap in freeGaps {
            let rankedCandidates = remainingTasks.compactMap { task in
                candidate(for: task, in: freeGap, constraints: constraints)
            }
            .filter { rejectedSuggestions.contains($0.fingerprint) == false }
            .sorted(by: isHigherRankedCandidate)

            guard let bestCandidate = rankedCandidates.first else {
                continue
            }

            suggestions.append(bestCandidate)
            remainingTasks.removeAll { $0.id == bestCandidate.taskID }
        }

        let cappedSuggestions = suggestions
            .sorted(by: isHigherRankedCandidate)
            .prefix(constraints.suggestionCap)

        return Array(cappedSuggestions).sorted(by: isEarlierSuggestion)
    }

    nonisolated func eligibleTasks(
        from tasks: [MyTask],
        scheduledBlocks: [ScheduledBlock]
    ) -> [MyTask] {
        let activelyScheduledTaskIDs = Set(
            scheduledBlocks
                .filter(\.isActivelyScheduled)
                .map(\.taskID)
        )

        return tasks
            .filter { task in
                guard task.isDone == false, task.status != .archived else {
                    return false
                }

                return activelyScheduledTaskIDs.contains(task.id) == false
            }
            .sorted(by: isHigherRankedTask)
    }

    nonisolated func candidate(
        for task: MyTask,
        in freeGap: FreeGap,
        constraints: PlannerConstraints
    ) -> SuggestionCandidate? {
        let gapMinutes = freeGap.durationMinutes
        guard gapMinutes >= constraints.minimumGapMinutes else {
            return nil
        }

        let assumedDurationMinutes = max(
            task.estimatedMinutes ?? constraints.defaultAssumedDurationMinutes,
            constraints.minimumGapMinutes
        )
        let proposedDurationMinutes = min(assumedDurationMinutes, gapMinutes)
        guard proposedDurationMinutes >= constraints.minimumGapMinutes else {
            return nil
        }

        let suggestedEnd = freeGap.start.addingTimeInterval(TimeInterval(proposedDurationMinutes * 60))
        let suggestedInterval = DateInterval(start: freeGap.start, end: suggestedEnd)
        let score = suggestionScore(
            for: task,
            in: freeGap,
            suggestedInterval: suggestedInterval,
            assumedDurationMinutes: assumedDurationMinutes,
            constraints: constraints
        )

        return SuggestionCandidate(
            task: task,
            sourceGap: freeGap,
            suggestedInterval: suggestedInterval,
            score: score,
            explanation: explanation(
                for: task,
                in: freeGap,
                suggestedInterval: suggestedInterval,
                assumedDurationMinutes: assumedDurationMinutes,
                constraints: constraints
            ),
            assumedDurationMinutes: assumedDurationMinutes
        )
    }

    private nonisolated func clippedBusyInterval(
        _ busyInterval: BusyInterval,
        to planningWindow: DateInterval
    ) -> BusyInterval? {
        let clippedStart = max(busyInterval.start, planningWindow.start)
        let clippedEnd = min(busyInterval.end, planningWindow.end)

        guard clippedEnd > clippedStart else {
            return nil
        }

        return BusyInterval(
            start: clippedStart,
            end: clippedEnd,
            sources: busyInterval.sources
        )
    }

    private nonisolated func mergedSourcesPreservingOrder(
        lhs: [BusySource],
        rhs: [BusySource]
    ) -> [BusySource] {
        var sources = lhs

        for source in rhs where sources.contains(source) == false {
            sources.append(source)
        }

        return sources
    }

    private nonisolated func suggestionScore(
        for task: MyTask,
        in freeGap: FreeGap,
        suggestedInterval: DateInterval,
        assumedDurationMinutes: Int,
        constraints: PlannerConstraints
    ) -> Double {
        let gapMinutes = freeGap.durationMinutes
        let overflowMinutes = max(assumedDurationMinutes - gapMinutes, 0)
        let fitScore = overflowMinutes == 0
            ? 32.0
            : max(-24.0, 12.0 - Double(overflowMinutes))
        let durationDelta = abs(gapMinutes - assumedDurationMinutes)
        let closenessScore = max(0.0, 18.0 - Double(durationDelta) / 2.0)
        let priorityScore = basePriorityScore(for: task.priority)
        let dueSoonScore = baseDueSoonScore(for: task.dueDate, now: constraints.now)
        let latenessPenalty = latenessPenalty(
            dueDate: task.dueDate,
            suggestedInterval: suggestedInterval
        )

        let (priorityMultiplier, dueSoonMultiplier) = emphasisMultipliers(
            for: constraints.priorityEmphasis
        )

        return fitScore
            + closenessScore
            + priorityScore * priorityMultiplier
            + dueSoonScore * dueSoonMultiplier
            + latenessPenalty
    }

    private nonisolated func basePriorityScore(for priority: PriorityLevel?) -> Double {
        switch priority {
        case .urgent:
            return 34
        case .high:
            return 24
        case .medium:
            return 14
        case .low:
            return 6
        case nil:
            return 0
        }
    }

    private nonisolated func baseDueSoonScore(
        for dueDate: Date?,
        now: Date
    ) -> Double {
        guard let dueDate else {
            return 0
        }

        let hoursUntilDue = dueDate.timeIntervalSince(now) / 3_600

        switch hoursUntilDue {
        case ..<0:
            return 40
        case 0..<24:
            return max(16, 38 - hoursUntilDue)
        case 24..<72:
            return max(8, 22 - ((hoursUntilDue - 24) / 4))
        case 72..<168:
            return max(1, 8 - ((hoursUntilDue - 72) / 24))
        default:
            return 0
        }
    }

    private nonisolated func latenessPenalty(
        dueDate: Date?,
        suggestedInterval: DateInterval
    ) -> Double {
        guard let dueDate else {
            return 0
        }

        return suggestedInterval.end > dueDate ? -12 : 0
    }

    private nonisolated func emphasisMultipliers(
        for emphasis: PlannerPriorityEmphasis
    ) -> (priority: Double, dueSoon: Double) {
        switch emphasis {
        case .balanced:
            return (1.0, 1.0)
        case .highestPriority:
            return (1.45, 0.8)
        case .dueSoon:
            return (0.8, 1.45)
        }
    }

    private nonisolated func explanation(
        for task: MyTask,
        in freeGap: FreeGap,
        suggestedInterval: DateInterval,
        assumedDurationMinutes: Int,
        constraints: PlannerConstraints
    ) -> String {
        var parts: [String] = []

        if task.estimatedMinutes == nil {
            parts.append("No estimate, assumed \(constraints.defaultAssumedDurationMinutes)m")
        } else if assumedDurationMinutes <= freeGap.durationMinutes {
            parts.append("Fits \(assumedDurationMinutes)m in a \(freeGap.durationMinutes)m gap")
        } else {
            parts.append("Best short block in a \(freeGap.durationMinutes)m gap")
        }

        if let dueDate = task.dueDate {
            if dueDate <= constraints.now {
                parts.append("Overdue")
            } else if Calendar.current.isDate(dueDate, inSameDayAs: constraints.now) {
                parts.append("Due today")
            } else {
                let hoursUntilDue = Int(dueDate.timeIntervalSince(constraints.now) / 3_600)
                if hoursUntilDue < 48 {
                    parts.append("Due soon")
                }
            }
        }

        if let priority = task.priority {
            parts.append("\(priority.displayName) priority")
        }

        if let workMode = task.workMode,
           task.estimatedMinutes == nil || suggestedInterval.duration >= 3_600 {
            parts.append(workMode.displayName)
        }

        return parts.prefix(3).joined(separator: " • ")
    }

    private nonisolated func isHigherRankedTask(_ lhs: MyTask, _ rhs: MyTask) -> Bool {
        if basePriorityScore(for: lhs.priority) != basePriorityScore(for: rhs.priority) {
            return basePriorityScore(for: lhs.priority) > basePriorityScore(for: rhs.priority)
        }

        if baseDueSoonScore(for: lhs.dueDate, now: .distantPast)
            != baseDueSoonScore(for: rhs.dueDate, now: .distantPast) {
            return baseDueSoonScore(for: lhs.dueDate, now: .distantPast)
                > baseDueSoonScore(for: rhs.dueDate, now: .distantPast)
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private nonisolated func isHigherRankedCandidate(
        _ lhs: SuggestionCandidate,
        _ rhs: SuggestionCandidate
    ) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        if lhs.suggestedInterval.start != rhs.suggestedInterval.start {
            return lhs.suggestedInterval.start < rhs.suggestedInterval.start
        }

        if lhs.task.createdAt != rhs.task.createdAt {
            return lhs.task.createdAt < rhs.task.createdAt
        }

        return lhs.task.id.uuidString < rhs.task.id.uuidString
    }

    private nonisolated func isEarlierSuggestion(
        _ lhs: SuggestionCandidate,
        _ rhs: SuggestionCandidate
    ) -> Bool {
        if lhs.suggestedInterval.start != rhs.suggestedInterval.start {
            return lhs.suggestedInterval.start < rhs.suggestedInterval.start
        }

        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        return lhs.task.id.uuidString < rhs.task.id.uuidString
    }
}
