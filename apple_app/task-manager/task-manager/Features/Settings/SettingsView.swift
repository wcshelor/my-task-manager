import Combine
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var permissionStatus: CalendarPermissionStatus
    @Published private(set) var calendars: [ReadableCalendar] = []
    @Published private(set) var homeWidgetCount = 0
    @Published private(set) var errorMessage: String?

    private let settingsRepository: any SettingsRepository
    private let homeLayoutRepository: any HomeLayoutRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarListingService: any CalendarListing
    private var hasLoaded = false

    init(
        settingsRepository: any SettingsRepository,
        homeLayoutRepository: any HomeLayoutRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing
    ) {
        self.settingsRepository = settingsRepository
        self.homeLayoutRepository = homeLayoutRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarListingService = calendarListingService
        self.settings = .mvpDefault
        self.permissionStatus = calendarPermissionProvider.currentStatus()
    }

    var writableCalendars: [ReadableCalendar] {
        calendars.filter(\.allowsContentModifications)
    }

    var selectedWriteCalendarIdentifier: String {
        settings.writeCalendarIdentifier
    }

    var selectedWriteCalendarTitle: String? {
        if let matchedCalendar = writableCalendars.first(where: {
            $0.id == settings.writeCalendarIdentifier
        }) {
            return matchedCalendar.title
        }

        guard settings.writeCalendarTitle.isEmpty == false else {
            return nil
        }

        return settings.writeCalendarTitle
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

        do {
            settings = try settingsRepository.loadSettings()
            homeWidgetCount = try homeLayoutRepository.loadLayout().orderedWidgets.count
        } catch {
            recordError("Unable to load settings: \(error.localizedDescription)")
        }

        guard permissionStatus == .fullAccessGranted else {
            calendars = []
            return
        }

        do {
            calendars = try await calendarListingService.fetchReadableCalendars()
        } catch {
            calendars = []
            recordError("Unable to load calendars: \(error.localizedDescription)")
        }
    }

    func selectWriteCalendar(withID calendarID: String) {
        guard let selectedCalendar = writableCalendars.first(where: { $0.id == calendarID }) else {
            recordError("The selected write calendar is no longer available.")
            return
        }

        var updatedSettings = settings
        updatedSettings.writeCalendarIdentifier = selectedCalendar.id
        updatedSettings.writeCalendarTitle = selectedCalendar.title
        save(updatedSettings, errorPrefix: "Unable to save calendar settings")
    }

    func setCalendarExcluded(_ title: String, isExcluded: Bool) {
        var updatedSettings = settings
        var titles = Set(updatedSettings.excludedReadCalendarTitles)

        if isExcluded {
            titles.insert(title)
        } else {
            titles.remove(title)
        }

        updatedSettings.excludedReadCalendarTitles = titles.sorted()
        save(updatedSettings, errorPrefix: "Unable to save calendar exclusions")
        calendars = calendars.map { calendar in
            guard calendar.title == title else {
                return calendar
            }

            return ReadableCalendar(
                id: calendar.id,
                title: calendar.title,
                allowsContentModifications: calendar.allowsContentModifications,
                isExcludedBySettings: isExcluded
            )
        }
    }

    func updateMinimumGapMinutes(_ minutes: Int) {
        var updatedSettings = settings
        updatedSettings.minimumGapMinutes = minutes
        save(updatedSettings, errorPrefix: "Unable to save planner settings")
    }

    func updateDefaultAssumedDurationMinutes(_ minutes: Int) {
        var updatedSettings = settings
        updatedSettings.defaultAssumedDurationMinutes = minutes
        save(updatedSettings, errorPrefix: "Unable to save planner settings")
    }

    func updatePlannerSuggestionCap(_ count: Int) {
        var updatedSettings = settings
        updatedSettings.plannerSuggestionCap = count
        save(updatedSettings, errorPrefix: "Unable to save planner settings")
    }

    private func save(_ updatedSettings: AppSettings, errorPrefix: String) {
        do {
            try settingsRepository.saveSettings(updatedSettings)
            settings = try settingsRepository.loadSettings()
            errorMessage = nil
        } catch {
            recordError("\(errorPrefix): \(error.localizedDescription)")
        }
    }

    private func recordError(_ message: String) {
        errorMessage = message
    }
}

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    private let homeLayoutRepository: any HomeLayoutRepository
    private let projectRepository: any ProjectRepository
    private let routineRepository: any RoutineRepository

    init(
        settingsRepository: any SettingsRepository,
        homeLayoutRepository: any HomeLayoutRepository,
        projectRepository: any ProjectRepository,
        routineRepository: any RoutineRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing
    ) {
        self.homeLayoutRepository = homeLayoutRepository
        self.projectRepository = projectRepository
        self.routineRepository = routineRepository
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                settingsRepository: settingsRepository,
                homeLayoutRepository: homeLayoutRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarListingService: calendarListingService
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Home Screen") {
                    NavigationLink {
                        HomeLayoutEditorView(
                            homeLayoutRepository: homeLayoutRepository,
                            projectRepository: projectRepository,
                            routineRepository: routineRepository
                        )
                    } label: {
                        LabeledContent("Customize Widgets") {
                            Text("\(viewModel.homeWidgetCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(homeSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Calendar / Planner") {
                    PlannerCalendarSetupCard(
                        writableCalendars: viewModel.writableCalendars,
                        selectedWriteCalendarIdentifier: viewModel.selectedWriteCalendarIdentifier,
                        selectedWriteCalendarTitle: viewModel.selectedWriteCalendarTitle,
                        onSelectWriteCalendar: { calendarID in
                            viewModel.selectWriteCalendar(withID: calendarID)
                        }
                    )

                    calendarReadAccessContent

                    Stepper(value: minimumGapBinding, in: 5 ... 180, step: 5) {
                        LabeledContent("Minimum Gap") {
                            Text("\(viewModel.settings.minimumGapMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: defaultDurationBinding, in: 15 ... 240, step: 15) {
                        LabeledContent("Default Duration") {
                            Text("\(viewModel.settings.defaultAssumedDurationMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: suggestionCapBinding, in: 0 ... 20, step: 1) {
                        LabeledContent("Suggestion Cap") {
                            Text("\(viewModel.settings.plannerSuggestionCap)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Sync / Devices") {
                    Text("Cross-device sync is not active yet. Settings sync and device-to-device sync are planned, but they are read-only placeholders in this build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }

    private var minimumGapBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.minimumGapMinutes },
            set: { viewModel.updateMinimumGapMinutes($0) }
        )
    }

    private var defaultDurationBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.defaultAssumedDurationMinutes },
            set: { viewModel.updateDefaultAssumedDurationMinutes($0) }
        )
    }

    private var suggestionCapBinding: Binding<Int> {
        Binding(
            get: { viewModel.settings.plannerSuggestionCap },
            set: { viewModel.updatePlannerSuggestionCap($0) }
        )
    }

    private var homeSummary: String {
        if viewModel.homeWidgetCount == 0 {
            return "Home is empty right now. Open customization to add widgets or restore the default layout."
        }

        return "Home currently shows \(viewModel.homeWidgetCount) widget\(viewModel.homeWidgetCount == 1 ? "" : "s")."
    }

    @ViewBuilder
    private var calendarReadAccessContent: some View {
        switch viewModel.permissionStatus {
        case .fullAccessGranted:
            if viewModel.calendars.isEmpty {
                Text("No readable calendars are available yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.calendars) { calendar in
                    Toggle(
                        isOn: Binding(
                            get: { calendar.isExcludedBySettings == false },
                            set: { isIncluded in
                                viewModel.setCalendarExcluded(calendar.title, isExcluded: isIncluded == false)
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(calendar.title)
                            Text("Use for busy-time reads")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        case .notDetermined:
            Text("Grant Calendar access from Planner before changing read-calendar settings on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .writeOnlyGrantedButInsufficient:
            Text("Full Calendar access is required to choose read calendars.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .denied, .restricted:
            Text("Calendar access is off. Re-enable it in iPhone Settings to manage read calendars here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .error(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView(
        settingsRepository: AppContainer.makePreview().settingsRepository,
        homeLayoutRepository: AppContainer.makePreview().homeLayoutRepository,
        projectRepository: AppContainer.makePreview().projectRepository,
        routineRepository: AppContainer.makePreview().routineRepository,
        calendarPermissionProvider: AppContainer.makePreview().calendarPermissionProvider,
        calendarListingService: AppContainer.makePreview().calendarListingService
    )
}
