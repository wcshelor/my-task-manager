import Foundation
import Testing
@testable import task_manager

@MainActor
struct EventKitCalendarServicesTests {
    @Test func permissionServiceMapsCurrentStatuses() {
        let writeOnlyStore = FakeCalendarEventStore(authorizationStatus: .writeOnly)
        let fullAccessStore = FakeCalendarEventStore(authorizationStatus: .fullAccess)

        let writeOnlyService = EventKitCalendarPermissionService(eventStore: writeOnlyStore)
        let fullAccessService = EventKitCalendarPermissionService(eventStore: fullAccessStore)

        #expect(writeOnlyService.currentStatus() == .writeOnlyGrantedButInsufficient)
        #expect(fullAccessService.currentStatus() == .fullAccessGranted)
    }

    @Test func permissionServiceReflectsGrantedAccessAfterRequest() async {
        let store = FakeCalendarEventStore(authorizationStatus: .notDetermined)
        store.requestResult = .success(true)
        store.authorizationStatusAfterRequest = .fullAccess
        let service = EventKitCalendarPermissionService(eventStore: store)

        let status = await service.requestFullAccess()

        #expect(status == .fullAccessGranted)
        #expect(store.requestFullAccessCallCount == 1)
    }

    @Test func calendarListingUsesSettingsToMarkExcludedCalendars() async throws {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "birthdays",
                title: "Birthdays",
                allowsContentModifications: false
            ),
            EventStoreCalendarDescriptor(
                id: "work",
                title: "Work",
                allowsContentModifications: true
            ),
        ]
        let settingsRepository = FakeSettingsRepository(
            settings: AppSettings(
                excludedReadCalendarTitles: ["Birthdays"],
                writeCalendarTitle: "Important",
                minimumGapMinutes: 15,
                defaultAssumedDurationMinutes: 30,
                plannerSuggestionCap: 5
            )
        )
        let service = EventKitCalendarListingService(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        let calendars = try await service.fetchReadableCalendars()

        #expect(calendars.count == 2)
        #expect(calendars[0].title == "Birthdays")
        #expect(calendars[0].isExcludedBySettings == true)
        #expect(calendars[1].title == "Work")
        #expect(calendars[1].isExcludedBySettings == false)
    }

    @Test func calendarReaderFiltersExcludedCalendarsAndNormalizesTitles() async throws {
        let untitledStart = Date(timeIntervalSince1970: 1_000)
        let reviewStart = Date(timeIntervalSince1970: 2_000)
        let birthdaysStart = Date(timeIntervalSince1970: 3_000)
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "birthdays",
                title: "Birthdays",
                allowsContentModifications: false
            ),
            EventStoreCalendarDescriptor(
                id: "work",
                title: "Work",
                allowsContentModifications: true
            ),
        ]
        store.events = [
            EventStoreEventDescriptor(
                identifier: "work-1",
                title: "  Weekly Review  ",
                start: reviewStart,
                end: reviewStart.addingTimeInterval(1_800),
                isAllDay: false,
                calendarTitle: "Work"
            ),
            EventStoreEventDescriptor(
                identifier: "work-2",
                title: "   ",
                start: untitledStart,
                end: untitledStart.addingTimeInterval(900),
                isAllDay: false,
                calendarTitle: "Work"
            ),
            EventStoreEventDescriptor(
                identifier: "bad-interval",
                title: "Broken Event",
                start: reviewStart,
                end: reviewStart,
                isAllDay: false,
                calendarTitle: "Work"
            ),
            EventStoreEventDescriptor(
                identifier: "birthday-1",
                title: "Birthday Dinner",
                start: birthdaysStart,
                end: birthdaysStart.addingTimeInterval(3_600),
                isAllDay: false,
                calendarTitle: "Birthdays"
            ),
        ]
        let settingsRepository = FakeSettingsRepository(
            settings: AppSettings(
                excludedReadCalendarTitles: ["Birthdays"],
                writeCalendarTitle: "Important",
                minimumGapMinutes: 15,
                defaultAssumedDurationMinutes: 30,
                plannerSuggestionCap: 5
            )
        )
        let service = EventKitCalendarReader(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        let events = try await service.fetchEvents(
            in: DateInterval(
                start: Date(timeIntervalSince1970: 500),
                end: Date(timeIntervalSince1970: 5_000)
            )
        )

        #expect(store.lastRequestedCalendarIdentifiers == ["work"])
        #expect(events.count == 2)
        #expect(events[0].identifier == "work-2")
        #expect(events[0].title == "Untitled Event")
        #expect(events[1].identifier == "work-1")
        #expect(events[1].title == "Weekly Review")
        #expect(events.allSatisfy { $0.calendarTitle == "Work" })
    }

    @Test func calendarReaderRejectsInsufficientPermission() async {
        let store = FakeCalendarEventStore(authorizationStatus: .denied)
        let settingsRepository = FakeSettingsRepository(settings: .mvpDefault)
        let service = EventKitCalendarReader(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        await #expect(throws: CalendarReadError.fullAccessRequired(.denied)) {
            try await service.fetchEvents(
                in: DateInterval(
                    start: Date(timeIntervalSince1970: 0),
                    end: Date(timeIntervalSince1970: 60)
                )
            )
        }
    }
}

@MainActor
private final class FakeCalendarEventStore: CalendarEventStore {
    var authorizationStatusValue: EventStoreAuthorizationStatus
    var authorizationStatusAfterRequest: EventStoreAuthorizationStatus?
    var requestResult: Result<Bool, Error> = .success(false)
    var calendars: [EventStoreCalendarDescriptor] = []
    var events: [EventStoreEventDescriptor] = []
    private(set) var requestFullAccessCallCount = 0
    private(set) var lastRequestedCalendarIdentifiers: Set<String>?

    init(authorizationStatus: EventStoreAuthorizationStatus) {
        self.authorizationStatusValue = authorizationStatus
    }

    func authorizationStatus() -> EventStoreAuthorizationStatus {
        authorizationStatusValue
    }

    func requestFullAccess() async throws -> Bool {
        requestFullAccessCallCount += 1

        if let authorizationStatusAfterRequest {
            authorizationStatusValue = authorizationStatusAfterRequest
        }

        return try requestResult.get()
    }

    func fetchEventCalendars() -> [EventStoreCalendarDescriptor] {
        calendars
    }

    func fetchEvents(
        in window: DateInterval,
        calendarIdentifiers: Set<String>?
    ) -> [EventStoreEventDescriptor] {
        lastRequestedCalendarIdentifiers = calendarIdentifiers

        return events.filter { event in
            guard event.end > window.start, event.start < window.end else {
                return false
            }

            guard let calendarIdentifiers else {
                return true
            }

            let calendarID = calendars.first(where: { $0.title == event.calendarTitle })?.id
            return calendarID.map(calendarIdentifiers.contains) ?? false
        }
    }
}

@MainActor
private final class FakeSettingsRepository: SettingsRepository {
    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func loadSettings() throws -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        self.settings = settings
    }
}
