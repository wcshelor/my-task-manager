import Foundation
import Testing
@testable import task_manager

@MainActor
struct CalendarReadViewModelTests {
    @Test func loadIfNeededSkipsCalendarReadsWithoutFullAccess() async {
        let permissionProvider = FakeCalendarPermissionProvider(currentStatus: .notDetermined)
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "work",
                title: "Work",
                allowsContentModifications: true,
                isExcludedBySettings: false
            )
        ]))
        let reader = FakeCalendarReader(result: .success([
            CalendarEventSnapshot(
                identifier: "work-1",
                title: "Focus Block",
                start: Date(timeIntervalSince1970: 100),
                end: Date(timeIntervalSince1970: 200),
                isAllDay: false,
                calendarTitle: "Work"
            )
        ]))
        let viewModel = CalendarReadViewModel(
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_000) }
        )

        await viewModel.loadIfNeeded()

        #expect(viewModel.permissionStatus == .notDetermined)
        #expect(viewModel.calendars.isEmpty)
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(listingService.fetchCallCount == 0)
        #expect(reader.fetchCallCount == 0)
    }

    @Test func requestCalendarAccessLoadsCalendarsAndEventsOnGrant() async {
        let permissionProvider = FakeCalendarPermissionProvider(
            currentStatus: .notDetermined,
            requestedStatus: .fullAccessGranted
        )
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "birthdays",
                title: "Birthdays",
                allowsContentModifications: false,
                isExcludedBySettings: true
            ),
            ReadableCalendar(
                id: "work",
                title: "Work",
                allowsContentModifications: true,
                isExcludedBySettings: false
            ),
        ]))
        let expectedEvent = CalendarEventSnapshot(
            identifier: "work-1",
            title: "Design Review",
            start: Date(timeIntervalSince1970: 3_600),
            end: Date(timeIntervalSince1970: 5_400),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let reader = FakeCalendarReader(result: .success([expectedEvent]))
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let viewModel = CalendarReadViewModel(
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendar: calendar,
            nowProvider: { now }
        )

        await viewModel.requestCalendarAccess()

        #expect(permissionProvider.requestCallCount == 1)
        #expect(viewModel.permissionStatus == .fullAccessGranted)
        #expect(viewModel.calendars == listingService.calendars)
        #expect(viewModel.events == [expectedEvent])
        #expect(reader.lastRequestedWindow == CalendarReadViewModel.FixedWindow.today.dateInterval(relativeTo: now, calendar: calendar))
        #expect(viewModel.errorMessage == nil)
    }

    @Test func selectWindowRefreshesEventsUsingNewWindow() async {
        let permissionProvider = FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted)
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "work",
                title: "Work",
                allowsContentModifications: true,
                isExcludedBySettings: false
            )
        ]))
        let reader = FakeCalendarReader(result: .success([]))
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let viewModel = CalendarReadViewModel(
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendar: calendar,
            nowProvider: { now }
        )

        await viewModel.loadIfNeeded()
        await viewModel.selectWindow(.nextSevenDays)

        #expect(viewModel.selectedWindow == .nextSevenDays)
        #expect(reader.fetchCallCount == 2)
        #expect(reader.lastRequestedWindow == CalendarReadViewModel.FixedWindow.nextSevenDays.dateInterval(relativeTo: now, calendar: calendar))
    }

    @Test func refreshSurfacesReaderErrors() async {
        let permissionProvider = FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted)
        let listingService = FakeCalendarListingService(result: .success([]))
        let reader = FakeCalendarReader(result: .failure(TestError.failedToRead))
        let viewModel = CalendarReadViewModel(
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_000) }
        )

        await viewModel.refresh()

        #expect(viewModel.calendars.isEmpty)
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.errorMessage == TestError.failedToRead.localizedDescription)
    }
}

@MainActor
private final class FakeCalendarPermissionProvider: CalendarPermissionProviding {
    var currentStatusValue: CalendarPermissionStatus
    var requestedStatus: CalendarPermissionStatus?
    private(set) var requestCallCount = 0

    init(
        currentStatus: CalendarPermissionStatus,
        requestedStatus: CalendarPermissionStatus? = nil
    ) {
        self.currentStatusValue = currentStatus
        self.requestedStatus = requestedStatus
    }

    func currentStatus() -> CalendarPermissionStatus {
        currentStatusValue
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        requestCallCount += 1

        if let requestedStatus {
            currentStatusValue = requestedStatus
        }

        return currentStatusValue
    }
}

@MainActor
private final class FakeCalendarListingService: CalendarListing {
    let result: Result<[ReadableCalendar], Error>
    private(set) var fetchCallCount = 0

    init(result: Result<[ReadableCalendar], Error>) {
        self.result = result
    }

    var calendars: [ReadableCalendar] {
        (try? result.get()) ?? []
    }

    func fetchReadableCalendars() async throws -> [ReadableCalendar] {
        fetchCallCount += 1
        return try result.get()
    }
}

@MainActor
private final class FakeCalendarReader: CalendarReading {
    let result: Result<[CalendarEventSnapshot], Error>
    private(set) var fetchCallCount = 0
    private(set) var lastRequestedWindow: DateInterval?

    init(result: Result<[CalendarEventSnapshot], Error>) {
        self.result = result
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        fetchCallCount += 1
        lastRequestedWindow = window
        return try result.get()
    }
}

private enum TestError: LocalizedError {
    case failedToRead

    var errorDescription: String? {
        switch self {
        case .failedToRead:
            return "Failed to read events."
        }
    }
}

private func makeUTCGregorianCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}
