import SwiftUI

struct EstimatedDurationControl: View {
    @Binding var estimatedMinutesText: String

    private var parsedEstimatedMinutes: Int? {
        guard let estimatedMinutes = Int(
            estimatedMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        ) else {
            return nil
        }

        return TaskDurationRules.cleanedEstimatedMinutes(estimatedMinutes)
    }

    private var labelText: String {
        parsedEstimatedMinutes.map { "\($0) min" } ?? "None"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(labelText)
                .foregroundStyle(parsedEstimatedMinutes == nil ? .secondary : .primary)
                .monospacedDigit()

            Spacer()

            Button {
                guard let currentMinutes = parsedEstimatedMinutes else {
                    return
                }

                let nextMinutes = currentMinutes - TaskDurationRules.minutesIncrement
                estimatedMinutesText = nextMinutes < TaskDurationRules.minutesIncrement
                    ? ""
                    : String(nextMinutes)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .disabled(parsedEstimatedMinutes == nil)

            Button {
                let nextMinutes = (parsedEstimatedMinutes ?? 0) + TaskDurationRules.minutesIncrement
                estimatedMinutesText = String(nextMinutes)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Estimated Duration")
        .accessibilityValue(labelText)
    }
}
