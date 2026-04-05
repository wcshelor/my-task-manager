import SwiftUI

struct CalendarReadView: View {
    @StateObject private var viewModel: CalendarReadViewModel

    init(
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading
    ) {
        _viewModel = StateObject(
            wrappedValue: CalendarReadViewModel(
                calendarPermissionProvider: calendarPermissionProvider,
                calendarListingService: calendarListingService,
                calendarReader: calendarReader
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Access") {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Status")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(viewModel.permissionStatus.displayTitle)
                            .foregroundStyle(viewModel.permissionStatus.tintColor)
                    }

                    if let detail = viewModel.permissionStatus.detailText {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Request Calendar Access") {
                        Task {
                            await viewModel.requestCalendarAccess()
                        }
                    }
                    .disabled(
                        viewModel.isLoading
                        || viewModel.permissionStatus == .fullAccessGranted
                    )
                }

                if let errorMessage = viewModel.errorMessage {
                    Section("Issue") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Calendars") {
                    if viewModel.calendars.isEmpty {
                        Text(viewModel.calendarsEmptyStateText)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.calendars) { calendar in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(calendar.title)

                                    Text(calendar.allowsContentModifications ? "Editable Calendar" : "Read-Only Calendar")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if calendar.isExcludedBySettings {
                                    Label("Excluded", systemImage: "eye.slash")
                                        .labelStyle(.titleAndIcon)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Events") {
                    Picker("Window", selection: selectedWindowBinding) {
                        ForEach(CalendarReadViewModel.FixedWindow.allCases) { window in
                            Text(window.title).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(viewModel.selectedDateWindow.displayLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading events…")
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.events.isEmpty {
                        Text(viewModel.eventsEmptyStateText)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.events.enumerated()), id: \.offset) { _, event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)

                                Text(event.timeLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(event.calendarTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Calendar Read")
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var selectedWindowBinding: Binding<CalendarReadViewModel.FixedWindow> {
        Binding {
            viewModel.selectedWindow
        } set: { window in
            Task {
                await viewModel.selectWindow(window)
            }
        }
    }
}

private extension CalendarPermissionStatus {
    var displayTitle: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .fullAccessGranted:
            return "Full Access Granted"
        case .writeOnlyGrantedButInsufficient:
            return "Write-Only Access"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .error:
            return "Error"
        }
    }

    var detailText: String? {
        switch self {
        case .notDetermined:
            return "The app has not requested Calendar permission yet."
        case .fullAccessGranted:
            return "Readable calendars and matching events are loaded below."
        case .writeOnlyGrantedButInsufficient:
            return "Reads require full Calendar access. Write-only permission is not enough."
        case .denied:
            return "Calendar access was denied. Update the app’s Calendar permission in System Settings to enable reads."
        case .restricted:
            return "Calendar access is restricted on this Mac."
        case .error(let message):
            return message
        }
    }

    var tintColor: Color {
        switch self {
        case .fullAccessGranted:
            return .green
        case .notDetermined:
            return .secondary
        case .writeOnlyGrantedButInsufficient, .restricted:
            return .orange
        case .denied, .error:
            return .red
        }
    }
}

private extension CalendarReadViewModel {
    var calendarsEmptyStateText: String {
        if permissionStatus == .fullAccessGranted {
            return "No readable calendars were returned."
        }

        return "Grant full Calendar access to load readable calendars."
    }

    var eventsEmptyStateText: String {
        if permissionStatus == .fullAccessGranted {
            return "No events were found for this window."
        }

        return "Grant full Calendar access to load events."
    }
}

private extension DateInterval {
    var displayLabel: String {
        let endDate = end.addingTimeInterval(-1)
        return "\(start.formatted(date: .abbreviated, time: .omitted)) – \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

private extension CalendarEventSnapshot {
    var timeLabel: String {
        if isAllDay {
            return "All Day"
        }

        let startLabel = start.formatted(date: .abbreviated, time: .shortened)
        let endLabel = end.formatted(date: .abbreviated, time: .shortened)
        return "\(startLabel) – \(endLabel)"
    }
}

#Preview {
    let previewContainer = AppContainer.makePreview()

    CalendarReadView(
        calendarPermissionProvider: previewContainer.calendarPermissionProvider,
        calendarListingService: previewContainer.calendarListingService,
        calendarReader: previewContainer.calendarReader
    )
}
