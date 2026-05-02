import Foundation
import SwiftData

@Model
final class ScheduledBlockRecord {
    var id: UUID = UUID()
    var taskID: UUID = UUID()
    var start: Date = Date.distantPast
    var end: Date = Date.distantPast
    var statusRawValue: String = ScheduledBlockStatus.proposed.rawValue
    var calendarLinkStateRawValue: String = CalendarLinkState.notWritten.rawValue
    var calendarEventIdentifier: String?
    var calendarTitle: String?
    var eventTitleSnapshot: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var lastSyncedAt: Date?
    var syncErrorMessage: String?
    var isAllDay: Bool = false

    init(block: ScheduledBlock) {
        self.id = block.id
        self.taskID = block.taskID
        self.start = block.start
        self.end = block.end
        self.statusRawValue = block.status.rawValue
        self.calendarLinkStateRawValue = block.calendarLinkState.rawValue
        self.calendarEventIdentifier = block.calendarEventIdentifier
        self.calendarTitle = block.calendarTitle
        self.eventTitleSnapshot = block.eventTitleSnapshot
        self.createdAt = block.createdAt
        self.updatedAt = block.updatedAt
        self.lastSyncedAt = block.lastSyncedAt
        self.syncErrorMessage = block.syncErrorMessage
        self.isAllDay = block.isAllDay
    }

    var scheduledBlock: ScheduledBlock {
        ScheduledBlock(
            id: id,
            taskID: taskID,
            start: start,
            end: end,
            status: ScheduledBlockStatus(rawValue: statusRawValue) ?? .proposed,
            calendarLinkState: CalendarLinkState(rawValue: calendarLinkStateRawValue) ?? .notWritten,
            calendarEventIdentifier: calendarEventIdentifier,
            calendarTitle: calendarTitle,
            eventTitleSnapshot: eventTitleSnapshot,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastSyncedAt: lastSyncedAt,
            syncErrorMessage: syncErrorMessage,
            isAllDay: isAllDay
        )
    }

    func update(from block: ScheduledBlock) {
        id = block.id
        taskID = block.taskID
        start = block.start
        end = block.end
        statusRawValue = block.status.rawValue
        calendarLinkStateRawValue = block.calendarLinkState.rawValue
        calendarEventIdentifier = block.calendarEventIdentifier
        calendarTitle = block.calendarTitle
        eventTitleSnapshot = block.eventTitleSnapshot
        createdAt = block.createdAt
        updatedAt = block.updatedAt
        lastSyncedAt = block.lastSyncedAt
        syncErrorMessage = block.syncErrorMessage
        isAllDay = block.isAllDay
    }
}
