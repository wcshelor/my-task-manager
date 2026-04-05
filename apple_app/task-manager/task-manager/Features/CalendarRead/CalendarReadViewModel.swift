import Combine
import Foundation

@MainActor
final class CalendarReadViewModel: ObservableObject {
    enum FixedWindow: String, CaseIterable, Identifiable, Sendable {
        case today
        case nextSevenDays

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .today:
                return "Today"
            case .nextSevenDays:
                return "Next 7 Days"
            }
        }

        func dateInterval(
            relativeTo referenceDate: Date,
            calendar: Calendar = .current
        ) -> DateInterval {
            let start = calendar.startOfDay(for: referenceDate)
            let dayCount: Int

            switch self {
            case .today:
                dayCount = 1
            case .nextSevenDays:
                dayCount = 7
            }

            let end = calendar.date(byAdding: .day, value: dayCount, to: start)
                ?? start.addingTimeInterval(TimeInterval(dayCount * 86_400))

            return DateInterval(start: start, end: end)
        }
    }

    @Published private(set) var permissionStatus: CalendarPermissionStatus
    @Published private(set) var calendars: [ReadableCalendar] = []
    @Published private(set) var events: [CalendarEventSnapshot] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var selectedWindow: FixedWindow = .today

    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarListingService: any CalendarListing
    private let calendarReader: any CalendarReading
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarListingService = calendarListingService
        self.calendarReader = calendarReader
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.permissionStatus = calendarPermissionProvider.currentStatus()
    }

    var selectedDateWindow: DateInterval {
        selectedWindow.dateInterval(relativeTo: nowProvider(), calendar: calendar)
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else {
            return
        }

        await refresh()
    }

    func refresh() async {
        permissionStatus = calendarPermissionProvider.currentStatus()
        hasLoaded = true
        errorMessage = nil

        guard permissionStatus == .fullAccessGranted else {
            calendars = []
            events = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            calendars = try await calendarListingService.fetchReadableCalendars()
            events = try await calendarReader.fetchEvents(in: selectedDateWindow)
        } catch {
            calendars = []
            events = []
            errorMessage = error.localizedDescription
        }
    }

    func requestCalendarAccess() async {
        let requestedStatus = await calendarPermissionProvider.requestFullAccess()
        permissionStatus = requestedStatus

        if case .error(let message) = requestedStatus {
            hasLoaded = true
            calendars = []
            events = []
            errorMessage = message
            return
        }

        await refresh()
    }

    func selectWindow(_ window: FixedWindow) async {
        guard selectedWindow != window else {
            return
        }

        selectedWindow = window
        await refresh()
    }
}
