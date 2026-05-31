import Foundation
import SwiftData

@Model
final class CalendarBlockFocusRecord {
    var id: UUID = UUID()
    var eventKey: String = ""
    var eventIdentifier: String = ""
    var calendarIdentifier: String = ""
    var titleSnapshot: String = ""
    var startDateSnapshot: Date = .distantPast
    var endDateSnapshot: Date = .distantPast
    var linkedProjectID: UUID?
    var selectedTaskIDsData: Data = Data()
    var intentionNote: String?
    var preferredDebriefTemplateKindRawValue: String?
    var isProjectLinkUserConfirmed: Bool = false
    var isNoFocusNeeded: Bool = false
    var createdAt: Date = .distantPast
    var updatedAt: Date = .distantPast

    init(focus: CalendarBlockFocus) {
        update(from: focus)
    }

    var focus: CalendarBlockFocus {
        CalendarBlockFocus(
            id: id,
            eventKey: eventKey,
            eventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier,
            titleSnapshot: titleSnapshot,
            startDateSnapshot: startDateSnapshot,
            endDateSnapshot: endDateSnapshot,
            linkedProjectID: linkedProjectID,
            selectedTaskIDs: decodedSelectedTaskIDs,
            intentionNote: intentionNote,
            preferredDebriefTemplateKind: preferredDebriefTemplateKindRawValue.flatMap(
                DebriefTemplateKind.init(rawValue:)
            ),
            isProjectLinkUserConfirmed: isProjectLinkUserConfirmed,
            isNoFocusNeeded: isNoFocusNeeded,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from focus: CalendarBlockFocus) {
        id = focus.id
        eventKey = focus.eventKey
        eventIdentifier = focus.eventIdentifier
        calendarIdentifier = focus.calendarIdentifier
        titleSnapshot = focus.titleSnapshot
        startDateSnapshot = focus.startDateSnapshot
        endDateSnapshot = focus.endDateSnapshot
        linkedProjectID = focus.linkedProjectID
        selectedTaskIDsData = (try? JSONEncoder().encode(focus.selectedTaskIDs)) ?? Data()
        intentionNote = focus.intentionNote
        preferredDebriefTemplateKindRawValue = focus.preferredDebriefTemplateKind?.rawValue
        isProjectLinkUserConfirmed = focus.isProjectLinkUserConfirmed
        isNoFocusNeeded = focus.isNoFocusNeeded
        createdAt = focus.createdAt
        updatedAt = focus.updatedAt
    }

    private var decodedSelectedTaskIDs: [UUID] {
        (try? JSONDecoder().decode([UUID].self, from: selectedTaskIDsData)) ?? []
    }
}
