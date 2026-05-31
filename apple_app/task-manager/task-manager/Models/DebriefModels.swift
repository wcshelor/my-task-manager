import Foundation

nonisolated enum DebriefTemplateKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case workBlock
    case meeting
    case social

    var id: Self { self }

    var displayName: String {
        switch self {
        case .workBlock:
            return "Work Block"
        case .meeting:
            return "Meeting"
        case .social:
            return "Social"
        }
    }
}

nonisolated enum CalendarDebriefStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case completed
    case skipped
}

nonisolated enum WorkBlockPlannedOutcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case yes
    case mostly
    case partly
    case no
    case differentUsefulThing

    var id: Self { self }

    var displayName: String {
        switch self {
        case .yes:
            return "Yes"
        case .mostly:
            return "Mostly"
        case .partly:
            return "Partly"
        case .no:
            return "No"
        case .differentUsefulThing:
            return "Different useful thing"
        }
    }
}

nonisolated enum WorkBlockBlocker: String, Codable, CaseIterable, Identifiable, Sendable {
    case tired
    case distracted
    case unclearNextStep
    case underestimatedTask
    case interrupted
    case avoidance
    case wrongEnvironment
    case techSetupIssue
    case emotionalResistance
    case moreUrgentThingAppeared

    var id: Self { self }

    var displayName: String {
        switch self {
        case .tired:
            return "Tired"
        case .distracted:
            return "Distracted"
        case .unclearNextStep:
            return "Unclear next step"
        case .underestimatedTask:
            return "Underestimated task"
        case .interrupted:
            return "Interrupted"
        case .avoidance:
            return "Avoidance"
        case .wrongEnvironment:
            return "Wrong environment"
        case .techSetupIssue:
            return "Tech/setup issue"
        case .emotionalResistance:
            return "Emotional resistance"
        case .moreUrgentThingAppeared:
            return "More urgent thing appeared"
        }
    }
}

nonisolated enum WorkBlockLengthFit: String, Codable, CaseIterable, Identifiable, Sendable {
    case tooShort
    case aboutRight
    case tooLong

    var id: Self { self }

    var displayName: String {
        switch self {
        case .tooShort:
            return "Too short"
        case .aboutRight:
            return "About right"
        case .tooLong:
            return "Too long"
        }
    }
}

nonisolated enum SocialDebriefMood: String, Codable, CaseIterable, Identifiable, Sendable {
    case draining
    case mixed
    case fine
    case good
    case reallyGood

    var id: Self { self }

    var displayName: String {
        switch self {
        case .draining:
            return "Draining"
        case .mixed:
            return "Mixed"
        case .fine:
            return "Fine"
        case .good:
            return "Good"
        case .reallyGood:
            return "Really good"
        }
    }
}

nonisolated enum SocialDebriefNourishment: String, Codable, CaseIterable, Identifiable, Sendable {
    case nourishing
    case neutral
    case obligatory
    case draining

    var id: Self { self }

    var displayName: String {
        switch self {
        case .nourishing:
            return "Nourishing"
        case .neutral:
            return "Neutral"
        case .obligatory:
            return "Obligatory"
        case .draining:
            return "Draining"
        }
    }
}

