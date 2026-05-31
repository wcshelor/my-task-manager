import Foundation
import SwiftData

@Model
final class CalendarDebriefRecordModel {
    var id: UUID = UUID()
    var eventKey: String = ""
    var eventIdentifier: String?
    var calendarIdentifier: String?
    var calendarTitleSnapshot: String = ""
    var titleSnapshot: String = ""
    var startDateSnapshot: Date = .distantPast
    var endDateSnapshot: Date = .distantPast
    var templateKindRawValue: String = DebriefTemplateKind.workBlock.rawValue
    var createdAt: Date = .distantPast
    var updatedAt: Date = .distantPast
    var completedAt: Date?
    var statusRawValue: String = CalendarDebriefStatus.pending.rawValue
    var noDebriefNeeded: Bool = false
    var essentialNote: String?
    var createdCaptureIDsData: Data = Data()

    var workPlannedOutcomeRawValue: String?
    var workProductivityRating: Int?
    var workWhatHappened: String?
    var workBlockersRawValueText: String = ""
    var workBlockLengthFitRawValue: String?
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
    var socialMoodRawValue: String?
    var socialWhoWasThere: String?
    var socialLearnedAboutSomeone: String?
    var socialPromised: String?
    var socialDifferentNextTime: String?
    var socialNourishmentRawValue: String?
    var taskOutcomesData: Data = Data()

    init(debrief: CalendarDebriefRecord) {
        update(from: debrief)
    }

    var debrief: CalendarDebriefRecord {
        CalendarDebriefRecord(
            id: id,
            eventKey: eventKey,
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier,
            calendarTitleSnapshot: calendarTitleSnapshot,
            titleSnapshot: titleSnapshot,
            startDateSnapshot: startDateSnapshot,
            endDateSnapshot: endDateSnapshot,
            templateKind: DebriefTemplateKind(rawValue: templateKindRawValue) ?? .workBlock,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt,
            status: CalendarDebriefStatus(rawValue: statusRawValue) ?? .pending,
            noDebriefNeeded: noDebriefNeeded,
            essentialNote: essentialNote,
            createdCaptureIDs: decodedCaptureIDs,
            workPlannedOutcome: workPlannedOutcomeRawValue.flatMap(WorkBlockPlannedOutcome.init(rawValue:)),
            workProductivityRating: workProductivityRating,
            workWhatHappened: workWhatHappened,
            workBlockers: decodedWorkBlockers,
            workBlockLengthFit: workBlockLengthFitRawValue.flatMap(WorkBlockLengthFit.init(rawValue:)),
            workEnergyBeforeRating: workEnergyBeforeRating,
            workEnergyAfterRating: workEnergyAfterRating,
            workFocusQualityRating: workFocusQualityRating,
            workNextStep: workNextStep,
            meetingOutcomes: meetingOutcomes,
            meetingFollowUps: meetingFollowUps,
            meetingUsefulnessRating: meetingUsefulnessRating,
            meetingDecisions: meetingDecisions,
            meetingOpenQuestions: meetingOpenQuestions,
            meetingDeadlines: meetingDeadlines,
            meetingPreparednessRating: meetingPreparednessRating,
            meetingPeopleInvolved: meetingPeopleInvolved,
            meetingRememberBeforeNext: meetingRememberBeforeNext,
            socialWorthRemembering: socialWorthRemembering,
            socialFollowUp: socialFollowUp,
            socialMood: socialMoodRawValue.flatMap(SocialDebriefMood.init(rawValue:)),
            socialWhoWasThere: socialWhoWasThere,
            socialLearnedAboutSomeone: socialLearnedAboutSomeone,
            socialPromised: socialPromised,
            socialDifferentNextTime: socialDifferentNextTime,
            socialNourishment: socialNourishmentRawValue.flatMap(SocialDebriefNourishment.init(rawValue:)),
            taskOutcomes: decodedTaskOutcomes
        )
    }

    func update(from debrief: CalendarDebriefRecord) {
        id = debrief.id
        eventKey = debrief.eventKey
        eventIdentifier = debrief.eventIdentifier
        calendarIdentifier = debrief.calendarIdentifier
        calendarTitleSnapshot = debrief.calendarTitleSnapshot
        titleSnapshot = debrief.titleSnapshot
        startDateSnapshot = debrief.startDateSnapshot
        endDateSnapshot = debrief.endDateSnapshot
        templateKindRawValue = debrief.templateKind.rawValue
        createdAt = debrief.createdAt
        updatedAt = debrief.updatedAt
        completedAt = debrief.completedAt
        statusRawValue = debrief.status.rawValue
        noDebriefNeeded = debrief.noDebriefNeeded
        essentialNote = debrief.essentialNote
        createdCaptureIDsData = (try? JSONEncoder().encode(debrief.createdCaptureIDs)) ?? Data()

        workPlannedOutcomeRawValue = debrief.workPlannedOutcome?.rawValue
        workProductivityRating = debrief.workProductivityRating
        workWhatHappened = debrief.workWhatHappened
        workBlockersRawValueText = debrief.workBlockers.map(\.rawValue).joined(separator: "\n")
        workBlockLengthFitRawValue = debrief.workBlockLengthFit?.rawValue
        workEnergyBeforeRating = debrief.workEnergyBeforeRating
        workEnergyAfterRating = debrief.workEnergyAfterRating
        workFocusQualityRating = debrief.workFocusQualityRating
        workNextStep = debrief.workNextStep

        meetingOutcomes = debrief.meetingOutcomes
        meetingFollowUps = debrief.meetingFollowUps
        meetingUsefulnessRating = debrief.meetingUsefulnessRating
        meetingDecisions = debrief.meetingDecisions
        meetingOpenQuestions = debrief.meetingOpenQuestions
        meetingDeadlines = debrief.meetingDeadlines
        meetingPreparednessRating = debrief.meetingPreparednessRating
        meetingPeopleInvolved = debrief.meetingPeopleInvolved
        meetingRememberBeforeNext = debrief.meetingRememberBeforeNext

        socialWorthRemembering = debrief.socialWorthRemembering
        socialFollowUp = debrief.socialFollowUp
        socialMoodRawValue = debrief.socialMood?.rawValue
        socialWhoWasThere = debrief.socialWhoWasThere
        socialLearnedAboutSomeone = debrief.socialLearnedAboutSomeone
        socialPromised = debrief.socialPromised
        socialDifferentNextTime = debrief.socialDifferentNextTime
        socialNourishmentRawValue = debrief.socialNourishment?.rawValue
        taskOutcomesData = (try? JSONEncoder().encode(debrief.taskOutcomes)) ?? Data()
    }

    private var decodedCaptureIDs: [UUID] {
        (try? JSONDecoder().decode([UUID].self, from: createdCaptureIDsData)) ?? []
    }

    private var decodedWorkBlockers: [WorkBlockBlocker] {
        workBlockersRawValueText
            .split(separator: "\n")
            .compactMap { WorkBlockBlocker(rawValue: String($0)) }
    }

    private var decodedTaskOutcomes: [DebriefTaskOutcome] {
        (try? JSONDecoder().decode([DebriefTaskOutcome].self, from: taskOutcomesData)) ?? []
    }
}
