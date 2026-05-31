import SwiftUI

struct FinanceTransactionListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sortMode: FinanceTransactionListSortMode = .date

    let month: Date
    let transactions: [FinanceTransaction]
    let onDelete: (FinanceTransaction) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Picker("Sort", selection: $sortMode) {
                ForEach(FinanceTransactionListSortMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                switch sortMode {
                case .date:
                    ForEach(FinanceSummaryService.dateSections(for: transactions)) { section in
                        Section(section.date.formatted(date: .abbreviated, time: .omitted)) {
                            rows(for: section.transactions)
                        }
                    }
                case .category:
                    ForEach(FinanceSummaryService.categorySections(for: transactions)) { section in
                        Section(section.title) {
                            rows(for: section.transactions)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(month.formatted(.dateTime.month(.wide).year()))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func rows(for transactions: [FinanceTransaction]) -> some View {
        ForEach(transactions) { transaction in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.name)
                        .font(.body.weight(.semibold))
                    Text(transaction.category?.name ?? "Uncategorized")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(FinanceFormatting.signedCurrencyString(from: transaction.signedAmount))
                    .foregroundStyle(transaction.kind == .income ? .green : .red)
                    .font(.body.weight(.semibold))
            }
            .swipeActions {
                Button(role: .destructive) {
                    onDelete(transaction)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

private enum FinanceTransactionListSortMode: String, CaseIterable, Identifiable {
    case date
    case category

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}