nonisolated struct CalendarDebriefRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    var eventKey: String
    var eventIdentifier: String?
    var calendarIdentifier: String?
    var calendarTitleSnapshot: String
    var titleSnapshot: String
    var startDateSnapshot: Date
    var endDateSnapshot: Date
    var templateKind: DebriefTemplateKind
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var status: CalendarDebriefStatus
    var noDebriefNeeded: Bool
    var essentialNote: String?
    var createdCaptureIDs: [UUID]

    var workPlannedOutcome: WorkBlockPlannedOutcome?
    var workProductivityRating: Int?
    var workWhatHappened: String?
    var workBlockers: [WorkBlockBlocker]
    var workBlockLengthFit: WorkBlockLengthFit?
    var workEnergyBeforeRating: Int?
    var workEnergyAfterRating: Int?
    var workFocusQualityRating: Int?
    var workNextStep: String?

    var meetingOutcomes: String?
    var meetingFollowUps: String?
    var meetingUsefulnessRating: Int?
    var meetingDecisions: String?
    var meetingOpenQuestions: String?
    var meetingDeadlines: String?
    var meetingPreparednessRating: Int?
    var meetingPeopleInvolved: String?
    var meetingRememberBeforeNext: String?

    var socialWorthRemembering: String?
    var socialFollowUp: String?
    var socialMood: SocialDebriefMood?
    var socialWhoWasThere: String?
    var socialLearnedAboutSomeone: String?
    var socialPromised: String?
    var socialDifferentNextTime: String?
    var socialNourishment: SocialDebriefNourishment?

    init(
        id: UUID = UUID(),
        eventKey: String,
        eventIdentifier: String?,
        calendarIdentifier: String?,
        calendarTitleSnapshot: String,
        titleSnapshot: String,
        startDateSnapshot: Date,
        endDateSnapshot: Date,
        templateKind: DebriefTemplateKind,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        completedAt: Date? = nil,
        status: CalendarDebriefStatus,
        noDebriefNeeded: Bool = false,
        essentialNote: String? = nil,
        createdCaptureIDs: [UUID] = [],
        workPlannedOutcome: WorkBlockPlannedOutcome? = nil,
        workProductivityRating: Int? = nil,
        workWhatHappened: String? = nil,
        workBlockers: [WorkBlockBlocker] = [],
        workBlockLengthFit: WorkBlockLengthFit? = nil,
        workEnergyBeforeRating: Int? = nil,
        workEnergyAfterRating: Int? = nil,
        workFocusQualityRating: Int? = nil,
        workNextStep: String? = nil,
        meetingOutcomes: String? = nil,
        meetingFollowUps: String? = nil,
        meetingUsefulnessRating: Int? = nil,
        meetingDecisions: String? = nil,
        meetingOpenQuestions: String? = nil,
        meetingDeadlines: String? = nil,
        meetingPreparednessRating: Int? = nil,
        meetingPeopleInvolved: String? = nil,
        meetingRememberBeforeNext: String? = nil,
        socialWorthRemembering: String? = nil,
        socialFollowUp: String? = nil,
        socialMood: SocialDebriefMood? = nil,
        socialWhoWasThere: String? = nil,
        socialLearnedAboutSomeone: String? = nil,
        socialPromised: String? = nil,
        socialDifferentNextTime: String? = nil,
        socialNourishment: SocialDebriefNourishment? = nil
    ) {
        self.id = id
        self.eventKey = eventKey
        self.eventIdentifier = Self.cleanedIdentifier(eventIdentifier)
        self.calendarIdentifier = Self.cleanedIdentifier(calendarIdentifier)
        self.calendarTitleSnapshot = Self.cleanedSnapshotTitle(calendarTitleSnapshot)
        self.titleSnapshot = Self.cleanedSnapshotTitle(titleSnapshot)
        self.startDateSnapshot = startDateSnapshot
        self.endDateSnapshot = endDateSnapshot
        self.templateKind = templateKind
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.completedAt = completedAt
        self.status = status
        self.noDebriefNeeded = noDebriefNeeded
        self.essentialNote = MyTask.cleanedOptionalText(from: essentialNote)
        self.createdCaptureIDs = Array(Set(createdCaptureIDs))

        self.workPlannedOutcome = workPlannedOutcome
        self.workProductivityRating = Self.cleanedRating(workProductivityRating)
        self.workWhatHappened = MyTask.cleanedOptionalText(from: workWhatHappened)
        self.workBlockers = Array(Set(workBlockers))
        self.workBlockLengthFit = workBlockLengthFit
        self.workEnergyBeforeRating = Self.cleanedRating(workEnergyBeforeRating)
        self.workEnergyAfterRating = Self.cleanedRating(workEnergyAfterRating)
        self.workFocusQualityRating = Self.cleanedRating(workFocusQualityRating)
        self.workNextStep = MyTask.cleanedOptionalText(from: workNextStep)

        self.meetingOutcomes = MyTask.cleanedOptionalText(from: meetingOutcomes)
        self.meetingFollowUps = MyTask.cleanedOptionalText(from: meetingFollowUps)
        self.meetingUsefulnessRating = Self.cleanedRating(meetingUsefulnessRating)
        self.meetingDecisions = MyTask.cleanedOptionalText(from: meetingDecisions)
        self.meetingOpenQuestions = MyTask.cleanedOptionalText(from: meetingOpenQuestions)
        self.meetingDeadlines = MyTask.cleanedOptionalText(from: meetingDeadlines)
        self.meetingPreparednessRating = Self.cleanedRating(meetingPreparednessRating)
        self.meetingPeopleInvolved = MyTask.cleanedOptionalText(from: meetingPeopleInvolved)
        self.meetingRememberBeforeNext = MyTask.cleanedOptionalText(from: meetingRememberBeforeNext)

        self.socialWorthRemembering = MyTask.cleanedOptionalText(from: socialWorthRemembering)
        self.socialFollowUp = MyTask.cleanedOptionalText(from: socialFollowUp)
        self.socialMood = socialMood
        self.socialWhoWasThere = MyTask.cleanedOptionalText(from: socialWhoWasThere)
        self.socialLearnedAboutSomeone = MyTask.cleanedOptionalText(from: socialLearnedAboutSomeone)
        self.socialPromised = MyTask.cleanedOptionalText(from: socialPromised)
        self.socialDifferentNextTime = MyTask.cleanedOptionalText(from: socialDifferentNextTime)
        self.socialNourishment = socialNourishment
    }

    var completed: Bool {
        status == .completed
    }

    var skipped: Bool {
        status == .skipped
    }

    var durationMinutes: Int {
        max(0, Int(endDateSnapshot.timeIntervalSince(startDateSnapshot) / 60))
    }

    static func suggestedTemplate(for eventTitle: String) -> DebriefTemplateKind {
        let normalized = eventTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if matchesAnyKeyword(
            normalized,
            keywords: ["meeting", "call", "sync", "besprechung"]
        ) {
            return .meeting
        }

        if matchesAnyKeyword(
            normalized,
            keywords: ["dinner", "drinks", "party", "hang", "date", "coffee"]
        ) {
            return .social
        }

        if matchesAnyKeyword(
            normalized,
            keywords: ["work", "admin", "study", "write", "coding", "project", "deep work"]
        ) {
            return .workBlock
        }

        return .workBlock
    }

    private static func matchesAnyKeyword(
        _ text: String,
        keywords: [String]
    ) -> Bool {
        keywords.contains { keyword in
            text.contains(keyword)
        }
    }

    private static func cleanedIdentifier(_ value: String?) -> String? {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    private static func cleanedSnapshotTitle(_ value: String) -> String {
        MyTask.cleanedTitle(from: value) ?? "Untitled Event"
    }

    private static func cleanedRating(_ value: Int?) -> Int? {
        guard let value else {
            return nil
        }

        return min(5, max(1, value))
    }
}

