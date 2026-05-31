import Foundation
import SwiftData

@MainActor
final class SwiftDataCalendarBlockFocusRepository: CalendarBlockFocusRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchFocus(
        forEventIdentifier eventIdentifier: String,
        calendarIdentifier: String
    ) throws -> CalendarBlockFocus? {
        try fetchAllRecords().first { record in
            record.eventIdentifier == normalized(eventIdentifier)
                && record.calendarIdentifier == normalized(calendarIdentifier)
        }?.focus
    }

    func fetchFocuses(in dateRange: DateInterval) throws -> [CalendarBlockFocus] {
        try fetchAllRecords()
            .map(\.focus)
            .filter { focus in
                focus.startDateSnapshot < dateRange.end
                    && focus.endDateSnapshot > dateRange.start
            }
            .sorted { lhs, rhs in
                if lhs.startDateSnapshot != rhs.startDateSnapshot {
                    return lhs.startDateSnapshot > rhs.startDateSnapshot
                }

                if lhs.endDateSnapshot != rhs.endDateSnapshot {
                    return lhs.endDateSnapshot > rhs.endDateSnapshot
                }

                return lhs.titleSnapshot.localizedCaseInsensitiveCompare(rhs.titleSnapshot) == .orderedAscending
            }
    }

    func fetchFocuses(linkedTo projectID: UUID) throws -> [CalendarBlockFocus] {
        try fetchAllRecords()
            .map(\.focus)
            .filter { $0.linkedProjectID == projectID }
            .sorted { lhs, rhs in
                if lhs.startDateSnapshot != rhs.startDateSnapshot {
                    return lhs.startDateSnapshot > rhs.startDateSnapshot
                }

                if lhs.endDateSnapshot != rhs.endDateSnapshot {
                    return lhs.endDateSnapshot > rhs.endDateSnapshot
                }

                return lhs.titleSnapshot.localizedCaseInsensitiveCompare(rhs.titleSnapshot) == .orderedAscending
            }
    }

    func saveFocus(
        _ focus: CalendarBlockFocus,
        replacingFocusWithID originalID: UUID?
    ) throws {
        let record =
            try fetchRecord(withID: originalID ?? focus.id)
            ?? fetchRecord(
                withEventIdentifier: focus.eventIdentifier,
                calendarIdentifier: focus.calendarIdentifier
            )
            ?? fetchRecord(withEventKey: focus.eventKey)

        if let record {
            record.update(from: focus)
        } else {
            modelContext.insert(CalendarBlockFocusRecord(focus: focus))
        }

        try modelContext.save()
    }

    func setLinkedProject(
        _ projectID: UUID?,
        for event: CalendarEventSnapshot,
        isUserConfirmed: Bool
    ) throws {
        guard var focus = try existingFocus(for: event) ?? CalendarBlockFocus(event: event) else {
            return
        }

        focus.linkedProjectID = projectID
        focus.isProjectLinkUserConfirmed = projectID != nil ? isUserConfirmed : false
        focus.updatedAt = .now
        try saveFocus(focus, replacingFocusWithID: focus.id)
    }

    func setSelectedTaskIDs(
        _ taskIDs: [UUID],
        for event: CalendarEventSnapshot
    ) throws {
        guard var focus = try existingFocus(for: event) ?? CalendarBlockFocus(event: event) else {
            return
        }

        focus.selectedTaskIDs = cleanedTaskIDs(taskIDs)
        focus.updatedAt = .now
        try saveFocus(focus, replacingFocusWithID: focus.id)
    }

    func updateIntentionNote(
        _ note: String?,
        for event: CalendarEventSnapshot
    ) throws {
        guard var focus = try existingFocus(for: event) ?? CalendarBlockFocus(event: event) else {
            return
        }

        focus.intentionNote = MyTask.cleanedOptionalText(from: note)
        focus.updatedAt = .now
        try saveFocus(focus, replacingFocusWithID: focus.id)
    }

    func markNoFocusNeeded(
        for event: CalendarEventSnapshot,
        isNoFocusNeeded: Bool
    ) throws {
        guard var focus = try existingFocus(for: event) ?? CalendarBlockFocus(event: event) else {
            return
        }

        focus.isNoFocusNeeded = isNoFocusNeeded
        if isNoFocusNeeded {
            focus.linkedProjectID = nil
            focus.isProjectLinkUserConfirmed = false
            focus.selectedTaskIDs = []
        }
        focus.updatedAt = .now
        try saveFocus(focus, replacingFocusWithID: focus.id)
    }

    private func existingFocus(for event: CalendarEventSnapshot) throws -> CalendarBlockFocus? {
        guard
            let eventIdentifier = event.identifier,
            let calendarIdentifier = event.calendarIdentifier
        else {
            return nil
        }

        return try fetchFocus(
            forEventIdentifier: eventIdentifier,
            calendarIdentifier: calendarIdentifier
        )
    }

    private func fetchAllRecords() throws -> [CalendarBlockFocusRecord] {
        try modelContext.fetch(FetchDescriptor<CalendarBlockFocusRecord>())
    }

    private func fetchRecord(withID id: UUID) throws -> CalendarBlockFocusRecord? {
        try fetchAllRecords().first { $0.id == id }
    }

    private func fetchRecord(
        withEventIdentifier eventIdentifier: String,
        calendarIdentifier: String
    ) throws -> CalendarBlockFocusRecord? {
        let cleanedEventIdentifier = normalized(eventIdentifier)
        let cleanedCalendarIdentifier = normalized(calendarIdentifier)

        return try fetchAllRecords().first { record in
            record.eventIdentifier == cleanedEventIdentifier
                && record.calendarIdentifier == cleanedCalendarIdentifier
        }
    }

    private func fetchRecord(withEventKey eventKey: String) throws -> CalendarBlockFocusRecord? {
        try fetchAllRecords().first { $0.eventKey == eventKey }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanedTaskIDs(_ taskIDs: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return taskIDs.filter { seen.insert($0).inserted }
    }
}
