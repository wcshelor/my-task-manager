import SwiftUI

struct PlannerCalendarSetupCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let writableCalendars: [ReadableCalendar]
    let selectedWriteCalendarIdentifier: String
    let selectedWriteCalendarTitle: String?
    let onSelectWriteCalendar: (String) -> Void

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calendar Setup")
                        .font(.headline)

                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(selectedWriteCalendarIdentifier.isEmpty ? "Selection Required" : "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedWriteCalendarIdentifier.isEmpty ? .orange : .green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (selectedWriteCalendarIdentifier.isEmpty ? Color.orange : Color.green)
                            .opacity(0.12),
                        in: Capsule()
                    )
            }

            if writableCalendars.isEmpty {
                Text("No writable calendars are available. Create or enable an editable iPhone calendar before accepting planner suggestions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker(
                    "Write Accepted Blocks To",
                    selection: Binding(
                        get: { selectedWriteCalendarIdentifier },
                        set: onSelectWriteCalendar
                    )
                ) {
                    Text("Select a Calendar").tag("")

                    ForEach(writableCalendars) { calendar in
                        Text(calendar.title).tag(calendar.id)
                    }
                }
                .pickerStyle(.menu)

                Text(helperText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(isCompactWidth ? 16 : 18)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var statusMessage: String {
        if writableCalendars.isEmpty {
            return "Planner suggestions can only be written back after you have a writable calendar."
        }

        if let selectedWriteCalendarTitle, selectedWriteCalendarIdentifier.isEmpty == false {
            return "Accepted suggestions are written to \(selectedWriteCalendarTitle)."
        }

        if let selectedWriteCalendarTitle {
            return "The saved calendar selection \"\(selectedWriteCalendarTitle)\" needs to be confirmed on this device."
        }

        return "Choose which calendar should receive accepted planner suggestions."
    }

    private var helperText: String {
        if selectedWriteCalendarTitle != nil, selectedWriteCalendarIdentifier.isEmpty == false {
            return "Busy-time reads continue to use every readable calendar that is not excluded by settings."
        }

        if selectedWriteCalendarTitle != nil {
            return "Re-select a writable calendar to replace the older title-based setting."
        }

        return "This is stored by stable calendar identifier, so calendar renames do not break event writes."
    }
}