nonisolated struct CalendarDebriefCandidate: Identifiable, Equatable, Hashable, Sendable {
    let eventKey: String
    let eventIdentifier: String?
    let calendarIdentifier: String?
    let calendarTitle: String
    let title: String
    let start: Date
    let end: Date
    let suggestedTemplate: DebriefTemplateKind
    let existingRecordID: UUID?

    var id: String {
        eventKey
    }

    var durationMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }
}

nonisolated struct DebriefQueueSettings: Equatable, Sendable {
    var lookbackDays: Int
    var minimumDurationMinutes: Int
    var ignoreAllDayEvents: Bool

    static let mvpDefault = DebriefQueueSettings(
        lookbackDays: 3,
        minimumDurationMinutes: 15,
        ignoreAllDayEvents: true
    )
}

nonisolated enum DebriefEventKey {
    static func from(
        eventIdentifier: String?,
        title: String,
        start: Date,
        end: Date,
        calendarIdentifier: String?,
        calendarTitle: String
    ) -> String {
        let normalizedIdentifier = eventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryIdentifier: String
        if let normalizedIdentifier, normalizedIdentifier.isEmpty == false {
            primaryIdentifier = normalizedIdentifier
        } else {
            primaryIdentifier = "no-id"
        }

        let normalizedCalendarIdentifier = calendarIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendarKey: String
        if let normalizedCalendarIdentifier, normalizedCalendarIdentifier.isEmpty == false {
            calendarKey = normalizedCalendarIdentifier
        } else {
            calendarKey = calendarTitle
        }

        return [
            primaryIdentifier,
            String(start.timeIntervalSince1970),
            String(end.timeIntervalSince1970),
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            calendarKey,
        ]
        .joined(separator: "|")
    }
}

nonisolated struct DebriefQueueService {
    private static let passiveEventKeywords = [
        "birthday",
        "holiday",
        "travel time",
        "commute",
        "out of office",
        "ooo",
    ]

    let settings: DebriefQueueSettings

    init(settings: DebriefQueueSettings = .mvpDefault) {
        self.settings = settings
    }

    func pendingCandidates(
        from events: [CalendarEventSnapshot],
        existingDebriefs: [CalendarDebriefRecord],
        now: Date
    ) -> [CalendarDebriefCandidate] {
        let earliestAllowedEndDate = now.addingTimeInterval(
            -Double(max(1, settings.lookbackDays)) * 86_400
        )

        let resolvedEventKeys = Set(
            existingDebriefs
                .filter { debrief in
                    debrief.status == .completed || debrief.status == .skipped
                }
                .map(\.eventKey)
        )

        let pendingRecordByEventKey = Dictionary(uniqueKeysWithValues: existingDebriefs.compactMap { debrief in
            guard debrief.status == .pending else {
                return nil
            }

            return (debrief.eventKey, debrief.id)
        })

        return events
            .filter { event in
                event.end <= now
                    && event.end >= earliestAllowedEndDate
                    && (settings.ignoreAllDayEvents == false || event.isAllDay == false)
                    && event.end.timeIntervalSince(event.start) >= Double(settings.minimumDurationMinutes) * 60
                    && isPassiveEventTitle(event.title) == false
            }
            .map { event in
                let eventKey = DebriefEventKey.from(
                    eventIdentifier: event.identifier,
                    title: event.title,
                    start: event.start,
                    end: event.end,
                    calendarIdentifier: event.calendarIdentifier,
                    calendarTitle: event.calendarTitle
                )

                return CalendarDebriefCandidate(
                    eventKey: eventKey,
                    eventIdentifier: event.identifier,
                    calendarIdentifier: event.calendarIdentifier,
                    calendarTitle: event.calendarTitle,
                    title: event.title,
                    start: event.start,
                    end: event.end,
                    suggestedTemplate: CalendarDebriefRecord.suggestedTemplate(for: event.title),
                    existingRecordID: pendingRecordByEventKey[eventKey]
                )
            }
            .filter { candidate in
                resolvedEventKeys.contains(candidate.eventKey) == false
            }
            .sorted { lhs, rhs in
                if lhs.end != rhs.end {
                    return lhs.end > rhs.end
                }

                if lhs.start != rhs.start {
                    return lhs.start > rhs.start
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func isPassiveEventTitle(_ title: String) -> Bool {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        return Self.passiveEventKeywords.contains { keyword in
            normalizedTitle.contains(keyword)
        }
    }
}
